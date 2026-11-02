-- =====================================================================
-- app.ufn_invoice_sjo_fields - one invoice's SJO fields as app.udt_invoice_sjo_fields_result JSON
-- (country / BU / ERP resolved to code and name); NULL when the invoice has no SJO row.
-- Used by: usp_invoice_list, usp_invoice_get_by_code
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_invoice_sjo_fields(p_invoice_id integer)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT to_jsonb(ROW(
               f.country_id, c.code, c.name,
               f.business_unit_id, bu.code, bu.name,
               f.erp_system_id, e.code, e.name,
               f.id_fiscal, f.ab_number, f.ab_name,
               f.flow_turn_down, f.critical_vendor, f.urgent_invoice, f.updated_at
           )::app.udt_invoice_sjo_fields_result)
    FROM app.invoice_sjo_fields f
    JOIN app.countries c       ON c.id = f.country_id
    JOIN app.business_units bu ON bu.id = f.business_unit_id
    JOIN app.erp_systems e     ON e.id = f.erp_system_id
    WHERE f.invoice_id = p_invoice_id;
$$;
