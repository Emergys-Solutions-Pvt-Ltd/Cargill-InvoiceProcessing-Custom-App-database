-- =====================================================================
-- app.usp_integration_get_secret - encrypted credentials for the backend (worker, connection test)
-- Request:  p_integration_id
-- Response: SETOF app.udt_integration_secret_result (no row when not found). Never sent to browsers.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_get_secret(p_integration_id integer)
RETURNS SETOF app.udt_integration_secret_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(id, secret_ciphertext)::app.udt_integration_secret_result
    FROM app.integrations
    WHERE id = p_integration_id;
$$;
