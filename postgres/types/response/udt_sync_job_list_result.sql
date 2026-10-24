-- =====================================================================
-- app.udt_sync_job_list_result - RESPONSE type: one page of sync job history + paging
-- Returned by: usp_sync_job_list. job = udt_sync_job_result as JSON; paging columns repeat on every row.
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_job_list_result AS (
    job             jsonb,
    total_items     integer,
    total_pages     integer,
    page            integer,
    page_size       integer
);
