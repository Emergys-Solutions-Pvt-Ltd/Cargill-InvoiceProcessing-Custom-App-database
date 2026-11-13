-- =====================================================================
-- app.usp_integration_summary - Synchronization dashboard of one integration
-- Request:  p_integration_id, p_days (period for the totals, default 30)
-- Response: SETOF app.udt_integration_summary_result (no row when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_summary(p_integration_id uuid, p_days integer DEFAULT 30)
RETURNS SETOF app.udt_integration_summary_result
LANGUAGE sql
STABLE
AS $$
    SELECT
        i.id, i.last_status, i.last_attempt_at, i.last_success_at, i.next_run_at, i.auto_sync_enabled,
        (SELECT to_jsonb(app.ufn_sync_job_row(j.id))
         FROM app.integration_sync_jobs j
         WHERE j.integration_id = i.id AND j.status NOT IN ('queued', 'running')
         ORDER BY j.finished_at DESC NULLS LAST, j.id DESC LIMIT 1),
        (SELECT to_jsonb(app.ufn_sync_job_row(j.id))
         FROM app.integration_sync_jobs j
         WHERE j.integration_id = i.id AND j.status IN ('queued', 'running')
         LIMIT 1),
        greatest(coalesce(p_days, 30), 1),
        coalesce(t.jobs_total, 0), coalesce(t.jobs_succeeded, 0), coalesce(t.jobs_partial, 0), coalesce(t.jobs_failed, 0),
        coalesce(t.fetched, 0), coalesce(t.created, 0), coalesce(t.updated, 0), coalesce(t.unchanged, 0),
        coalesce(t.rejected, 0), coalesce(t.failed, 0), t.avg_duration_ms,
        app.ufn_external_ref_count(i.id)
    FROM app.integrations i
    LEFT JOIN LATERAL (
        SELECT count(*)::integer                                                  AS jobs_total,
               count(*) FILTER (WHERE j.status = 'succeeded')::integer            AS jobs_succeeded,
               count(*) FILTER (WHERE j.status = 'partially_succeeded')::integer  AS jobs_partial,
               count(*) FILTER (WHERE j.status = 'failed')::integer               AS jobs_failed,
               sum(j.records_fetched)::bigint   AS fetched,
               sum(j.records_created)::bigint   AS created,
               sum(j.records_updated)::bigint   AS updated,
               sum(j.records_unchanged)::bigint AS unchanged,
               sum(j.records_rejected)::bigint  AS rejected,
               sum(j.records_failed)::bigint    AS failed,
               (avg(extract(epoch FROM (j.finished_at - j.started_at)) * 1000)
                    FILTER (WHERE j.finished_at IS NOT NULL AND j.started_at IS NOT NULL))::bigint AS avg_duration_ms
        FROM app.integration_sync_jobs j
        WHERE j.integration_id = i.id AND j.created_at >= now() - make_interval(days => greatest(coalesce(p_days, 30), 1))
    ) t ON true
    WHERE i.id = p_integration_id;
$$;
