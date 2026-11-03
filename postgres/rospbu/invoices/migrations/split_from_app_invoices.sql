-- GENERATED from common/invoices/templates/migrations/split_from_app_invoices.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- One-time migration: copy the ROSPBU invoices (and their attachments, line items, source emails and
-- integration refs) out of the former common table app.invoices into rospbu.rospbu_invoices, keeping ids.
-- Runs only while app.invoices exists and rospbu.rospbu_invoices is still empty; common/invoices/migrations/
-- drop_app_invoices.sql then checks the counts and drops the common tables (same transaction).
-- =====================================================================
DO $$
BEGIN
    IF to_regclass('app.invoices') IS NULL OR EXISTS (SELECT 1 FROM rospbu.rospbu_invoices) THEN
        RETURN;
    END IF;

    INSERT INTO rospbu.rospbu_invoices
        (id, invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a, first_invoice_number,
         second_invoice_number, invoice_date, expiry_days, invoice_expiry_date, support_team, pre_settlement_number,
         credit_note, currency_code, amount, invoice_subtotal, invoice_subtotal_with_tax, status, reception_date,
         email_reception_date, process_id, origin_city_id, destination_city_id, team_id, assigned_user_id,
         claim_number, additional_info, filenet_id, created_by, updated_by, created_at, updated_at)
    SELECT i.id, i.invoice_code, i.module_id, i.vendor_id, i.station_id, i.invoice_1a, i.invoice_2a, i.first_invoice_number,
           i.second_invoice_number, i.invoice_date, i.expiry_days, i.invoice_expiry_date, i.support_team, i.pre_settlement_number,
           i.credit_note, i.currency_code, i.amount, i.invoice_subtotal, i.invoice_subtotal_with_tax, i.status, i.reception_date,
           i.email_reception_date, i.process_id, i.origin_city_id, i.destination_city_id, i.team_id, i.assigned_user_id,
           i.claim_number, i.additional_info, i.filenet_id, i.created_by, i.updated_by, i.created_at, i.updated_at
    FROM app.invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id

    WHERE a.db_schema = 'rospbu';

    INSERT INTO rospbu.invoice_source_emails
        (id, invoice_id, message_id, from_name, from_address, to_addresses, cc_addresses, subject, body_text, received_at, created_at)
    SELECT e.id, e.invoice_id, e.message_id, e.from_name, e.from_address, e.to_addresses, e.cc_addresses, e.subject,
           e.body_text, e.received_at, e.created_at
    FROM app.invoice_source_emails e JOIN rospbu.rospbu_invoices i ON i.id = e.invoice_id;

    INSERT INTO rospbu.invoice_attachments
        (id, invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary, uploaded_at,
         source_email_id, storage_provider, storage_bucket, content_sha256, storage_etag)
    SELECT t.id, t.invoice_id, t.file_name, t.title, t.category, t.mime_type, t.size_bytes, t.storage_path, t.is_primary,
           t.uploaded_at, t.source_email_id, t.storage_provider, t.storage_bucket, t.content_sha256, t.storage_etag
    FROM app.invoice_attachments t JOIN rospbu.rospbu_invoices i ON i.id = t.invoice_id;

    INSERT INTO rospbu.invoice_line_items
        (id, invoice_id, line_no, code, description, quantity, unit_of_measure, unit_price, discount, subtotal, vat_rate, subtotal_with_vat)
    SELECT li.id, li.invoice_id, li.line_no, li.code, li.description, li.quantity, li.unit_of_measure, li.unit_price,
           li.discount, li.subtotal, li.vat_rate, li.subtotal_with_vat
    FROM app.invoice_line_items li JOIN rospbu.rospbu_invoices i ON i.id = li.invoice_id;

    INSERT INTO rospbu.invoice_external_refs
        (id, invoice_id, source_system, external_key, integration_id, profile_id, external_doc, source_changed_at,
         payload_hash, source_state, first_job_id, last_job_id, first_synced_at, last_synced_at)
    SELECT r.id, r.invoice_id, r.source_system, r.external_key, r.integration_id, r.profile_id, r.external_doc,
           r.source_changed_at, r.payload_hash, r.source_state, r.first_job_id, r.last_job_id, r.first_synced_at, r.last_synced_at
    FROM app.invoice_external_refs r JOIN rospbu.rospbu_invoices i ON i.id = r.invoice_id;

    -- Identity sequences continue after the copied ids
    PERFORM setval(pg_get_serial_sequence('rospbu.rospbu_invoices', 'id'), coalesce((SELECT max(id) FROM rospbu.rospbu_invoices), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('rospbu.invoice_source_emails', 'id'), coalesce((SELECT max(id) FROM rospbu.invoice_source_emails), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('rospbu.invoice_attachments', 'id'), coalesce((SELECT max(id) FROM rospbu.invoice_attachments), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('rospbu.invoice_line_items', 'id'), coalesce((SELECT max(id) FROM rospbu.invoice_line_items), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('rospbu.invoice_external_refs', 'id'), coalesce((SELECT max(id) FROM rospbu.invoice_external_refs), 0) + 1, false);
END $$;
