-- =====================================================================
-- app.usp_team_member_add - Admin Configuration "Add Member"
-- Request:  p_module_id, p_name, p_email, p_alias (NULL/blank = name lower-cased without
--           spaces), p_team (team name). Links user_id when the email matches a user.
-- Response: app.udt_team_member_result (the added member)
-- Errors:   CA400 unknown team, CA404 unknown module, CA409 email already on this module
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_team_member_add(
    p_module_id integer,
    p_name      text,
    p_email     text,
    p_alias     text DEFAULT NULL,
    p_team      text DEFAULT 'Reception Team'
)
RETURNS app.udt_team_member_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_team_id   integer;
    v_result    app.udt_team_member_result;
BEGIN
    SELECT id INTO v_team_id FROM app.teams WHERE name = p_team AND is_active;
    IF v_team_id IS NULL THEN
        RAISE EXCEPTION 'Unknown team ''%''', coalesce(p_team, '') USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.app_modules WHERE id = p_module_id) THEN
        RAISE EXCEPTION 'Application module not found.' USING ERRCODE = 'CA404';
    END IF;
    IF EXISTS (SELECT 1 FROM app.app_team_members WHERE module_id = p_module_id AND lower(email) = lower(p_email)) THEN
        RAISE EXCEPTION '''%'' is already a member of this application', p_email USING ERRCODE = 'CA409';
    END IF;

    INSERT INTO app.app_team_members (module_id, team_id, user_id, name, email, alias)
    VALUES (p_module_id, v_team_id,
            (SELECT id FROM app.users WHERE lower(email) = lower(p_email)),
            p_name, p_email,
            coalesce(nullif(btrim(p_alias), ''), lower(replace(p_name, ' ', ''))))
    RETURNING id, name, email, alias, p_team
    INTO v_result;

    RETURN v_result;
END;
$$;
