-- =====================================================================
-- app.usp_master_data_options - active items of one entity for dropdowns
-- Request:  p_entity, p_parent_id (optional filter, e.g. states of one country)
-- Response: SETOF app.udt_master_data_option_result, ordered by sort_order then name
-- Errors:   CA404 unknown entity
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_master_data_options(p_entity text, p_parent_id integer DEFAULT NULL)
RETURNS SETOF app.udt_master_data_option_result
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT b.id, b.code, b.name, b.parent_id, b.color
         FROM (' || app.ufn_master_data_select_sql(p_entity) || ') b
         WHERE b.is_active AND ($1::integer IS NULL OR b.parent_id = $1)
         ORDER BY b.sort_order, lower(b.name), b.id'
    USING p_parent_id;
END;
$$;
