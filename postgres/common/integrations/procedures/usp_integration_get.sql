-- =====================================================================
-- app.usp_integration_get - one integration with its extraction profiles
-- Request:  p_integration_id
-- Response: SETOF app.udt_integration_result (no row when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_get(p_integration_id integer)
RETURNS SETOF app.udt_integration_result
LANGUAGE sql
STABLE
AS $$
    SELECT r.*
    FROM app.integrations i
    CROSS JOIN LATERAL app.ufn_integration_row(i.id) r
    WHERE i.id = p_integration_id;
$$;
