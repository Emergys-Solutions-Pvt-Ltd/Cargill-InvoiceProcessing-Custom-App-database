-- =====================================================================
-- app.usp_attachment_add - registers a file uploaded from the Invoice Details PDF viewer
-- (the backend has already written it under the storage root).
-- Request:  p_invoice_code, file metadata, p_storage_path (relative to the storage root),
--           p_is_primary = true makes it the invoice's main PDF (the previous one stays attached)
-- Response: app.udt_attachment_result
-- Errors:   CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_attachment_add(
    p_invoice_code  text,
    p_file_name     text,
    p_title         text,
    p_category      text,
    p_mime_type     text,
    p_size_bytes    bigint,
    p_storage_path  text,
    p_is_primary    boolean DEFAULT false
)
RETURNS app.udt_attachment_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    integer;
    v_app_code      text;
    v_result        app.udt_attachment_result;
BEGIN
    SELECT i.id, a.code INTO v_invoice_id, v_app_code
    FROM app.invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    IF p_is_primary THEN
        UPDATE app.invoice_attachments SET is_primary = false WHERE invoice_id = v_invoice_id AND is_primary;
    END IF;

    INSERT INTO app.invoice_attachments
        (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
    VALUES
        (v_invoice_id, p_file_name, nullif(btrim(p_title), ''), coalesce(nullif(btrim(p_category), ''), 'Uploaded Document'),
         coalesce(p_mime_type, 'application/pdf'), p_size_bytes, p_storage_path, coalesce(p_is_primary, false))
    RETURNING id, invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary, uploaded_at, v_app_code
    INTO v_result;

    RETURN v_result;
END;
$$;
