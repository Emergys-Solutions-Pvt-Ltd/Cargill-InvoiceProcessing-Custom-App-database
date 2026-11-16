-- =====================================================================
-- app.usp_integration_set_secret - store / rotate / clear the encrypted credentials
-- Request:  p_integration_id, p_secret_ciphertext (AES-256-GCM payload from the backend
--           SecretStore; NULL clears the secret), p_user_id
-- Response: app.udt_row_count_result
-- Errors:   CA404 integration not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_set_secret(
    p_integration_id    uuid,
    p_secret_ciphertext text,
    p_user_id           uuid
)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    UPDATE app.integrations SET
        secret_ciphertext = p_secret_ciphertext,
        secret_updated_at = CASE WHEN p_secret_ciphertext IS NULL THEN NULL ELSE now() END,
        updated_by        = p_user_id,
        updated_at        = now()
    WHERE id = p_integration_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
    END IF;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
