-- =====================================================================
-- app.udt_integration_summary_result - RESPONSE type: Synchronization dashboard of one integration
-- Returned by: usp_integration_summary. last_job / active_job = udt_sync_job_result JSON (NULL when none).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_integration_summary_result AS (
    integration_id      integer,
    last_status         text,
    last_attempt_at     timestamptz,
    last_success_at     timestamptz,
    next_run_at         timestamptz,
    auto_sync_enabled   boolean,
    last_job            jsonb,
    active_job          jsonb,
    period_days         integer,
    jobs_total          integer,
    jobs_succeeded      integer,
    jobs_partial        integer,
    jobs_failed         integer,
    records_fetched     bigint,
    records_created     bigint,
    records_updated     bigint,
    records_unchanged   bigint,
    records_rejected    bigint,
    records_failed      bigint,
    avg_duration_ms     bigint,
    invoices_imported   integer
);
