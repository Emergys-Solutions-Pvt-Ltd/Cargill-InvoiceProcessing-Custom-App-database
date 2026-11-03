-- =====================================================================
-- app.usp_sync_job_cancel - cancel a queued job, or ask a running job to stop after its
-- current page (already committed pages stay; re-running is safe).
-- Request:  p_integration_id, p_job_id
-- Response: app.udt_sync_job_result
-- Errors:   CA404 job not found for the integration, CA409 job already finished
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_cancel(p_integration_id integer, p_job_id integer)
RETURNS app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_status text;
BEGIN
    SELECT status INTO v_status FROM app.integration_sync_jobs
    WHERE id = p_job_id AND integration_id = p_integration_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Job not found.' USING ERRCODE = 'CA404';
    END IF;

    IF v_status = 'queued' THEN
        UPDATE app.integration_sync_jobs
        SET status = 'cancelled', finished_at = now(), error_summary = 'Cancelled before it started'
        WHERE id = p_job_id;
        UPDATE app.integrations SET last_status = 'cancelled' WHERE id = p_integration_id;
    ELSIF v_status = 'running' THEN
        UPDATE app.integration_sync_jobs SET cancel_requested = true WHERE id = p_job_id;
    ELSE
        RAISE EXCEPTION 'The job has already finished (%).', v_status USING ERRCODE = 'CA409';
    END IF;

    RETURN app.ufn_sync_job_row(p_job_id);
END;
$$;
