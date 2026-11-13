-- =====================================================================
-- app.usp_sync_error_add - record job-level errors (e.g. a fetch failure of one profile)
-- Request:  p_job_id, p_profile_id (NULL = whole job), p_errors = JSON array of app.udt_sync_error_input
-- Response: app.udt_row_count_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_error_add(p_job_id uuid, p_profile_id uuid, p_errors jsonb)
RETURNS app.udt_row_count_result
LANGUAGE sql
AS $$
    WITH ins AS (
        INSERT INTO app.integration_sync_errors (job_id, profile_id, stage, external_key, message, details)
        SELECT p_job_id, p_profile_id,
               CASE WHEN e.stage IN ('fetch', 'mapping', 'validation', 'persistence', 'review') THEN e.stage ELSE 'fetch' END,
               left(e.external_key, 200), left(coalesce(e.message, 'Error'), 2000), e.details
        FROM jsonb_populate_recordset(NULL::app.udt_sync_error_input, coalesce(p_errors, '[]'::jsonb)) e
        RETURNING 1
    )
    SELECT ROW(count(*)::integer)::app.udt_row_count_result FROM ins;
$$;
