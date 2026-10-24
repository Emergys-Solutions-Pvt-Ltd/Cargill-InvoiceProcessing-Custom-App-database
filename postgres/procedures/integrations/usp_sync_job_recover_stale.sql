-- =====================================================================
-- app.usp_sync_job_recover_stale - worker: fail running jobs whose worker stopped sending
-- heartbeats (crash, container killed). The caller decides whether to queue a retry.
-- Request:  p_stale_seconds
-- Response: SETOF app.udt_sync_job_result - the jobs marked failed
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_recover_stale(p_stale_seconds integer)
RETURNS SETOF app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_job record;
BEGIN
    FOR v_job IN
        UPDATE app.integration_sync_jobs SET
            status        = 'failed',
            finished_at   = now(),
            error_summary = 'The worker stopped responding (no heartbeat for ' || p_stale_seconds || ' s)'
        WHERE status = 'running' AND heartbeat_at < now() - make_interval(secs => greatest(p_stale_seconds, 30))
        RETURNING id, integration_id
    LOOP
        UPDATE app.integrations SET last_status = 'failed' WHERE id = v_job.integration_id AND last_job_id = v_job.id;
        RETURN NEXT app.ufn_sync_job_row(v_job.id);
    END LOOP;
END;
$$;
