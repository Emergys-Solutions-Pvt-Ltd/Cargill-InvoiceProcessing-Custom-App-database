-- =====================================================================
-- app.ufn_sync_job_row - builds app.udt_sync_job_result for one sync job
-- (integration / requester names, error count, duration). Shared by every usp_sync_job_*
-- function and the job history list so the shape is defined once.
-- Returns NULL when the job does not exist.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_sync_job_row(p_job_id uuid)
RETURNS app.udt_sync_job_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(
        j.id, j.integration_id, i.name, j.trigger_type, j.requested_by, u.name, j.status, j.attempt,
        j.max_attempts, j.retry_of_job_id, j.run_after, j.started_at, j.finished_at, j.heartbeat_at,
        j.worker_id, j.cancel_requested, j.records_fetched, j.records_created, j.records_updated,
        j.records_unchanged, j.records_rejected, j.records_failed, j.pages_processed, j.profile_stats,
        j.error_summary,
        (SELECT count(*)::integer FROM app.integration_sync_errors e WHERE e.job_id = j.id),
        CASE WHEN j.started_at IS NOT NULL
             THEN (extract(epoch FROM (coalesce(j.finished_at, now()) - j.started_at)) * 1000)::bigint
        END,
        j.created_at
    )::app.udt_sync_job_result
    FROM app.integration_sync_jobs j
    JOIN app.integrations i ON i.id = j.integration_id
    LEFT JOIN app_auth.users u   ON u.id = j.requested_by
    WHERE j.id = p_job_id;
$$;
