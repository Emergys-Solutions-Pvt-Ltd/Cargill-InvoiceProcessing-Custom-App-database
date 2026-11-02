-- =====================================================================
-- app.usp_invoice_get_by_code - Invoice Detail screen in one round trip
-- Request:  p_invoice_code, e.g. 'INV-GP-1015'
-- Response: SETOF app.udt_invoice_detail_result (no row when not found):
--             invoice     = app.udt_invoice_result
--             attachments = app.udt_attachment_result[] (primary first)
--             line_items  = app.udt_line_item_result[]
--             ccpps       = app.udt_ccpp_result[]
--             source_email = app.udt_invoice_email_result (NULL when not received by email)
--             sf_fields    = app.udt_invoice_sf_fields_result (NULL when the invoice has no row yet)
--             sjo_fields   = app.udt_invoice_sjo_fields_result (NULL for non-SJO invoices)
--           The caller checks access using invoice.application_code.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_get_by_code(p_invoice_code text)
RETURNS SETOF app.udt_invoice_detail_result
LANGUAGE sql
STABLE
AS $$
    SELECT
        to_jsonb(ROW(
            v.id, v.invoice_code, v.module_slug, v.invoice_prefix, v.application_code, v.invoice_1a, v.invoice_2a,
            v.first_invoice_number, v.second_invoice_number, v.invoice_date, v.expiry_days, v.invoice_expiry_date,
            v.support_team, v.pre_settlement_number, v.credit_note, v.currency_code, v.amount, v.invoice_subtotal,
            v.invoice_subtotal_with_tax, v.status, v.reception_date, v.email_reception_date, v.vendor_name, v.cuit,
            v.country_station, v.pdf_attachment_id, v.pdf_file_name, v.pdf_title, v.pdf_mime_type,
            v.process_id, v.process_name, v.origin_city_id, v.origin_name, v.destination_city_id,
            v.destination_name, v.team_id, v.team_name, v.assigned_user_id, v.assigned_user_name,
            v.claim_number, v.additional_info, v.filenet_id, v.created_by, v.created_by_name,
            v.updated_by, v.updated_by_name, v.is_manual
        )::app.udt_invoice_result),
        coalesce((
            SELECT jsonb_agg(to_jsonb(ROW(
                       att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
                       att.storage_path, att.is_primary, att.uploaded_at, v.application_code,
                       att.storage_provider, att.storage_bucket, att.content_sha256
                   )::app.udt_attachment_result) ORDER BY att.is_primary DESC, att.id)
            FROM app.invoice_attachments att WHERE att.invoice_id = v.id
        ), '[]'::jsonb),
        coalesce((
            SELECT jsonb_agg(to_jsonb(ROW(
                       li.line_no, li.code, li.description, li.quantity, li.unit_of_measure, li.unit_price,
                       li.discount, li.subtotal, li.vat_rate, li.subtotal_with_vat
                   )::app.udt_line_item_result) ORDER BY li.line_no)
            FROM app.invoice_line_items li WHERE li.invoice_id = v.id
        ), '[]'::jsonb),
        coalesce((
            SELECT jsonb_agg(to_jsonb(ROW(
                       c.id, c.invoice_id, c.product, c.legal_doc_issuer, c.status, c.value, c.km, c.tons, c.unit_rate, c.km_fc, c.tons_fc,
                       c.third_jurisdiction, c.ab, c.aux, c.bp, c.closed_quantity, c.pending_quantity, c.total_quantity,
                       c.cc, c.cia, c.withholding_code, c.withholding_concept, c.matching, c.created_by, ccb.name,
                       c.account, c.cuit, c.line_description, c.receipt_detail, c.status1, c.status2, c.receipt_date,
                       c.gcia, c.name, c.iibb_destination, c.iibb_origin, c.closed_amount, c.line_amount,
                       c.matched_amount, c.pending_amount, c.order_total_amount, c.vat, c.updated_by, cub.name,
                       c.line, c.currency, c.municipality, c.order_number, c.receipt_number, c.observation,
                       c.origin_destination_drei, c.owner_legacy_id, c.praclo, c.praptd, c.prdgl, c.province,
                       c.pruorg, c.suss, c.tax_area, c.order_type, c.receipt_type, c.take_line, c.unique_ccpp,
                       c.user_legacy_id, c.fiscal_zone
                   )::app.udt_ccpp_result) ORDER BY c.id)
            FROM app.invoice_ccpps c
            LEFT JOIN app.users ccb ON ccb.id = c.created_by
            LEFT JOIN app.users cub ON cub.id = c.updated_by
            WHERE c.invoice_id = v.id
        ), '[]'::jsonb),
        (
            SELECT to_jsonb(ROW(
                       e.id, e.message_id, e.from_name, e.from_address, e.to_addresses, e.cc_addresses,
                       e.subject, e.body_text, e.received_at,
                       coalesce((
                           SELECT jsonb_agg(to_jsonb(ROW(
                                      att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type,
                                      att.size_bytes, att.storage_path, att.is_primary, att.uploaded_at, v.application_code,
                                      att.storage_provider, att.storage_bucket, att.content_sha256
                                  )::app.udt_attachment_result) ORDER BY att.is_primary DESC, att.id)
                           FROM app.invoice_attachments att WHERE att.source_email_id = e.id
                       ), '[]'::jsonb)
                   )::app.udt_invoice_email_result)
            FROM app.invoice_source_emails e WHERE e.invoice_id = v.id
        ),
        (
            SELECT to_jsonb(ROW(
                       sf.invoice_1a_2a_cancel, sf.first_invoice_number_cancel, sf.second_invoice_number_cancel,
                       sf.ab_number, sf.accounting_register, sf.code_of_imputation, sf.code_of_imputation_str,
                       sf.gp_code_of_imputation, sf.cost_center, sf.jde_number, sf.nro_de_o6, sf.po_number, sf.x1_number,
                       sf.owner_legacy_id, sf.user_legacy_id, sf.adjustment_approval, sf.branch_plant, sf.center,
                       sf.code_type, sf.drei, sf.adjustment_doc, sf.installment_payment, sf.invoice_type, sf.order_type,
                       sf.pending_reason, sf.reject_reason, sf.sub_process, sf.area, sf.cbs_observation,
                       sf.computation_formula, sf.expense_type, sf.admin_observation, sf.approval_observation,
                       sf.attachment_name_before_change, sf.credit_note_comments, sf.distribution_type, sf.notes,
                       sf.observation, sf.reject_observation, sf.client_email, sf.admin_approved_date, sf.approval_date,
                       sf.cae_expiration_date, sf.processed_date, sf.rejection_date, sf.cae_number, sf.exchange_rate,
                       sf.payment_term, sf.is_boortmal_invoice, sf.bu_employee_approver_done, sf.is_distribution,
                       sf.is_downloaded_invoice, sf.has_po, sf.is_high_priority, sf.is_invoice_paid, sf.need_approval,
                       sf.po_attached, sf.vip_control_done, sf.updated_at,
                       sf.cantidad, sf.description, sf.ros_cuit_legacy_id, sf.due_date_invoice, sf.producto
                   )::app.udt_invoice_sf_fields_result)
            FROM app.invoice_sf_fields sf WHERE sf.invoice_id = v.id
        ),
        app.ufn_invoice_sjo_fields(v.id)
    FROM app.vw_invoice_summary v
    WHERE v.invoice_code = p_invoice_code;
$$;
