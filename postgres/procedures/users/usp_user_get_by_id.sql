-- =====================================================================
-- app.usp_user_get_by_id - one user (auth middleware reload, Settings detail)
-- Request:  p_user_id; p_active_only = true returns nothing for suspended users
-- Response: SETOF app.udt_user_result (no rows when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_get_by_id(
    p_user_id       integer,
    p_active_only   boolean DEFAULT false
)
RETURNS SETOF app.udt_user_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, username, name, email, role, status, auth_provider, assigned_apps
    FROM app.vw_user_summary
    WHERE id = p_user_id
      AND (NOT p_active_only OR status = 'Active');
$$;
