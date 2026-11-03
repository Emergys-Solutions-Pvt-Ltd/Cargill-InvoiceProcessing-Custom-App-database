-- =====================================================================
-- One-time migration, after <app>/invoices/migrations/split_from_app_invoices.sql of every app:
-- checks that every row of the former common invoice tables arrived in exactly one app's tables,
-- then drops the common tables (app.invoices, its child tables, gpp.invoice_sf_fields and
-- sjo.invoice_sjo_fields, whose columns now live on gpp.gpp_invoices / sjo.sjo_invoices).
-- Any mismatch raises, rolling the whole deploy back. No-op once app.invoices is gone.
-- The app schemas come from app.applications.db_schema.
-- =====================================================================
DO $$
DECLARE
    v_table     text;
    v_old       bigint;
    v_new       bigint;
    v_n         bigint;
    v_schema    text;
BEGIN
    IF to_regclass('app.invoices') IS NULL THEN
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id
               JOIN app.applications a ON a.id = m.application_id WHERE a.db_schema IS NULL) THEN
        RAISE EXCEPTION 'Invoices of an application without db_schema cannot be moved.';
    END IF;

    FOREACH v_table IN ARRAY ARRAY['invoices', 'invoice_attachments', 'invoice_line_items', 'invoice_source_emails', 'invoice_external_refs']
    LOOP
        EXECUTE format('SELECT count(*) FROM app.%I', v_table) INTO v_old;
        v_new := 0;
        FOR v_schema IN SELECT DISTINCT db_schema FROM app.applications WHERE db_schema IS NOT NULL
        LOOP
            EXECUTE format('SELECT count(*) FROM %I.%I', v_schema,
                           CASE WHEN v_table = 'invoices' THEN v_schema || '_invoices' ELSE v_table END) INTO v_n;
            v_new := v_new + v_n;
        END LOOP;
        IF v_old <> v_new THEN
            RAISE EXCEPTION 'Invoice split incomplete for %: % row(s) in app, % in the app schemas.', v_table, v_old, v_new;
        END IF;
    END LOOP;

    -- app.mailbox_emails (mailbox feature, not created by these scripts) pointed at app.invoices; its
    -- invoice link cannot follow one table any more. Only this constraint is dropped (no email was linked
    -- when the split ran); its owner must reference the app's invoice table instead. Any other object
    -- still depending on app.invoices makes the DROP below fail and rolls the deploy back.
    IF to_regclass('app.mailbox_emails') IS NOT NULL THEN
        ALTER TABLE app.mailbox_emails DROP CONSTRAINT IF EXISTS fk_mailbox_emails_invoice;
    END IF;

    DROP VIEW IF EXISTS app.vw_invoice_summary;   -- recreated per app as <app>.vw_invoice_summary
    DROP TABLE app.invoice_attachments;
    DROP TABLE app.invoice_source_emails;
    DROP TABLE app.invoice_line_items;
    DROP TABLE app.invoice_external_refs;
    DROP TABLE IF EXISTS gpp.invoice_sf_fields;
    DROP TABLE IF EXISTS sjo.invoice_sjo_fields;
    DROP TABLE app.invoices;
END $$;
