-- =====================================================================
-- app.vw_invoice_summary - invoice header joined with module, application, vendor,
-- station and its primary attachment. The first columns match app.udt_invoice_result
-- in order, so functions can build that type with ROW(...)::app.udt_invoice_result.
-- Used by: usp_invoice_list, usp_invoice_get_by_code
-- =====================================================================
CREATE OR REPLACE VIEW app.vw_invoice_summary AS
SELECT
    i.id,
    i.invoice_code,
    m.slug              AS module_slug,
    m.invoice_prefix,
    a.code              AS application_code,
    i.invoice_1a,
    i.invoice_2a,
    i.first_invoice_number,
    i.second_invoice_number,
    i.invoice_date,
    i.expiry_days,
    i.invoice_expiry_date,
    i.support_team,
    i.pre_settlement_number,
    i.credit_note,
    i.currency_code,
    i.amount,
    i.invoice_subtotal,
    i.invoice_subtotal_with_tax,
    i.status,
    i.reception_date,
    i.email_reception_date,
    v.legal_name        AS vendor_name,
    v.cuit,
    s.display_name      AS country_station,
    pdf.id              AS pdf_attachment_id,
    pdf.file_name       AS pdf_file_name,
    pdf.title           AS pdf_title,
    pdf.mime_type       AS pdf_mime_type,
    -- workflow / Super User fields (Invoice Details page)
    i.process_id,
    pr.name             AS process_name,
    i.origin_city_id,
    oc.name             AS origin_name,
    i.destination_city_id,
    dc.name             AS destination_name,
    i.team_id,
    tm.name             AS team_name,
    i.assigned_user_id,
    au.name             AS assigned_user_name,
    i.claim_number,
    i.additional_info,
    i.filenet_id,
    -- filter column, not part of udt_invoice_result
    i.module_id
FROM app.invoices i
JOIN app.app_modules m  ON m.id = i.module_id
JOIN app.applications a ON a.id = m.application_id
JOIN app.vendors v      ON v.id = i.vendor_id
LEFT JOIN app.country_stations s ON s.id = i.station_id
LEFT JOIN app.processes pr ON pr.id = i.process_id
LEFT JOIN app.cities oc    ON oc.id = i.origin_city_id
LEFT JOIN app.cities dc    ON dc.id = i.destination_city_id
LEFT JOIN app.teams tm     ON tm.id = i.team_id
LEFT JOIN app.users au     ON au.id = i.assigned_user_id
LEFT JOIN LATERAL (
    SELECT att.id, att.file_name, att.title, att.mime_type
    FROM app.invoice_attachments att
    WHERE att.invoice_id = i.id
    ORDER BY att.is_primary DESC, att.id
    LIMIT 1
) pdf ON true;
