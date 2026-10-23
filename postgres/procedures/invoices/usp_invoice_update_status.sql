-- =====================================================================
-- app.usp_invoice_update_status - change an invoice's workflow status
-- Request:  p_invoice_code, p_status (an active app.statuses code, case-insensitive)
-- Response: app.udt_row_count_result
-- Errors:   CA400 unknown / inactive status, CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_update_status(p_invoice_code text, p_status text)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_status    text;
    v_rows      integer;
BEGIN
    SELECT code INTO v_status FROM app.statuses WHERE lower(code) = lower(p_status) AND is_active;
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Status must be one of %.',
            (SELECT string_agg(code, ', ' ORDER BY sort_order) FROM app.statuses WHERE is_active)
            USING ERRCODE = 'CA400';
    END IF;

    UPDATE app.invoices SET status = v_status, updated_at = now() WHERE invoice_code = p_invoice_code;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
