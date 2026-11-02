-- =====================================================================
-- app.usp_integration_invoices_without_attachment - sync worker: which of the given invoices still
-- have no attachment, so the source document (e.g. the OnBase PDF) must be attached.
-- Request:  p_invoice_codes (invoice ids of one processed page)
-- Response: SETOF app.udt_code_result - the codes without any attachment
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_invoices_without_attachment(p_invoice_codes text[])
RETURNS SETOF app.udt_code_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(i.invoice_code)::app.udt_code_result
    FROM app.invoices i
    WHERE i.invoice_code = ANY (coalesce(p_invoice_codes, ARRAY[]::text[]))
      AND NOT EXISTS (SELECT 1 FROM app.invoice_attachments a WHERE a.invoice_id = i.id);
$$;
