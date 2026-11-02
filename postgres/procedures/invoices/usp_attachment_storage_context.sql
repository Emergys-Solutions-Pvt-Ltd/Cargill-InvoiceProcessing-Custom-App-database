-- =====================================================================
-- app.usp_attachment_storage_context - which application an invoice belongs to, for the storage
-- layout (S3: <App>/<YYYY>/<Mon>/<file name>) before its attachment is registered.
-- Request:  p_invoice_code
-- Response: SETOF app.udt_code_result - the application code (GP, sjo, rospbu); no row = not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_attachment_storage_context(p_invoice_code text)
RETURNS SETOF app.udt_code_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(a.code)::app.udt_code_result
    FROM app.invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE i.invoice_code = p_invoice_code;
$$;
