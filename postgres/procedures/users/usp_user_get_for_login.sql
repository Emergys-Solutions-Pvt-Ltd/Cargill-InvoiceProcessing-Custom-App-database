-- =====================================================================
-- app.usp_user_get_for_login - user record for credential checks (any status)
-- Request:  p_login - email or short username (e.g. 'admin'), case-insensitive
-- Response: SETOF app.udt_user_login_result (includes password_hash; login use only)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_get_for_login(p_login text)
RETURNS SETOF app.udt_user_login_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, username, name, email, role, status, auth_provider, assigned_apps, password_hash
    FROM app.vw_user_summary
    WHERE lower(email) = lower(p_login) OR lower(username) = lower(p_login)
    ORDER BY (lower(email) = lower(p_login)) DESC
    LIMIT 1;
$$;
