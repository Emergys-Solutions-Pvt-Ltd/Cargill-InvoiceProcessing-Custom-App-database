-- =====================================================================
-- app.usp_user_touch_last_login - stamps last_login_at after a successful login
-- Request:  p_user_id
-- Response: app.udt_row_count_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_touch_last_login(p_user_id integer)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    UPDATE app.users SET last_login_at = now() WHERE id = p_user_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
