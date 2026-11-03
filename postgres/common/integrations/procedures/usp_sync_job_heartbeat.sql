-- =====================================================================
-- app.usp_sync_job_heartbeat - worker: prove the job is alive and read cancel requests
-- Request:  p_job_id, p_worker_id
-- Response: app.udt_sync_job_result (cancel_requested tells the worker to stop safely)
-- Errors:   CA409 the job is no longer running for this worker (recovered as stale, or finished)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_heartbeat(p_job_id integer, p_worker_id text)
RETURNS app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE app.integration_sync_jobs SET heartbeat_at = now()
    WHERE id = p_job_id AND status = 'running' AND worker_id = p_worker_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job % is no longer owned by this worker.', p_job_id USING ERRCODE = 'CA409';
    END IF;
    RETURN app.ufn_sync_job_row(p_job_id);
END;
$$;
