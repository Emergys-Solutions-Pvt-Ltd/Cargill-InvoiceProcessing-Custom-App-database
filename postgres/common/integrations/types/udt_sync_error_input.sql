-- =====================================================================
-- app.udt_sync_error_input - REQUEST type: one error to record for a sync job
-- Used by: usp_sync_page_apply(p_rejects jsonb), usp_sync_error_add(p_errors jsonb).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_error_input AS (
    external_key    text,
    stage           text,
    message         text,
    details         jsonb
);
