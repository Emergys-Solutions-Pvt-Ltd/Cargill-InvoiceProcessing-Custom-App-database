-- =====================================================================
-- app.usp_sync_job_get - one job of an integration (job detail, per-profile stats)
-- Request:  p_integration_id, p_job_id
-- Response: SETOF app.udt_sync_job_result (no row when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_get(p_integration_id uuid, p_job_id uuid)
RETURNS SETOF app.udt_sync_job_result
LANGUAGE sql
STABLE
AS $$
    SELECT r.*
    FROM app.integration_sync_jobs j
    CROSS JOIN LATERAL app.ufn_sync_job_row(j.id) r
    WHERE j.id = p_job_id AND j.integration_id = p_integration_id;
$$;
