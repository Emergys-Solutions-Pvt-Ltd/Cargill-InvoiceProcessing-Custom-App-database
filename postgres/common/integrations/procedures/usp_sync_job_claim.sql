-- =====================================================================
-- app.usp_sync_job_claim - worker: take the next due job (FOR UPDATE SKIP LOCKED, so any number
-- of workers can poll safely) and mark it running.
-- Request:  p_worker_id (host:pid:random, written to the job for ownership checks)
-- Response: SETOF app.udt_sync_job_result - zero or one row
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_claim(p_worker_id text)
RETURNS SETOF app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_id                uuid;
    v_integration_id    uuid;
BEGIN
    SELECT j.id, j.integration_id INTO v_id, v_integration_id
    FROM app.integration_sync_jobs j
    WHERE j.status = 'queued' AND j.run_after <= now()
    ORDER BY j.run_after, j.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF v_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE app.integration_sync_jobs
    SET status = 'running', started_at = now(), heartbeat_at = now(), worker_id = left(p_worker_id, 100)
    WHERE id = v_id;

    UPDATE app.integrations
    SET last_attempt_at = now(), last_status = 'running', last_job_id = v_id
    WHERE id = v_integration_id;

    RETURN NEXT app.ufn_sync_job_row(v_id);
END;
$$;
