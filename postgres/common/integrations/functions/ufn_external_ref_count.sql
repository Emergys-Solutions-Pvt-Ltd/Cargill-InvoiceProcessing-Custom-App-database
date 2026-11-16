-- =====================================================================
-- app.ufn_external_ref_count - invoices imported by one integration, across every app's
-- <db_schema>.invoice_external_refs (apps from app.applications.db_schema).
-- Used by: usp_integration_summary
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_external_ref_count(p_integration_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_schema    text;
    v_n         integer;
    v_total     integer := 0;
BEGIN
    FOR v_schema IN SELECT DISTINCT db_schema FROM app.applications WHERE db_schema IS NOT NULL
    LOOP
        EXECUTE format('SELECT count(*)::integer FROM %I.invoice_external_refs WHERE integration_id = $1', v_schema)
            INTO v_n USING p_integration_id;
        v_total := v_total + v_n;
    END LOOP;
    RETURN v_total;
END;
$$;
