-- =====================================================================
-- app.ufn_master_data_select_sql - builds the SELECT that returns the columns of
-- app.udt_master_data_result for one Configuration entity (joined to its parent, if any).
-- Table / column names come only from app.master_data_entities and are quoted with %I,
-- so callers can safely embed the result in dynamic SQL.
-- Raises CA404 for an unknown entity.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_master_data_select_sql(p_entity text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_def           app.master_data_entities;
    v_parent_table  text;
BEGIN
    SELECT * INTO v_def FROM app.master_data_entities WHERE entity = p_entity;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown configuration list ''%''', p_entity USING ERRCODE = 'CA404';
    END IF;

    IF v_def.parent_entity IS NOT NULL THEN
        SELECT table_name INTO v_parent_table FROM app.master_data_entities WHERE entity = v_def.parent_entity;
    END IF;

    RETURN format(
        'SELECT t.id, t.code::varchar(30), t.name::varchar(150), t.description::varchar(500), '
        || '%s AS parent_id, %s AS parent_name, %s AS color, t.sort_order, t.is_active, t.updated_at '
        || 'FROM app.%I t %s',
        CASE WHEN v_def.parent_column IS NULL THEN 'NULL::integer' ELSE format('t.%I', v_def.parent_column) END,
        CASE WHEN v_parent_table IS NULL THEN 'NULL::varchar(150)' ELSE 'p.name::varchar(150)' END,
        CASE WHEN v_def.has_color THEN 't.color::varchar(20)' ELSE 'NULL::varchar(20)' END,
        v_def.table_name,
        CASE WHEN v_parent_table IS NULL THEN ''
             ELSE format('LEFT JOIN app.%I p ON p.id = t.%I', v_parent_table, v_def.parent_column) END
    );
END;
$$;
