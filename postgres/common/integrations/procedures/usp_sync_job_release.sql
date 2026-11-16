-- =====================================================================
-- app.usp_sync_job_release - worker shutdown: put a running job back in the queue so another
-- worker resumes it from the last committed page (profile watermarks are already saved).
-- Request:  p_job_id, p_worker_id
-- Response: app.udt_row_count_result (0 when the job was no longer owned by this worker)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_release(p_job_id uuid, p_worker_id text)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_integration_id uuid;
BEGIN
    UPDATE app.integration_sync_jobs
    SET status = 'queued', worker_id = NULL, heartbeat_at = NULL, run_after = now()
    WHERE id = p_job_id AND status = 'running' AND worker_id = p_worker_id
    RETURNING integration_id INTO v_integration_id;

    IF v_integration_id IS NULL THEN
        RETURN ROW(0)::app.udt_row_count_result;
    END IF;
    UPDATE app.integrations SET last_status = 'queued' WHERE id = v_integration_id;
    RETURN ROW(1)::app.udt_row_count_result;
END;
$$;
