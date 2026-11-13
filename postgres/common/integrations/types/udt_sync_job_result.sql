-- =====================================================================
-- app.udt_sync_job_result - RESPONSE type: one synchronization job with its counters
-- Returned by the usp_sync_job_* functions (built by ufn_sync_job_row).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_job_result AS (
    id                  uuid,
    integration_id      uuid,
    integration_name    text,
    trigger_type        text,
    requested_by        uuid,
    requested_by_name   text,
    status              text,
    attempt             integer,
    max_attempts        integer,
    retry_of_job_id     uuid,
    run_after           timestamptz,
    started_at          timestamptz,
    finished_at         timestamptz,
    heartbeat_at        timestamptz,
    worker_id           text,
    cancel_requested    boolean,
    records_fetched     integer,
    records_created     integer,
    records_updated     integer,
    records_unchanged   integer,
    records_rejected    integer,
    records_failed      integer,
    pages_processed     integer,
    profile_stats       jsonb,
    error_summary       text,
    error_count         integer,
    duration_ms         bigint,
    created_at          timestamptz
);
