-- =====================================================================
-- app.usp_master_data_delete - delete one Configuration item
-- Request:  p_entity, p_id
-- Response: app.udt_row_count_result
-- Errors:   CA404 unknown entity or item,
--           CA409 item still referenced (e.g. a country with states, a team with members,
--                 a status used by invoices) - deactivate it instead
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_master_data_delete(p_entity text, p_id integer)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_def   app.master_data_entities;
    v_name  text;
    v_rows  integer;
BEGIN
    SELECT * INTO v_def FROM app.master_data_entities WHERE entity = p_entity;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown configuration list ''%''', p_entity USING ERRCODE = 'CA404';
    END IF;

    EXECUTE format('SELECT name FROM app.%I WHERE id = $1', v_def.table_name) INTO v_name USING p_id;
    IF v_name IS NULL THEN
        RAISE EXCEPTION '% not found.', v_def.label USING ERRCODE = 'CA404';
    END IF;

    BEGIN
        EXECUTE format('DELETE FROM app.%I WHERE id = $1', v_def.table_name) USING p_id;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION '% "%" is in use and cannot be deleted. Deactivate it instead.', v_def.label, v_name
                USING ERRCODE = 'CA409';
    END;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
