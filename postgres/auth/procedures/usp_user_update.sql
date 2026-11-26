-- =====================================================================
-- app_auth.usp_user_update - edit a user / Suspend-Activate toggle (Settings / UAM)
-- Request:  p_user_id; NULL p_name / p_email / p_role / p_status keep the current value.
--           A username that equals the old email follows an email change.
--           p_app_codes replaces the assigned apps when it is NOT NULL.
--           p_team_id moves the user to that team (one team per user); p_clear_team = true
--           removes the team. Both NULL/false keep the current team. A new team must be active.
-- Response: app_auth.udt_user_result (the updated user)
-- Errors:   CA400 invalid role / status / unknown application code / unknown or inactive team
--           CA404 user not found
--           CA409 email already used by another user
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_update(
    p_user_id   uuid,
    p_name      text    DEFAULT NULL,
    p_role      text    DEFAULT NULL,
    p_status    text    DEFAULT NULL,
    p_app_codes text[]  DEFAULT NULL,
    p_email     text    DEFAULT NULL,
    p_team_id   uuid    DEFAULT NULL,
    p_clear_team boolean DEFAULT false
)
RETURNS app_auth.udt_user_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_unknown   text;
    v_result    app_auth.udt_user_result;
BEGIN
    IF p_role IS NOT NULL AND p_role NOT IN ('Admin', 'User') THEN
        RAISE EXCEPTION 'Role must be Admin or User.' USING ERRCODE = 'CA400';
    END IF;
    IF p_status IS NOT NULL AND p_status NOT IN ('Active', 'Suspended') THEN
        RAISE EXCEPTION 'Status must be Active or Suspended.' USING ERRCODE = 'CA400';
    END IF;

    IF p_app_codes IS NOT NULL THEN
        SELECT string_agg(c, ', ') INTO v_unknown
        FROM unnest(p_app_codes) AS c
        WHERE NOT EXISTS (SELECT 1 FROM app.applications a WHERE a.code = c AND a.is_active);
        IF v_unknown IS NOT NULL THEN
            RAISE EXCEPTION 'Unknown application(s): %', v_unknown USING ERRCODE = 'CA400';
        END IF;
    END IF;

    -- Keeping an already assigned team that was deactivated since is allowed
    IF p_team_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM app.teams WHERE id = p_team_id AND is_active)
       AND NOT EXISTS (SELECT 1 FROM app_auth.users WHERE id = p_user_id AND team_id = p_team_id) THEN
        RAISE EXCEPTION 'Unknown or inactive team.' USING ERRCODE = 'CA400';
    END IF;

    IF p_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM app_auth.users
        WHERE id <> p_user_id AND (lower(email) = lower(p_email) OR lower(username) = lower(p_email))
    ) THEN
        RAISE EXCEPTION 'A user with email or username ''%'' already exists', p_email USING ERRCODE = 'CA409';
    END IF;

    UPDATE app_auth.users
       SET name       = coalesce(p_name, name),
           username   = CASE WHEN p_email IS NOT NULL AND lower(username) = lower(email) THEN p_email ELSE username END,
           email      = coalesce(p_email, email),
           role       = coalesce(p_role, role),
           status     = coalesce(p_status, status),
           team_id    = CASE WHEN coalesce(p_clear_team, false) THEN NULL ELSE coalesce(p_team_id, team_id) END,
           updated_at = now()
     WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found.' USING ERRCODE = 'CA404';
    END IF;

    IF p_app_codes IS NOT NULL THEN
        DELETE FROM app_auth.user_applications WHERE user_id = p_user_id;
        INSERT INTO app_auth.user_applications (user_id, application_id)
        SELECT p_user_id, a.id FROM app.applications a WHERE a.code = ANY (p_app_codes);
    END IF;

    SELECT id, username, name, email, role, status, auth_provider, assigned_apps, team_id, team_name
    INTO v_result
    FROM app_auth.vw_user_summary WHERE id = p_user_id;
    RETURN v_result;
END;
$$;
