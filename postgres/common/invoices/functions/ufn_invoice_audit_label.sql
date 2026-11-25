-- =====================================================================
-- app.ufn_invoice_audit_label - display text of an invoice column value for the audit history
-- Reference columns (ids) become the referenced name; other values are returned unchanged.
-- An id that no longer resolves (or is not a uuid) is returned as is.
-- Used by: app.ufn_invoice_audit_trigger
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_invoice_audit_label(p_field text, p_value text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id    uuid;
    v_label text;
BEGIN
    IF p_value IS NULL
       OR p_field NOT IN ('process_id', 'origin_city_id', 'destination_city_id', 'team_id', 'assigned_user_id',
                          'vendor_id', 'station_id', 'module_id', 'country_id', 'business_unit_id', 'erp_system_id')
       OR p_value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN p_value;
    END IF;
    v_id := p_value::uuid;

    CASE p_field
        WHEN 'process_id'          THEN SELECT name INTO v_label FROM app.processes WHERE id = v_id;
        WHEN 'origin_city_id'      THEN SELECT name INTO v_label FROM app.cities WHERE id = v_id;
        WHEN 'destination_city_id' THEN SELECT name INTO v_label FROM app.cities WHERE id = v_id;
        WHEN 'team_id'             THEN SELECT name INTO v_label FROM app.teams WHERE id = v_id;
        WHEN 'assigned_user_id'    THEN SELECT name INTO v_label FROM app_auth.users WHERE id = v_id;
        WHEN 'vendor_id'           THEN SELECT legal_name INTO v_label FROM app.vendors WHERE id = v_id;
        WHEN 'station_id'          THEN SELECT display_name INTO v_label FROM app.country_stations WHERE id = v_id;
        WHEN 'module_id'           THEN SELECT name INTO v_label FROM app.app_modules WHERE id = v_id;
        WHEN 'country_id'          THEN SELECT name INTO v_label FROM app.countries WHERE id = v_id;
        WHEN 'business_unit_id'    THEN SELECT name INTO v_label FROM app.business_units WHERE id = v_id;
        WHEN 'erp_system_id'       THEN SELECT name INTO v_label FROM sjo.erp_systems WHERE id = v_id;
    END CASE;

    RETURN coalesce(v_label, p_value);
END;
$$;
