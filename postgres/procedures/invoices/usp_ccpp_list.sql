-- =====================================================================
-- app.usp_ccpp_list - GP Invoice Detail "CCPP" tab: list rows linked to one invoice
-- Request:  p_invoice_code
-- Response: SETOF app.udt_ccpp_result (empty when the invoice has no CCPP rows)
-- Errors:   CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_ccpp_list(p_invoice_code text)
RETURNS SETOF app.udt_ccpp_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_invoice_id integer;
BEGIN
    SELECT i.id INTO v_invoice_id FROM app.invoices i WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN QUERY
        SELECT c.id, c.invoice_id, c.product, c.legal_doc_issuer, c.status, c.value, c.km, c.tons, c.unit_rate, c.km_fc, c.tons_fc,
               c.third_jurisdiction, c.ab, c.aux, c.bp, c.closed_quantity, c.pending_quantity, c.total_quantity,
               c.cc, c.cia, c.withholding_code, c.withholding_concept, c.matching, c.created_by, ccb.name,
               c.account, c.cuit, c.line_description, c.receipt_detail, c.status1, c.status2, c.receipt_date,
               c.gcia, c.name, c.iibb_destination, c.iibb_origin, c.closed_amount, c.line_amount,
               c.matched_amount, c.pending_amount, c.order_total_amount, c.vat, c.updated_by, cub.name,
               c.line, c.currency, c.municipality, c.order_number, c.receipt_number, c.observation,
               c.origin_destination_drei, c.owner_legacy_id, c.praclo, c.praptd, c.prdgl, c.province,
               c.pruorg, c.suss, c.tax_area, c.order_type, c.receipt_type, c.take_line, c.unique_ccpp,
               c.user_legacy_id, c.fiscal_zone
        FROM app.invoice_ccpps c
        LEFT JOIN app.users ccb ON ccb.id = c.created_by
        LEFT JOIN app.users cub ON cub.id = c.updated_by
        WHERE c.invoice_id = v_invoice_id
        ORDER BY c.id;
END;
$$;
