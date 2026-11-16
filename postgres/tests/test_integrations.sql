-- =====================================================================
-- Database tests for the invoice integration functions (SAP sync).
-- Runs inside one transaction and ROLLS BACK: safe on a shared database.
--   psql "<connection>" -v ON_ERROR_STOP=1 -f database/postgres/tests/test_integrations.sql
-- Each block uses ASSERT; the first failure aborts the script with a message.
-- Covers: profile validation, one active job per integration, idempotent page upsert
-- (created / unchanged / updated), row-level rejection, invoice id collision, cancellation
-- rules, worker ownership, counters / watermark, history, summary, retention, cursor reset.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

CREATE TEMP TABLE t_ctx (k text PRIMARY KEY, v text) ON COMMIT DROP;

-- ---- Setup: integration with one GP profile ----
DO $$
DECLARE
    v_module    uuid    := (SELECT id FROM app.app_modules WHERE slug = 'GP');
    v_admin     uuid    := (SELECT id FROM app_auth.users WHERE username = 'admin');
    v_int       app.udt_integration_result;
BEGIN
    ASSERT v_module IS NOT NULL, 'GP module missing (run seed.sql first)';

    -- invalid status in profile -> CA400
    BEGIN
        PERFORM app.usp_integration_save(NULL, NULL, 'sap-odata', 'zz test sap', NULL, 'QA', 'ZZTEST-100', true,
            '{}', 'basic', '{}', false, '{}', false, '{}', NULL,
            jsonb_build_array(jsonb_build_object('module_id', v_module, 'name', 'GP', 'invoice_code_template', 'X-{a}',
                                                 'default_status', 'NoSuchStatus')), v_admin);
        ASSERT false, 'expected CA400 for unknown status';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;

    v_int := app.usp_integration_save(NULL, NULL, 'sap-odata', 'zz test sap', 'test', 'QA', 'ZZTEST-100', true,
        '{"baseUrl": "https://sap.example"}', 'basic', '{"username": "u"}', false,
        '{"mode": "interval", "intervalMinutes": 15, "timezone": "UTC"}', false, '{"maxAttempts": 2}', NULL,
        jsonb_build_array(jsonb_build_object(
            'module_id', v_module, 'name', 'General Payments', 'is_active', true,
            'settings', '{"entitySet": "A_SupplierInvoice"}'::jsonb,
            'key_fields', '["CompanyCode","FiscalYear","SupplierInvoice"]'::jsonb,
            'invoice_code_template', 'INV-{prefix}-SAP-{SupplierInvoice}-{FiscalYear}',
            'field_mapping', '{}'::jsonb, 'default_status', 'Pending',
            'cancellation_rule', '{"field": "ReverseDocument", "operator": "notEmpty", "setStatus": "Rejected", "onlyWhenStatusIn": ["Pending"]}'::jsonb)),
        v_admin);
    ASSERT v_int.version = 1 AND jsonb_array_length(v_int.profiles) = 1, 'integration + profile created';
    ASSERT v_int.secret_configured = false, 'no secret yet';

    -- duplicate name -> CA409
    BEGIN
        PERFORM app.usp_integration_save(NULL, NULL, 'sap-odata', 'ZZ TEST SAP', NULL, NULL, 'X', true, '{}', 'none', '{}',
            false, '{}', false, '{}', NULL, '[]', v_admin);
        ASSERT false, 'expected CA409 for duplicate name';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    -- stale version -> CA409
    BEGIN
        PERFORM app.usp_integration_save(v_int.id, 99, 'sap-odata', 'zz test sap', NULL, NULL, 'ZZTEST-100', true, '{}', 'basic',
            '{}', false, '{}', false, '{}', NULL, v_int.profiles, v_admin);
        ASSERT false, 'expected CA409 for stale version';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    PERFORM app.usp_integration_set_secret(v_int.id, 'v1:test:cipher', v_admin);
    ASSERT (SELECT secret_configured FROM app.usp_integration_get(v_int.id)), 'secret flagged as configured';
    ASSERT (SELECT secret_ciphertext FROM app.usp_integration_get_secret(v_int.id)) = 'v1:test:cipher', 'secret readable by backend';

    INSERT INTO t_ctx VALUES ('int', v_int.id::text), ('profile', (v_int.profiles -> 0 ->> 'id')), ('admin', v_admin::text);
END $$;

-- ---- Queue: one active job per integration, claim, ownership ----
DO $$
DECLARE
    v_int   uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'int');
    v_admin uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'admin');
    v_job   app.udt_sync_job_result;
BEGIN
    v_job := app.usp_sync_job_enqueue(v_int, 'manual', v_admin);
    ASSERT v_job.status = 'queued' AND v_job.max_attempts = 2, 'job queued with retry policy';

    BEGIN
        PERFORM app.usp_sync_job_enqueue(v_int, 'scheduled', NULL);
        ASSERT false, 'expected CA409 for overlapping job';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    -- other queued jobs (real ones) may exist; claim until we get ours
    UPDATE app.integration_sync_jobs SET run_after = now() - interval '1 hour' WHERE id = v_job.id;
    LOOP
        SELECT * INTO v_job FROM app.usp_sync_job_claim('worker-a');
        EXIT WHEN v_job.id IS NULL OR v_job.integration_id = v_int;
    END LOOP;
    ASSERT v_job.status = 'running' AND v_job.worker_id = 'worker-a', 'claimed by worker-a';

    BEGIN
        PERFORM app.usp_sync_job_heartbeat(v_job.id, 'worker-b');
        ASSERT false, 'expected CA409 for foreign worker heartbeat';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    INSERT INTO t_ctx VALUES ('job', v_job.id::text);
END $$;

-- ---- Page upsert: created, rejected, collision, idempotent replay ----
DO $$
DECLARE
    v_job       uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'job');
    v_profile   uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'profile');
    v_rows      jsonb;
    v_outcomes  text;
    v_job_row   app.udt_sync_job_result;
BEGIN
    v_rows := jsonb_build_array(
        jsonb_build_object('row_no', 1, 'external_key', '1010/2026/A', 'invoice_code', 'INV-GP-SAP-ZZA-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 100, 'reception_date', '2026-07-01',
            'currency_code', 'ARS', 'payload_hash', repeat('a', 64), 'source_changed_at', '2026-07-01T10:00:00Z',
            'external_doc', '{"CompanyCode": "1010"}'::jsonb),
        jsonb_build_object('row_no', 2, 'external_key', '1010/2026/B', 'invoice_code', 'INV-GP-SAP-ZZB-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 200, 'reception_date', '2026-07-01',
            'payload_hash', repeat('b', 64), 'source_changed_at', '2026-07-01T11:00:00Z'),
        jsonb_build_object('row_no', 3, 'external_key', '1010/2026/C', 'invoice_code', 'INV-GP-SAP-ZZC-2026',
            'vendor_name', 'ZZ Vendor', 'amount', 300, 'reception_date', '2026-07-01', 'payload_hash', repeat('c', 64)),
        jsonb_build_object('row_no', 4, 'external_key', '1010/2026/D', 'invoice_code', 'INV-GP-1270',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 1, 'reception_date', '2026-07-01',
            'payload_hash', repeat('d', 64)),
        jsonb_build_object('row_no', 5, 'external_key', '1010/2026/E', 'invoice_code', 'INV-GP-SAP-ZZE-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 5, 'reception_date', '2026-07-01',
            'payload_hash', repeat('e', 64), 'cancelled', true));

    SELECT string_agg(row_no || '=' || outcome, ',' ORDER BY row_no) INTO v_outcomes
    FROM app.usp_sync_page_apply(v_job, 'worker-a', v_profile, 6, v_rows,
        '[{"external_key": "1010/2026/F", "stage": "validation", "message": "cuit: invalid"}]', '2026-07-01T11:00:00Z');
    ASSERT v_outcomes = '1=created,2=created,3=rejected,4=rejected,5=skipped', 'first page outcomes: ' || v_outcomes;

    v_job_row := app.ufn_sync_job_row(v_job);
    ASSERT v_job_row.records_fetched = 6 AND v_job_row.records_created = 2 AND v_job_row.records_rejected = 3
        AND v_job_row.records_unchanged = 1 AND v_job_row.pages_processed = 1,
        'counters after page 1: ' || row_to_json(v_job_row)::text;
    ASSERT v_job_row.error_count = 3, 'three errors recorded (pre-reject, missing cuit, collision)';
    ASSERT (SELECT watermark FROM app.integration_profiles WHERE id = v_profile) = '2026-07-01T11:00:00Z', 'watermark advanced';
    ASSERT (SELECT status FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZA-2026') = 'Pending', 'default status';
    ASSERT (SELECT created_by IS NULL FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZA-2026'), 'system-created invoice';

    -- Replay the same page: nothing new, nothing duplicated
    SELECT string_agg(row_no || '=' || outcome, ',' ORDER BY row_no) INTO v_outcomes
    FROM app.usp_sync_page_apply(v_job, 'worker-a', v_profile, 2, jsonb_path_query_array(v_rows, '$[0 to 1]'), NULL, NULL);
    ASSERT v_outcomes = '1=unchanged,2=unchanged', 'replay is idempotent: ' || v_outcomes;
    ASSERT (SELECT count(*) FROM gpp.invoice_external_refs WHERE source_system = 'ZZTEST-100') = 2, 'no duplicate refs';
    ASSERT (SELECT watermark FROM app.integration_profiles WHERE id = v_profile) = '2026-07-01T11:00:00Z',
        'NULL watermark keeps the cursor';
END $$;

-- ---- Updates: source fields only; cancellation rules ----
DO $$
DECLARE
    v_job       uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'job');
    v_profile   uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'profile');
    v_outcomes  text;
BEGIN
    -- A is being processed (Approved, assigned to a team); B still Pending
    UPDATE gpp.gpp_invoices SET status = 'Approved', team_id = (SELECT id FROM app.teams ORDER BY sort_order, name LIMIT 1)
    WHERE invoice_code = 'INV-GP-SAP-ZZA-2026';

    SELECT string_agg(row_no || '=' || outcome, ',' ORDER BY row_no) INTO v_outcomes
    FROM app.usp_sync_page_apply(v_job, 'worker-a', v_profile, 2, jsonb_build_array(
        jsonb_build_object('row_no', 1, 'external_key', '1010/2026/A', 'invoice_code', 'INV-GP-SAP-ZZA-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 150, 'reception_date', '2026-07-01',
            'payload_hash', repeat('1', 64), 'cancelled', true),
        jsonb_build_object('row_no', 2, 'external_key', '1010/2026/B', 'invoice_code', 'INV-GP-SAP-ZZB-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 200, 'reception_date', '2026-07-01',
            'payload_hash', repeat('2', 64), 'cancelled', true)), NULL, '2026-07-02T09:00:00Z');
    ASSERT v_outcomes = '1=updated,2=updated', 'update outcomes: ' || v_outcomes;

    ASSERT (SELECT amount FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZA-2026') = 150, 'source field updated';
    ASSERT (SELECT status FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZA-2026') = 'Approved',
        'status of an invoice in processing is never changed';
    ASSERT (SELECT team_id IS NOT NULL FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZA-2026'), 'workflow field kept';
    ASSERT EXISTS (SELECT 1 FROM app.integration_sync_errors WHERE job_id = v_job AND stage = 'review'
                   AND external_key = '1010/2026/A'), 'review error for cancellation after processing started';
    ASSERT (SELECT status FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZB-2026') = 'Rejected',
        'pending invoice cancelled in source becomes Rejected';
    ASSERT (SELECT source_state FROM gpp.invoice_external_refs WHERE external_key = '1010/2026/B'
            AND source_system = 'ZZTEST-100') = 'cancelled', 'ref marked cancelled';
END $$;

-- ---- A row that fails to persist keeps the cursor where it was ----
DO $$
DECLARE
    v_job       uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'job');
    v_profile   uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'profile');
    v_before    timestamptz := (SELECT watermark FROM app.integration_profiles WHERE id = v_profile);
    v_outcomes  text;
BEGIN
    SELECT string_agg(row_no || '=' || outcome, ',' ORDER BY row_no) INTO v_outcomes
    FROM app.usp_sync_page_apply(v_job, 'worker-a', v_profile, 2, jsonb_build_array(
        jsonb_build_object('row_no', 1, 'external_key', '1010/2026/G', 'invoice_code', 'INV-GP-SAP-ZZG-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 7, 'reception_date', '2026-07-03',
            'payload_hash', repeat('g', 64)),
        jsonb_build_object('row_no', 2, 'external_key', '1010/2026/H', 'invoice_code', 'INV-GP-SAP-ZZH-2026',
            'vendor_name', 'ZZ Vendor', 'cuit', '30-99999999-1', 'amount', 8, 'reception_date', '2026-07-03',
            'invoice_1a', repeat('9', 40), 'payload_hash', repeat('h', 64))), NULL, '2026-07-09T00:00:00Z');
    ASSERT v_outcomes = '1=created,2=failed', 'persistence failure outcomes: ' || v_outcomes;
    ASSERT (SELECT watermark FROM app.integration_profiles WHERE id = v_profile) = v_before,
        'cursor not advanced past a failed row';
    ASSERT EXISTS (SELECT 1 FROM gpp.gpp_invoices WHERE invoice_code = 'INV-GP-SAP-ZZG-2026'), 'good row of the page kept';
    ASSERT EXISTS (SELECT 1 FROM app.integration_sync_errors WHERE job_id = v_job AND stage = 'persistence'
                   AND external_key = '1010/2026/H'), 'persistence error recorded';
END $$;

-- ---- Finish, history, errors, summary, cancel, cursor reset, purge ----
DO $$
DECLARE
    v_int       uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'int');
    v_job       uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'job');
    v_profile   uuid    := (SELECT v::uuid FROM t_ctx WHERE k = 'profile');
    v_row       app.udt_sync_job_result;
    v_summary   app.udt_integration_summary_result;
    v_queued    app.udt_sync_job_result;
BEGIN
    BEGIN
        PERFORM app.usp_integration_profile_reset_cursor(v_int, v_profile);
        ASSERT false, 'expected CA409: cursor reset while running';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    v_row := app.usp_sync_job_finish(v_job, 'worker-a', 'partially_succeeded', '3 records rejected');
    ASSERT v_row.status = 'partially_succeeded' AND v_row.finished_at IS NOT NULL AND v_row.duration_ms >= 0, 'finished';
    ASSERT (SELECT last_status FROM app.integrations WHERE id = v_int) = 'partially_succeeded', 'integration status';
    ASSERT (SELECT last_success_at IS NOT NULL FROM app.integrations WHERE id = v_int), 'last success set';

    BEGIN
        PERFORM app.usp_sync_job_finish(v_job, 'worker-a', 'succeeded', NULL);
        ASSERT false, 'expected CA409: finishing twice';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    ASSERT (SELECT total_items FROM app.usp_sync_job_list(v_int, NULL, NULL, NULL, NULL, 1, 10) LIMIT 1) = 1, 'history row';
    ASSERT (SELECT total_items FROM app.usp_sync_error_list(v_job, 'review', 1, 10) LIMIT 1) = 1, 'error list filter';

    SELECT * INTO v_summary FROM app.usp_integration_summary(v_int, 30);
    ASSERT v_summary.jobs_total = 1 AND v_summary.records_created = 3 AND v_summary.invoices_imported = 3
        AND v_summary.last_job ->> 'status' = 'partially_succeeded' AND v_summary.active_job IS NULL, 'summary';

    -- retry -> queued; cancel queued; cancel finished -> CA409
    v_queued := app.usp_sync_job_enqueue(v_int, 'retry', NULL, v_job, 1, now() + interval '1 hour');
    ASSERT v_queued.retry_of_job_id = v_job, 'retry links to original';
    v_queued := app.usp_sync_job_cancel(v_int, v_queued.id);
    ASSERT v_queued.status = 'cancelled', 'queued job cancelled';
    BEGIN
        PERFORM app.usp_sync_job_cancel(v_int, v_job);
        ASSERT false, 'expected CA409: cancel finished job';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    PERFORM app.usp_integration_profile_reset_cursor(v_int, v_profile);
    ASSERT (SELECT watermark IS NULL FROM app.integration_profiles WHERE id = v_profile), 'cursor reset';

    UPDATE app.integration_sync_jobs SET finished_at = now() - interval '400 days' WHERE integration_id = v_int;
    ASSERT (app.usp_integration_purge_history(90)).rows_affected = 2, 'old jobs purged';
    ASSERT (SELECT count(*) FROM gpp.invoice_external_refs WHERE source_system = 'ZZTEST-100') = 3, 'refs survive purge';

    -- Deactivating cancels queued work
    v_queued := app.usp_sync_job_enqueue(v_int, 'manual', NULL);
    PERFORM app.usp_integration_save(v_int, (SELECT version FROM app.integrations WHERE id = v_int), 'sap-odata', 'zz test sap',
        NULL, NULL, 'ZZTEST-100', false, '{}', 'basic', '{}', false, '{}', false, '{}', NULL,
        (SELECT profiles FROM app.usp_integration_get(v_int)), NULL);
    ASSERT (SELECT status FROM app.integration_sync_jobs WHERE id = v_queued.id) = 'cancelled', 'deactivation cancels queue';

    PERFORM app.usp_integration_delete(v_int);
    ASSERT (SELECT count(*) FROM gpp.invoice_external_refs WHERE source_system = 'ZZTEST-100' AND integration_id IS NULL) = 3,
        'refs kept after integration delete';
END $$;

\echo 'All integration database tests passed.'
ROLLBACK;
