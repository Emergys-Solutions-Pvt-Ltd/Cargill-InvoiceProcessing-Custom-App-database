-- =====================================================================
-- app.udt_sync_error_list_result - RESPONSE type: one page of sync job errors + paging
-- Returned by: usp_sync_error_list.
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_error_list_result AS (
    id              bigint,
    job_id          integer,
    profile_id      integer,
    profile_name    text,
    stage           text,
    external_key    text,
    message         text,
    details         jsonb,
    created_at      timestamptz,
    total_items     integer,
    total_pages     integer,
    page            integer,
    page_size       integer
);
