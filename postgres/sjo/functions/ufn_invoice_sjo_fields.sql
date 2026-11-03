-- =====================================================================
-- sjo.ufn_invoice_sjo_fields - one SJO invoice's SJO fields as sjo.udt_invoice_sjo_fields_result JSON
-- (country / BU / ERP resolved to code and name); NULL until the SJO fields are saved (invoices
-- imported by SAP / OnBase have none).
-- Used by: sjo.usp_invoice_list, sjo.usp_invoice_get_by_code
-- =====================================================================
CREATE OR REPLACE FUNCTION sjo.ufn_invoice_sjo_fields(p_invoice_id integer)
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
           )::sjo.udt_invoice_sjo_fields_result)
    FROM sjo.sjo_invoices f
    JOIN app.countries c       ON c.id = f.country_id
    JOIN app.business_units bu ON bu.id = f.business_unit_id
    JOIN sjo.erp_systems e     ON e.id = f.erp_system_id
    WHERE f.id = p_invoice_id;
$$;
