-- =====================================================================
-- app.usp_user_create - "Add New User" (Settings / UAM)
-- Request:  user fields + p_app_codes (application codes to grant).
--           p_password_hash is a bcrypt hash for LOCAL users, NULL for AD users.
-- Response: app.udt_user_result (the created user)
-- Errors:   CA400 invalid role / provider / unknown application code, or LOCAL without password
--           CA409 email or username already exists
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_create(
    p_username      text,
    p_name          text,
    p_email         text,
    p_role          text    DEFAULT 'User',
    p_auth_provider text    DEFAULT 'AD',
    p_password_hash text    DEFAULT NULL,
    p_app_codes     text[]  DEFAULT '{}'
)
RETURNS app.udt_user_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_unknown   text;
    v_id        integer;
    v_result    app.udt_user_result;
BEGIN
    IF p_role NOT IN ('Admin', 'User') THEN
        RAISE EXCEPTION 'Role must be Admin or User.' USING ERRCODE = 'CA400';
    END IF;
    IF p_auth_provider NOT IN ('LOCAL', 'AD') THEN
        RAISE EXCEPTION 'AuthProvider must be LOCAL or AD.' USING ERRCODE = 'CA400';
    END IF;
    IF p_auth_provider = 'LOCAL' AND p_password_hash IS NULL THEN
        RAISE EXCEPTION 'A password is required for LOCAL users.' USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(c, ', ') INTO v_unknown
    FROM unnest(coalesce(p_app_codes, '{}')) AS c
    WHERE NOT EXISTS (SELECT 1 FROM app.applications a WHERE a.code = c AND a.is_active);
    IF v_unknown IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown application(s): %', v_unknown USING ERRCODE = 'CA400';
    END IF;

    IF EXISTS (SELECT 1 FROM app.users WHERE lower(email) = lower(p_email) OR lower(username) = lower(p_username)) THEN
        RAISE EXCEPTION 'A user with email or username ''%'' already exists', p_email USING ERRCODE = 'CA409';
    END IF;

    INSERT INTO app.users (username, name, email, role, auth_provider, password_hash)
    VALUES (p_username, p_name, p_email, p_role, p_auth_provider, p_password_hash)
    RETURNING id INTO v_id;

    INSERT INTO app.user_applications (user_id, application_id)
    SELECT v_id, a.id FROM app.applications a WHERE a.code = ANY (p_app_codes);

    SELECT id, username, name, email, role, status, auth_provider, assigned_apps
    INTO v_result
    FROM app.vw_user_summary WHERE id = v_id;
    RETURN v_result;
END;
$$;
