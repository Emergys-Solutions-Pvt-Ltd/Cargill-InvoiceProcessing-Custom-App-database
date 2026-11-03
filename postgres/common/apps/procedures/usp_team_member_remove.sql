-- =====================================================================
-- app.usp_team_member_remove - Admin Configuration "Remove Member" (multi-select)
-- Request:  p_module_id, p_member_ids; ids belonging to another module are ignored
-- Response: app.udt_row_count_result (members removed)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_team_member_remove(p_module_id integer, p_member_ids integer[])
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    DELETE FROM app.app_team_members
    WHERE module_id = p_module_id AND id = ANY (coalesce(p_member_ids, '{}'));
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
