-- =====================================================================
-- app.usp_invoice_get_by_code - Invoice Detail screen in one round trip
-- Request:  p_invoice_code, e.g. 'INV-GP-1015'
-- Response: SETOF app.udt_invoice_detail_result (no row when not found):
--             invoice     = app.udt_invoice_result
--             attachments = app.udt_attachment_result[] (primary first)
--             line_items  = app.udt_line_item_result[]
--             ccpps       = app.udt_ccpp_result[]
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
            v.claim_number, v.additional_info, v.filenet_id
        )::app.udt_invoice_result),
        coalesce((
            SELECT jsonb_agg(to_jsonb(ROW(
                       att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
                       att.storage_path, att.is_primary, att.uploaded_at, v.application_code
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
                       c.id, c.product, c.legal_doc_issuer, c.status, c.value, c.km, c.tons, c.unit_rate, c.km_fc, c.tons_fc
                   )::app.udt_ccpp_result) ORDER BY c.id)
            FROM app.invoice_ccpps c WHERE c.invoice_id = v.id
        ), '[]'::jsonb)
    FROM app.vw_invoice_summary v
    WHERE v.invoice_code = p_invoice_code;
$$;
