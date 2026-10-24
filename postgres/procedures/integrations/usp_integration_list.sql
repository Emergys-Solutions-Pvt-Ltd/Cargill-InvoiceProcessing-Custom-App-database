-- =====================================================================
-- app.usp_integration_list - Settings > SAP Configuration list
-- Request:  p_provider_type (e.g. 'sap-odata'; NULL = all providers)
-- Response: SETOF app.udt_integration_result ordered by name (secrets never included)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_list(p_provider_type text DEFAULT NULL)
RETURNS SETOF app.udt_integration_result
LANGUAGE sql
STABLE
AS $$
    SELECT r.*
    FROM app.integrations i
    CROSS JOIN LATERAL app.ufn_integration_row(i.id) r
    WHERE p_provider_type IS NULL OR i.provider_type = p_provider_type
    ORDER BY lower(i.name);
$$;
