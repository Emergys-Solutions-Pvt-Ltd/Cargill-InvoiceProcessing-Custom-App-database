-- =====================================================================
-- app.usp_sync_job_enqueue - queue a synchronization (scheduled, manual or retry)
-- Request:  p_integration_id, p_trigger_type (scheduled | manual | retry), p_requested_by (user, NULL
--           for the scheduler), p_retry_of_job_id (retry only), p_attempt (1 for new runs),
--           p_run_after (NULL = now; retries use now + backoff)
-- Response: app.udt_sync_job_result
-- Errors:   CA400 inactive integration, no active profile, bad trigger, retry of another integration's job
--           CA404 integration not found
--           CA409 a job is already queued or running for this integration (no overlapping runs)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_enqueue(
    p_integration_id    uuid,
    p_trigger_type      text,
    p_requested_by      uuid,
    p_retry_of_job_id   uuid     DEFAULT NULL,
    p_attempt           integer     DEFAULT 1,
    p_run_after         timestamptz DEFAULT NULL
)
RETURNS app.udt_sync_job_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_integration   record;
    v_max_attempts  integer;
    v_id            uuid;
BEGIN
    SELECT id, is_active, retry_policy INTO v_integration FROM app.integrations WHERE id = p_integration_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
    END IF;
    IF NOT v_integration.is_active THEN
        RAISE EXCEPTION 'The integration is inactive. Activate it before synchronizing.' USING ERRCODE = 'CA400';
    END IF;
    IF p_trigger_type NOT IN ('scheduled', 'manual', 'retry') THEN
        RAISE EXCEPTION 'Invalid trigger type %.', p_trigger_type USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.integration_profiles WHERE integration_id = p_integration_id AND is_active) THEN
        RAISE EXCEPTION 'The integration has no active extraction profile.' USING ERRCODE = 'CA400';
    END IF;
    IF p_retry_of_job_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM app.integration_sync_jobs WHERE id = p_retry_of_job_id AND integration_id = p_integration_id) THEN
        RAISE EXCEPTION 'The job to retry does not belong to this integration.' USING ERRCODE = 'CA400';
    END IF;

    v_max_attempts := least(greatest(coalesce((v_integration.retry_policy ->> 'maxAttempts')::integer, 3), 1), 10);

    BEGIN
        INSERT INTO app.integration_sync_jobs
            (integration_id, trigger_type, requested_by, attempt, max_attempts, retry_of_job_id, run_after)
        VALUES
            (p_integration_id, p_trigger_type, p_requested_by, greatest(coalesce(p_attempt, 1), 1),
             greatest(v_max_attempts, coalesce(p_attempt, 1)), p_retry_of_job_id, coalesce(p_run_after, now()))
        RETURNING id INTO v_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'A synchronization is already queued or running for this integration.' USING ERRCODE = 'CA409';
    END;

    UPDATE app.integrations SET last_status = 'queued' WHERE id = p_integration_id;
    RETURN app.ufn_sync_job_row(v_id);
END;
$$;
