-- =====================================================================
-- app.usp_sync_page_apply - persist one extracted page of source invoices (idempotent)
-- Request:  p_job_id, p_worker_id (ownership check), p_profile_id,
--           p_fetched   = records received from the source for this page,
--           p_rows      = JSON array of app.udt_external_invoice_input (mapped + validated),
--           p_rejects   = JSON array of app.udt_sync_error_input (records that failed mapping /
--                         validation in the backend),
--           p_watermark = highest source change time of the page (NULL = do not advance the cursor;
--                         also not advanced when any row of the page failed to persist)
-- Response: SETOF app.udt_sync_row_outcome_result, one per p_rows element:
--             created   new invoice + invoice_external_refs row
--             updated   source fields changed (status / team / assignee are never touched)
--             unchanged same payload hash as last time
--             skipped   cancelled in the source before it was ever imported
--             rejected  missing fields, or the invoice id is used by another invoice
--             failed    database error for that row (the rest of the page is still saved)
-- Behaviour: one transaction for the page; every row runs in its own savepoint. Job counters,
--            per-profile stats, errors and the profile watermark are written in the same
--            transaction, so a crash can only replay this page, and replaying is harmless.
--            Cancellation in the source: status becomes cancellation_rule.setStatus (default
--            Rejected) only while the invoice status is in onlyWhenStatusIn (default Pending);
--            otherwise a 'review' error is recorded and the status is left alone.
-- Errors:   CA404 profile not found for the job, CA409 job not running for this worker
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_page_apply(
    p_job_id        integer,
    p_worker_id     text,
    p_profile_id    integer,
    p_fetched       integer,
    p_rows          jsonb,
    p_rejects       jsonb,
    p_watermark     timestamptz
)
RETURNS SETOF app.udt_sync_row_outcome_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_job           record;
    v_profile       record;
    v_source        text;
    v_cancel_status text;
    v_cancellable   text[];
    r               app.udt_external_invoice_input;
    v_ref           record;
    v_vendor_id     integer;
    v_invoice_id    integer;
    v_outcome       text;
    v_code          text;
    v_msg           text;
    v_pre_rejected  integer;
    v_counts        record;
    v_stats         jsonb;
BEGIN
    SELECT * INTO v_job FROM app.integration_sync_jobs WHERE id = p_job_id FOR UPDATE;
    IF NOT FOUND OR v_job.status <> 'running' OR v_job.worker_id IS DISTINCT FROM p_worker_id THEN
        RAISE EXCEPTION 'Job % is no longer owned by this worker.', p_job_id USING ERRCODE = 'CA409';
    END IF;

    SELECT p.id, p.name, p.module_id, p.default_status, p.cancellation_rule INTO v_profile
    FROM app.integration_profiles p
    WHERE p.id = p_profile_id AND p.integration_id = v_job.integration_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile % not found for this integration.', p_profile_id USING ERRCODE = 'CA404';
    END IF;

    SELECT source_system INTO v_source FROM app.integrations WHERE id = v_job.integration_id;

    v_cancel_status := coalesce(v_profile.cancellation_rule ->> 'setStatus', 'Rejected');
    v_cancellable := ARRAY(SELECT jsonb_array_elements_text(coalesce(v_profile.cancellation_rule -> 'onlyWhenStatusIn', '[]'::jsonb)));
    IF cardinality(v_cancellable) = 0 THEN
        v_cancellable := ARRAY['Pending'];
    END IF;

    -- Records the backend could not map / validate
    INSERT INTO app.integration_sync_errors (job_id, profile_id, stage, external_key, message, details)
    SELECT p_job_id, p_profile_id,
           CASE WHEN e.stage IN ('fetch', 'mapping', 'validation', 'persistence', 'review') THEN e.stage ELSE 'validation' END,
           left(e.external_key, 200), left(coalesce(e.message, 'Invalid record'), 2000), e.details
    FROM jsonb_populate_recordset(NULL::app.udt_sync_error_input, coalesce(p_rejects, '[]'::jsonb)) e;
    GET DIAGNOSTICS v_pre_rejected = ROW_COUNT;

    CREATE TEMP TABLE IF NOT EXISTS tmp_sync_outcomes (
        row_no integer, external_key text, outcome text, invoice_code text, message text
    ) ON COMMIT DROP;
    TRUNCATE tmp_sync_outcomes;

    FOR r IN
        SELECT * FROM jsonb_populate_recordset(NULL::app.udt_external_invoice_input, coalesce(p_rows, '[]'::jsonb))
        ORDER BY row_no
    LOOP
        v_outcome := NULL;
        v_code := r.invoice_code;
        v_msg := NULL;
        BEGIN
            IF r.external_key IS NULL OR r.invoice_code IS NULL OR r.vendor_name IS NULL OR r.cuit IS NULL
               OR r.amount IS NULL OR r.reception_date IS NULL OR r.payload_hash IS NULL THEN
                RAISE EXCEPTION 'Missing required invoice fields.' USING ERRCODE = 'CA400';
            END IF;

            SELECT ref.id, ref.invoice_id, ref.payload_hash, ref.source_state, i.status, i.invoice_code
            INTO v_ref
            FROM app.invoice_external_refs ref
            JOIN app.invoices i ON i.id = ref.invoice_id
            WHERE ref.source_system = v_source AND ref.external_key = r.external_key
            FOR UPDATE OF ref, i;

            IF NOT FOUND THEN
                IF coalesce(r.cancelled, false) THEN
                    v_outcome := 'skipped';
                    v_msg := 'Cancelled in the source before it was imported';
                ELSE
                    IF EXISTS (SELECT 1 FROM app.invoices WHERE invoice_code = r.invoice_code) THEN
                        RAISE EXCEPTION 'Invoice id % is already used by another invoice.', r.invoice_code USING ERRCODE = 'CA409';
                    END IF;

                    INSERT INTO app.vendors (legal_name, cuit) VALUES (r.vendor_name, r.cuit) ON CONFLICT (cuit) DO NOTHING;
                    SELECT id INTO v_vendor_id FROM app.vendors WHERE cuit = r.cuit;

                    INSERT INTO app.invoices
                        (invoice_code, module_id, vendor_id, invoice_1a, invoice_2a, first_invoice_number,
                         second_invoice_number, invoice_date, currency_code, amount, invoice_subtotal,
                         invoice_subtotal_with_tax, credit_note, status, reception_date, created_by)
                    VALUES
                        (r.invoice_code, v_profile.module_id, v_vendor_id, r.invoice_1a, r.invoice_2a, r.first_invoice_number,
                         r.second_invoice_number, r.invoice_date, coalesce(r.currency_code, 'ARS'), r.amount,
                         coalesce(r.invoice_subtotal, r.amount), r.invoice_subtotal_with_tax, coalesce(r.credit_note, false),
                         v_profile.default_status, r.reception_date, NULL)
                    RETURNING id INTO v_invoice_id;

                    INSERT INTO app.invoice_external_refs
                        (invoice_id, source_system, external_key, integration_id, profile_id, external_doc,
                         source_changed_at, payload_hash, source_state, first_job_id, last_job_id)
                    VALUES
                        (v_invoice_id, v_source, r.external_key, v_job.integration_id, p_profile_id, r.external_doc,
                         r.source_changed_at, r.payload_hash, 'active', p_job_id, p_job_id);

                    v_outcome := 'created';
                END IF;
            ELSIF v_ref.payload_hash = r.payload_hash THEN
                UPDATE app.invoice_external_refs SET last_job_id = p_job_id, last_synced_at = now() WHERE id = v_ref.id;
                v_code := v_ref.invoice_code;
                v_outcome := 'unchanged';
            ELSE
                INSERT INTO app.vendors (legal_name, cuit) VALUES (r.vendor_name, r.cuit) ON CONFLICT (cuit) DO NOTHING;
                SELECT id INTO v_vendor_id FROM app.vendors WHERE cuit = r.cuit;

                -- Source-owned fields only: status, team, assignee, process, claim ... stay as they are
                UPDATE app.invoices SET
                    vendor_id                 = v_vendor_id,
                    invoice_1a                = r.invoice_1a,
                    invoice_2a                = r.invoice_2a,
                    first_invoice_number      = r.first_invoice_number,
                    second_invoice_number     = r.second_invoice_number,
                    invoice_date              = r.invoice_date,
                    currency_code             = coalesce(r.currency_code, currency_code),
                    amount                    = r.amount,
                    invoice_subtotal          = coalesce(r.invoice_subtotal, r.amount),
                    invoice_subtotal_with_tax = r.invoice_subtotal_with_tax,
                    credit_note               = coalesce(r.credit_note, false),
                    reception_date            = r.reception_date,
                    updated_at                = now()
                WHERE id = v_ref.invoice_id;

                IF coalesce(r.cancelled, false) AND v_ref.source_state = 'active' THEN
                    IF v_ref.status = ANY (v_cancellable) THEN
                        UPDATE app.invoices SET status = v_cancel_status WHERE id = v_ref.invoice_id;
                        v_msg := 'Cancelled in the source: status set to ' || v_cancel_status;
                    ELSE
                        v_msg := 'Cancelled in the source after processing started (status ' || v_ref.status
                                 || '); status left unchanged';
                        INSERT INTO app.integration_sync_errors (job_id, profile_id, stage, external_key, message, details)
                        VALUES (p_job_id, p_profile_id, 'review', left(r.external_key, 200), v_msg,
                                jsonb_build_object('invoiceCode', v_ref.invoice_code, 'status', v_ref.status));
                    END IF;
                END IF;

                UPDATE app.invoice_external_refs SET
                    payload_hash      = r.payload_hash,
                    source_changed_at = r.source_changed_at,
                    external_doc      = r.external_doc,
                    source_state      = CASE WHEN coalesce(r.cancelled, false) THEN 'cancelled' ELSE 'active' END,
                    last_job_id       = p_job_id,
                    last_synced_at    = now()
                WHERE id = v_ref.id;

                v_code := v_ref.invoice_code;
                v_outcome := 'updated';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- This row's savepoint is rolled back; the rest of the page continues
            v_msg := SQLERRM;
            v_outcome := CASE WHEN SQLSTATE IN ('CA400', 'CA409') THEN 'rejected' ELSE 'failed' END;
            INSERT INTO app.integration_sync_errors (job_id, profile_id, stage, external_key, message, details)
            VALUES (p_job_id, p_profile_id,
                    CASE WHEN v_outcome = 'rejected' THEN 'validation' ELSE 'persistence' END,
                    left(r.external_key, 200), left(v_msg, 2000),
                    jsonb_build_object('invoiceCode', r.invoice_code, 'sqlstate', SQLSTATE));
        END;

        INSERT INTO tmp_sync_outcomes VALUES (r.row_no, r.external_key, v_outcome, v_code, v_msg);
    END LOOP;

    SELECT count(*) FILTER (WHERE outcome = 'created')                    AS created,
           count(*) FILTER (WHERE outcome = 'updated')                    AS updated,
           count(*) FILTER (WHERE outcome IN ('unchanged', 'skipped'))    AS unchanged,
           count(*) FILTER (WHERE outcome = 'rejected') + v_pre_rejected  AS rejected,
           count(*) FILTER (WHERE outcome = 'failed')                     AS failed
    INTO v_counts
    FROM tmp_sync_outcomes;

    v_stats := coalesce(v_job.profile_stats -> p_profile_id::text, '{}'::jsonb);
    v_stats := jsonb_build_object(
        'name',      v_profile.name,
        'fetched',   coalesce((v_stats ->> 'fetched')::integer, 0)   + coalesce(p_fetched, 0),
        'created',   coalesce((v_stats ->> 'created')::integer, 0)   + v_counts.created,
        'updated',   coalesce((v_stats ->> 'updated')::integer, 0)   + v_counts.updated,
        'unchanged', coalesce((v_stats ->> 'unchanged')::integer, 0) + v_counts.unchanged,
        'rejected',  coalesce((v_stats ->> 'rejected')::integer, 0)  + v_counts.rejected,
        'failed',    coalesce((v_stats ->> 'failed')::integer, 0)    + v_counts.failed,
        'pages',     coalesce((v_stats ->> 'pages')::integer, 0)     + 1,
        'watermark', CASE WHEN v_counts.failed = 0 THEN coalesce(to_jsonb(p_watermark), v_stats -> 'watermark')
                          ELSE v_stats -> 'watermark' END
    );

    UPDATE app.integration_sync_jobs SET
        records_fetched   = records_fetched   + coalesce(p_fetched, 0),
        records_created   = records_created   + v_counts.created,
        records_updated   = records_updated   + v_counts.updated,
        records_unchanged = records_unchanged + v_counts.unchanged,
        records_rejected  = records_rejected  + v_counts.rejected,
        records_failed    = records_failed    + v_counts.failed,
        pages_processed   = pages_processed + 1,
        profile_stats     = jsonb_set(profile_stats, ARRAY[p_profile_id::text], v_stats),
        heartbeat_at      = now()
    WHERE id = p_job_id;

    -- A row that failed to persist must be fetched again next run, so its page keeps the old cursor
    -- (the backend also stops passing a watermark for the rest of that profile's run)
    IF p_watermark IS NOT NULL AND v_counts.failed = 0 THEN
        UPDATE app.integration_profiles
        SET watermark = greatest(watermark, p_watermark), watermark_updated_at = now()
        WHERE id = p_profile_id;
    END IF;

    RETURN QUERY SELECT t.row_no, t.external_key, t.outcome, t.invoice_code, t.message FROM tmp_sync_outcomes t ORDER BY t.row_no;
END;
$$;
