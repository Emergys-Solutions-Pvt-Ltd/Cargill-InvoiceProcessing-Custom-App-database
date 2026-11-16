-- =====================================================================
-- app_auth.usp_user_delete - Settings > Users "Delete"
-- Request:  p_user_id, p_deleted_by (the admin performing the delete)
-- Response: app.udt_row_count_result
-- Behaviour: history is kept - invoices created by the user keep existing (created_by is
--            cleared), team memberships stay as name/email entries without the user link,
--            app assignments are removed with the user.
-- Errors:   CA400 deleting your own account, CA404 user not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_delete(p_user_id uuid, p_deleted_by uuid)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_schema    text;
    v_rows integer;
BEGIN
    IF p_user_id = p_deleted_by THEN
        RAISE EXCEPTION 'You cannot delete your own account.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app_auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'User not found.' USING ERRCODE = 'CA404';
    END IF;

    -- Every app's invoice table (<db_schema>.<db_schema>_invoices): keep the invoices, drop the links
    FOR v_schema IN SELECT DISTINCT db_schema FROM app.applications WHERE db_schema IS NOT NULL
    LOOP
        EXECUTE format('UPDATE %I.%I SET created_by = NULL WHERE created_by = $1', v_schema, v_schema || '_invoices') USING p_user_id;
        EXECUTE format('UPDATE %I.%I SET updated_by = NULL WHERE updated_by = $1', v_schema, v_schema || '_invoices') USING p_user_id;
        EXECUTE format('UPDATE %I.%I SET assigned_user_id = NULL WHERE assigned_user_id = $1', v_schema, v_schema || '_invoices') USING p_user_id;
    END LOOP;
    UPDATE app.app_settings     SET updated_by = NULL WHERE updated_by = p_user_id;
    UPDATE app.app_team_members SET user_id    = NULL WHERE user_id    = p_user_id;

    DELETE FROM app_auth.users WHERE id = p_user_id;   -- user_applications cascade
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
