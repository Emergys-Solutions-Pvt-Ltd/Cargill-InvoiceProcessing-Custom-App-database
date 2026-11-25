-- =====================================================================
-- Database tests for the invoice Audit History (app.invoice_audit_log, trg_<app>_invoices_audit,
-- app.ufn_invoice_audit_trigger, <app>.usp_invoice_audit_list).
-- Runs inside one transaction and ROLLS BACK: safe on a shared database.
--   psql "<connection>" -v ON_ERROR_STOP=1 -f database/postgres/tests/test_invoice_audit.sql
-- Each block uses ASSERT; the first failure aborts the script with a message.
-- Covers: Created (actor = created_by), Updated with changed fields only, actor from app.user_id,
-- reference ids stored as names, no row for a bookkeeping-only update, system updates (no actor),
-- list order + CA404, Deleted, every app table has the trigger.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

DO $$
DECLARE
    v_module    uuid := (SELECT id FROM app.app_modules WHERE slug = 'GP');
    v_admin     uuid := (SELECT id FROM app_auth.users WHERE username = 'admin');
    v_user      uuid := (SELECT id FROM app_auth.users WHERE username = 'GP');
    v_process   uuid := (SELECT id FROM app.processes WHERE is_active ORDER BY sort_order LIMIT 1);
    v_status    text := (SELECT code FROM app.statuses WHERE is_active AND code <> 'Pending' ORDER BY sort_order LIMIT 1);
    v_id        uuid;
    v_rows      app.udt_invoice_audit_result[];
    v_change    jsonb;
BEGIN
    ASSERT v_module IS NOT NULL AND v_admin IS NOT NULL AND v_user IS NOT NULL, 'seed data missing (run seed.sql first)';
    ASSERT v_process IS NOT NULL AND v_status IS NOT NULL, 'master data missing (process / status)';

    -- every app invoice table is audited
    ASSERT (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
             WHERE t.tgname IN ('trg_gpp_invoices_audit', 'trg_sjo_invoices_audit', 'trg_rospbu_invoices_audit')
               AND NOT t.tgisinternal AND t.tgenabled <> 'D') = 3, 'audit trigger missing on an app invoice table';

    PERFORM set_config('app.user_id', '', true);

    -- Created: actor = created_by
    INSERT INTO gpp.gpp_invoices (invoice_code, module_id, amount, reception_date, created_by)
    VALUES ('ZZAUDIT-1', v_module, 100, current_date, v_admin)
    RETURNING id INTO v_id;
    ASSERT (SELECT count(*) FROM app.invoice_audit_log WHERE invoice_id = v_id) = 1, 'one Created row expected';
    ASSERT (SELECT action = 'Created' AND actor_user_id = v_admin AND app_schema = 'gpp' AND changes IS NULL
              FROM app.invoice_audit_log WHERE invoice_id = v_id), 'Created row: action / actor / schema';

    -- Updated by a user of the API (session setting app.user_id): only the status, actor = that user
    PERFORM set_config('app.user_id', v_user::text, true);
    PERFORM gpp.usp_invoice_update_status('ZZAUDIT-1', v_status);
    SELECT changes INTO v_change FROM app.invoice_audit_log WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1;
    ASSERT jsonb_array_length(v_change) = 1, 'status change: exactly one changed field (updated_at ignored), got ' || v_change;
    ASSERT v_change -> 0 ->> 'field' = 'status' AND v_change -> 0 ->> 'oldValue' = 'Pending'
       AND v_change -> 0 ->> 'newValue' = v_status, 'status change values: ' || v_change;
    ASSERT (SELECT actor_user_id FROM app.invoice_audit_log WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1) = v_user,
        'actor must come from app.user_id';

    -- Updated without the session setting: actor = the updated_by the statement set; reference id stored as its name
    PERFORM set_config('app.user_id', '', true);
    PERFORM gpp.usp_invoice_update_details('ZZAUDIT-1', v_process, NULL, NULL, 5, 'note', NULL, v_admin);
    SELECT changes INTO v_change FROM app.invoice_audit_log WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1;
    ASSERT (SELECT actor_user_id FROM app.invoice_audit_log WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1) = v_admin,
        'actor must fall back to the changed updated_by';
    ASSERT (SELECT e ->> 'newValue' FROM jsonb_array_elements(v_change) e WHERE e ->> 'field' = 'process_id')
         = (SELECT name FROM app.processes WHERE id = v_process), 'process_id must be stored as the process name: ' || v_change;
    ASSERT (SELECT e ->> 'oldValue' IS NULL FROM jsonb_array_elements(v_change) e WHERE e ->> 'field' = 'process_id'),
        'old process must be NULL';
    ASSERT (SELECT count(*) FROM jsonb_array_elements(v_change) e
             WHERE e ->> 'field' IN ('claim_number', 'additional_info', 'process_id')) = 3, 'details fields: ' || v_change;
    ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_change) e WHERE e ->> 'field' IN ('updated_at', 'updated_by')),
        'bookkeeping columns must not be listed';

    -- Bookkeeping-only update: no row
    UPDATE gpp.gpp_invoices SET updated_at = now() + interval '1 minute', updated_by = v_user WHERE id = v_id;
    ASSERT (SELECT count(*) FROM app.invoice_audit_log WHERE invoice_id = v_id) = 3, 'no row for a bookkeeping-only update';

    -- System update (no session setting, updated_by unchanged): actor NULL
    UPDATE gpp.gpp_invoices SET claim_number = 7 WHERE id = v_id;
    ASSERT (SELECT actor_user_id IS NULL FROM app.invoice_audit_log WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1),
        'system update must have no actor';

    -- List: newest first, names joined, CA404
    SELECT array_agg(r) INTO v_rows FROM gpp.usp_invoice_audit_list('ZZAUDIT-1') r;
    ASSERT array_length(v_rows, 1) = 4, 'list must return 4 events';
    ASSERT v_rows[1].action = 'Updated' AND v_rows[1].actor_name IS NULL, 'newest event first (system update)';
    ASSERT v_rows[4].action = 'Created' AND v_rows[4].actor_name = (SELECT name FROM app_auth.users WHERE id = v_admin),
        'oldest event last with the creator name';

    -- the invoice belongs to GPP: another app's list does not find it
    BEGIN
        PERFORM sjo.usp_invoice_audit_list('ZZAUDIT-1');
        ASSERT false, 'expected CA404 for an invoice of another app';
    EXCEPTION WHEN SQLSTATE 'CA404' THEN NULL;
    END;

    -- Deleted: row kept after the invoice is gone
    PERFORM set_config('app.user_id', v_admin::text, true);
    DELETE FROM gpp.gpp_invoices WHERE id = v_id;
    ASSERT (SELECT action = 'Deleted' AND actor_user_id = v_admin FROM app.invoice_audit_log
             WHERE invoice_id = v_id ORDER BY event_seq DESC LIMIT 1), 'Deleted row with the acting user';
    ASSERT (SELECT count(*) FROM app.invoice_audit_log WHERE invoice_id = v_id) = 5, 'history survives the delete';
END $$;

\echo 'All invoice audit database tests passed.'
ROLLBACK;
