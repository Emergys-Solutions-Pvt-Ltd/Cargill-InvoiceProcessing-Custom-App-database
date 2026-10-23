-- =====================================================================
-- app.usp_attachment_get_by_id - attachment metadata for the signed file download
-- Request:  p_attachment_id
-- Response: SETOF app.udt_attachment_result (no rows when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_attachment_get_by_id(p_attachment_id integer)
RETURNS SETOF app.udt_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
           att.storage_path, att.is_primary, att.uploaded_at, a.code
    FROM app.invoice_attachments att
    JOIN app.invoices i     ON i.id = att.invoice_id
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE att.id = p_attachment_id;
$$;
