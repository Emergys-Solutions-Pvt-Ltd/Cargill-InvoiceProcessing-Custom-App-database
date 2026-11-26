-- =====================================================================
-- app_auth.vw_user_summary - users with their assigned application codes aggregated
-- into a comma separated list, plus the user's team (app.teams). The first nine columns
-- match app_auth.udt_user_login_result.
-- Used by: usp_user_* functions (password_hash is only selected for login)
-- =====================================================================
CREATE OR REPLACE VIEW app_auth.vw_user_summary AS
SELECT
    u.id,
    u.username,
    u.name,
    u.email,
    u.role,
    u.status,
    u.auth_provider,
    (SELECT string_agg(a.code, ',' ORDER BY a.id)
       FROM app_auth.user_applications ua
       JOIN app.applications a ON a.id = ua.application_id
      WHERE ua.user_id = u.id) AS assigned_apps,
    u.password_hash,
    u.team_id,
    t.name AS team_name
FROM app_auth.users u
LEFT JOIN app.teams t ON t.id = u.team_id;
