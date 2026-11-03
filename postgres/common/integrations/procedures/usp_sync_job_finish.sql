-- =====================================================================
-- app.usp_sync_job_finish - worker: close a running job and update the integration status
-- Request:  p_job_id, p_worker_id, p_status (succeeded | partially_succeeded | failed | cancelled),
--           p_error_summary (short, sanitized; NULL when none)
-- Response: app.udt_sync_job_result
-- Errors:   CA400 invalid status, CA409 job not running for this worker
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_finish(
    p_job_id        integer,
    p_worker_id     text,
    p_status        text,
    p_error_summary text
)
RETURNS app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_integration_id integer;
BEGIN
    IF p_status NOT IN ('succeeded', 'partially_succeeded', 'failed', 'cancelled') THEN
        RAISE EXCEPTION 'Invalid final status %.', p_status USING ERRCODE = 'CA400';
    END IF;

    UPDATE app.integration_sync_jobs SET
        status        = p_status,
        finished_at   = now(),
        heartbeat_at  = now(),
        error_summary = left(p_error_summary, 2000)
    WHERE id = p_job_id AND status = 'running' AND worker_id = p_worker_id
    RETURNING integration_id INTO v_integration_id;
    IF v_integration_id IS NULL THEN
        RAISE EXCEPTION 'Job % is no longer owned by this worker.', p_job_id USING ERRCODE = 'CA409';
    END IF;

    UPDATE app.integrations SET
        last_status     = p_status,
        last_job_id     = p_job_id,
        last_success_at = CASE WHEN p_status IN ('succeeded', 'partially_succeeded') THEN now() ELSE last_success_at END
    WHERE id = v_integration_id;

    RETURN app.ufn_sync_job_row(p_job_id);
END;
$$;
