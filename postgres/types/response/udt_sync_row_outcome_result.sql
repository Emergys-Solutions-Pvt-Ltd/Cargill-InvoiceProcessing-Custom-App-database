-- =====================================================================
-- app.udt_sync_row_outcome_result - RESPONSE type: what happened to one source record
-- Returned by: usp_sync_page_apply. outcome: created | updated | unchanged | skipped | rejected | failed.
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_row_outcome_result AS (
    row_no          integer,
    external_key    text,
    outcome         text,
    invoice_code    text,
    message         text
);
