-- =====================================================================
-- app.usp_integration_set_next_run - scheduler: store the next automatic run time
-- Request:  p_integration_id, p_next_run_at (NULL = not scheduled)
-- Response: app.udt_row_count_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_set_next_run(p_integration_id uuid, p_next_run_at timestamptz)
RETURNS app.udt_row_count_result
LANGUAGE sql
AS $$
    WITH upd AS (
        UPDATE app.integrations SET next_run_at = p_next_run_at WHERE id = p_integration_id RETURNING 1
    )
    SELECT ROW(count(*)::integer)::app.udt_row_count_result FROM upd;
$$;
