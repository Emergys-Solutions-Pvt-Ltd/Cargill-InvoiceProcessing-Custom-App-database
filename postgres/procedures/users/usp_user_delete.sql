-- =====================================================================
-- app.usp_user_delete - Settings > Users "Delete"
-- Request:  p_user_id, p_deleted_by (the admin performing the delete)
-- Response: app.udt_row_count_result
-- Behaviour: history is kept - invoices created by the user keep existing (created_by is
--            cleared), team memberships stay as name/email entries without the user link,
--            app assignments are removed with the user.
-- Errors:   CA400 deleting your own account, CA404 user not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_delete(p_user_id integer, p_deleted_by integer)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    IF p_user_id = p_deleted_by THEN
        RAISE EXCEPTION 'You cannot delete your own account.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User not found.' USING ERRCODE = 'CA404';
    END IF;

    UPDATE app.invoices         SET created_by = NULL WHERE created_by = p_user_id;
    UPDATE app.app_settings     SET updated_by = NULL WHERE updated_by = p_user_id;
    UPDATE app.app_team_members SET user_id    = NULL WHERE user_id    = p_user_id;

    DELETE FROM app.users WHERE id = p_user_id;   -- user_applications cascade
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
