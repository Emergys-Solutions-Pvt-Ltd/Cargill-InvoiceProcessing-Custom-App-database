-- =====================================================================
-- One-time migration: copy the {{APP}} invoices (and their attachments, line items, source emails and
-- integration refs) out of the former common table app.invoices into {{S}}.{{T}}, keeping ids.
-- Runs only while app.invoices exists and {{S}}.{{T}} is still empty; common/invoices/migrations/
-- drop_app_invoices.sql then checks the counts and drops the common tables (same transaction).
-- =====================================================================
DO $$
BEGIN
    IF to_regclass('app.invoices') IS NULL OR EXISTS (SELECT 1 FROM {{S}}.{{T}}) THEN
        RETURN;
    END IF;

    INSERT INTO {{S}}.{{T}}
        (id, invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a, first_invoice_number,
         second_invoice_number, invoice_date, expiry_days, invoice_expiry_date, support_team, pre_settlement_number,
         credit_note, currency_code, amount, invoice_subtotal, invoice_subtotal_with_tax, status, reception_date,
         email_reception_date, process_id, origin_city_id, destination_city_id, team_id, assigned_user_id,
         claim_number, additional_info, filenet_id, created_by, updated_by, created_at, updated_at{{#gpp}},
         invoice_1a_2a_cancel, first_invoice_number_cancel, second_invoice_number_cancel, ab_number,
         accounting_register, code_of_imputation, code_of_imputation_str, gp_code_of_imputation, cost_center,
         jde_number, nro_de_o6, po_number, x1_number, owner_legacy_id, user_legacy_id, ros_cuit_legacy_id,
         adjustment_approval, branch_plant, center, code_type, drei, adjustment_doc, installment_payment,
         invoice_type, order_type, pending_reason, reject_reason, sub_process, producto, area, cbs_observation,
         computation_formula, expense_type, description, admin_observation, approval_observation,
         attachment_name_before_change, credit_note_comments, distribution_type, notes, observation,
         reject_observation, client_email, admin_approved_date, approval_date, cae_expiration_date, processed_date,
         rejection_date, due_date_invoice, cae_number, exchange_rate, payment_term, cantidad, is_boortmal_invoice,
         bu_employee_approver_done, is_distribution, is_downloaded_invoice, has_po, is_high_priority,
         is_invoice_paid, need_approval, po_attached, vip_control_done{{/gpp}}{{#sjo}},
         country_id, business_unit_id, erp_system_id, id_fiscal, ab_number, ab_name,
         flow_turn_down, critical_vendor, urgent_invoice{{/sjo}})
    SELECT i.id, i.invoice_code, i.module_id, i.vendor_id, i.station_id, i.invoice_1a, i.invoice_2a, i.first_invoice_number,
           i.second_invoice_number, i.invoice_date, i.expiry_days, i.invoice_expiry_date, i.support_team, i.pre_settlement_number,
           i.credit_note, i.currency_code, i.amount, i.invoice_subtotal, i.invoice_subtotal_with_tax, i.status, i.reception_date,
           i.email_reception_date, i.process_id, i.origin_city_id, i.destination_city_id, i.team_id, i.assigned_user_id,
           i.claim_number, i.additional_info, i.filenet_id, i.created_by, i.updated_by, i.created_at, i.updated_at{{#gpp}},
           sf.invoice_1a_2a_cancel, sf.first_invoice_number_cancel, sf.second_invoice_number_cancel, sf.ab_number,
           sf.accounting_register, sf.code_of_imputation, sf.code_of_imputation_str, sf.gp_code_of_imputation, sf.cost_center,
           sf.jde_number, sf.nro_de_o6, sf.po_number, sf.x1_number, sf.owner_legacy_id, sf.user_legacy_id, sf.ros_cuit_legacy_id,
           sf.adjustment_approval, sf.branch_plant, sf.center, sf.code_type, sf.drei, sf.adjustment_doc, sf.installment_payment,
           sf.invoice_type, sf.order_type, sf.pending_reason, sf.reject_reason, sf.sub_process, sf.producto, sf.area, sf.cbs_observation,
           sf.computation_formula, sf.expense_type, sf.description, sf.admin_observation, sf.approval_observation,
           sf.attachment_name_before_change, sf.credit_note_comments, sf.distribution_type, sf.notes, sf.observation,
           sf.reject_observation, sf.client_email, sf.admin_approved_date, sf.approval_date, sf.cae_expiration_date, sf.processed_date,
           sf.rejection_date, sf.due_date_invoice, sf.cae_number, sf.exchange_rate, sf.payment_term, sf.cantidad,
           coalesce(sf.is_boortmal_invoice, false), coalesce(sf.bu_employee_approver_done, false), coalesce(sf.is_distribution, false),
           coalesce(sf.is_downloaded_invoice, false), coalesce(sf.has_po, false), coalesce(sf.is_high_priority, false),
           coalesce(sf.is_invoice_paid, false), coalesce(sf.need_approval, false), coalesce(sf.po_attached, false),
           coalesce(sf.vip_control_done, false){{/gpp}}{{#sjo}},
           f.country_id, f.business_unit_id, f.erp_system_id, f.id_fiscal, f.ab_number, f.ab_name,
           coalesce(f.flow_turn_down, false), coalesce(f.critical_vendor, false), coalesce(f.urgent_invoice, false){{/sjo}}
    FROM app.invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
{{#gpp}}
    LEFT JOIN gpp.invoice_sf_fields sf ON sf.invoice_id = i.id
{{/gpp}}
{{#sjo}}
    LEFT JOIN sjo.invoice_sjo_fields f ON f.invoice_id = i.id
{{/sjo}}
    WHERE a.db_schema = '{{S}}';

    INSERT INTO {{S}}.invoice_source_emails
        (id, invoice_id, message_id, from_name, from_address, to_addresses, cc_addresses, subject, body_text, received_at, created_at)
    SELECT e.id, e.invoice_id, e.message_id, e.from_name, e.from_address, e.to_addresses, e.cc_addresses, e.subject,
           e.body_text, e.received_at, e.created_at
    FROM app.invoice_source_emails e JOIN {{S}}.{{T}} i ON i.id = e.invoice_id;

    INSERT INTO {{S}}.invoice_attachments
        (id, invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary, uploaded_at,
         source_email_id, storage_provider, storage_bucket, content_sha256, storage_etag)
    SELECT t.id, t.invoice_id, t.file_name, t.title, t.category, t.mime_type, t.size_bytes, t.storage_path, t.is_primary,
           t.uploaded_at, t.source_email_id, t.storage_provider, t.storage_bucket, t.content_sha256, t.storage_etag
    FROM app.invoice_attachments t JOIN {{S}}.{{T}} i ON i.id = t.invoice_id;

    INSERT INTO {{S}}.invoice_line_items
        (id, invoice_id, line_no, code, description, quantity, unit_of_measure, unit_price, discount, subtotal, vat_rate, subtotal_with_vat)
    SELECT li.id, li.invoice_id, li.line_no, li.code, li.description, li.quantity, li.unit_of_measure, li.unit_price,
           li.discount, li.subtotal, li.vat_rate, li.subtotal_with_vat
    FROM app.invoice_line_items li JOIN {{S}}.{{T}} i ON i.id = li.invoice_id;

    INSERT INTO {{S}}.invoice_external_refs
        (id, invoice_id, source_system, external_key, integration_id, profile_id, external_doc, source_changed_at,
         payload_hash, source_state, first_job_id, last_job_id, first_synced_at, last_synced_at)
    SELECT r.id, r.invoice_id, r.source_system, r.external_key, r.integration_id, r.profile_id, r.external_doc,
           r.source_changed_at, r.payload_hash, r.source_state, r.first_job_id, r.last_job_id, r.first_synced_at, r.last_synced_at
    FROM app.invoice_external_refs r JOIN {{S}}.{{T}} i ON i.id = r.invoice_id;

{{#gpp}}
    -- CCPP rows belong to GPP invoices only: rows of SJO / ROSPBU invoices cannot follow them
    DELETE FROM gpp.invoice_ccpps c WHERE NOT EXISTS (SELECT 1 FROM gpp.gpp_invoices i WHERE i.id = c.invoice_id);
    ALTER TABLE gpp.invoice_ccpps DROP CONSTRAINT IF EXISTS fk_ccpps_invoice;
    ALTER TABLE gpp.invoice_ccpps ADD CONSTRAINT fk_gpp_ccpps_invoice
        FOREIGN KEY (invoice_id) REFERENCES gpp.gpp_invoices (id) ON DELETE CASCADE;

{{/gpp}}
    -- Identity sequences continue after the copied ids
    PERFORM setval(pg_get_serial_sequence('{{S}}.{{T}}', 'id'), coalesce((SELECT max(id) FROM {{S}}.{{T}}), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('{{S}}.invoice_source_emails', 'id'), coalesce((SELECT max(id) FROM {{S}}.invoice_source_emails), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('{{S}}.invoice_attachments', 'id'), coalesce((SELECT max(id) FROM {{S}}.invoice_attachments), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('{{S}}.invoice_line_items', 'id'), coalesce((SELECT max(id) FROM {{S}}.invoice_line_items), 0) + 1, false);
    PERFORM setval(pg_get_serial_sequence('{{S}}.invoice_external_refs', 'id'), coalesce((SELECT max(id) FROM {{S}}.invoice_external_refs), 0) + 1, false);
END $$;
