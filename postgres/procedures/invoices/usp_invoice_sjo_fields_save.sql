-- =====================================================================
-- app.usp_invoice_sjo_fields_save - Invoice Details "Save" of the SJO fields (insert or update)
-- Request:  p_invoice_code, p_updated_by (user id), the SJO fields. Country, BU, ERP and
--           ID Fiscal are required; A.B. Number / A.B. Name are optional (blank = NULL).
-- Response: app.udt_row_count_result
-- Errors:   CA400 not an SJO invoice, missing required field, unknown / inactive country, BU or ERP
--           CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_sjo_fields_save(
    p_invoice_code      text,
    p_updated_by        integer,
    p_country_id        integer,
    p_business_unit_id  integer,
    p_erp_system_id     integer,
    p_id_fiscal         text,
    p_ab_number         text    DEFAULT NULL,
    p_ab_name           text    DEFAULT NULL,
    p_flow_turn_down    boolean DEFAULT false,
    p_critical_vendor   boolean DEFAULT false,
    p_urgent_invoice    boolean DEFAULT false
)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    integer;
    v_app_code      text;
    v_rows          integer;
BEGIN
    SELECT i.id, a.code INTO v_invoice_id, v_app_code
    FROM app.invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;
    IF upper(v_app_code) <> 'SJO' THEN
        RAISE EXCEPTION 'SJO fields can only be saved on SJO invoices.' USING ERRCODE = 'CA400';
    END IF;

    IF p_country_id IS NULL OR p_business_unit_id IS NULL OR p_erp_system_id IS NULL
       OR nullif(btrim(p_id_fiscal), '') IS NULL THEN
        RAISE EXCEPTION 'Country, BU, ERP and ID Fiscal are required.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.countries WHERE id = p_country_id AND is_active) THEN
        RAISE EXCEPTION 'Selected country does not exist or is inactive.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.business_units WHERE id = p_business_unit_id AND is_active) THEN
        RAISE EXCEPTION 'Selected BU does not exist or is inactive.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.erp_systems WHERE id = p_erp_system_id AND is_active) THEN
        RAISE EXCEPTION 'Selected ERP does not exist or is inactive.' USING ERRCODE = 'CA400';
    END IF;

    INSERT INTO app.invoice_sjo_fields AS f
        (invoice_id, country_id, business_unit_id, erp_system_id, id_fiscal, ab_number, ab_name,
         flow_turn_down, critical_vendor, urgent_invoice, updated_by)
    VALUES
        (v_invoice_id, p_country_id, p_business_unit_id, p_erp_system_id, btrim(p_id_fiscal),
         nullif(btrim(p_ab_number), ''), nullif(btrim(p_ab_name), ''),
         coalesce(p_flow_turn_down, false), coalesce(p_critical_vendor, false), coalesce(p_urgent_invoice, false),
         p_updated_by)
    ON CONFLICT (invoice_id) DO UPDATE
        SET country_id       = EXCLUDED.country_id,
            business_unit_id = EXCLUDED.business_unit_id,
            erp_system_id    = EXCLUDED.erp_system_id,
            id_fiscal        = EXCLUDED.id_fiscal,
            ab_number        = EXCLUDED.ab_number,
            ab_name          = EXCLUDED.ab_name,
            flow_turn_down   = EXCLUDED.flow_turn_down,
            critical_vendor  = EXCLUDED.critical_vendor,
            urgent_invoice   = EXCLUDED.urgent_invoice,
            updated_by       = EXCLUDED.updated_by,
            updated_at       = now();
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    UPDATE app.invoices SET updated_by = p_updated_by, updated_at = now() WHERE id = v_invoice_id;

    RETURN ROW(v_rows)::app.udt_row_count_result;
EXCEPTION
    WHEN string_data_right_truncation THEN
        RAISE EXCEPTION 'ID Fiscal / A.B. Number (max 30) or A.B. Name (max 255) is too long.' USING ERRCODE = 'CA400';
END;
$$;
