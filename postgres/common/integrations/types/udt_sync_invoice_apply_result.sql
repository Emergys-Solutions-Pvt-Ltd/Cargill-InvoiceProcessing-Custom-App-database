-- =====================================================================
-- app.udt_sync_invoice_apply_result - RESPONSE type of <app>.usp_sync_invoice_apply: what happened
-- to one source invoice in its app's tables (called per row by app.usp_sync_page_apply).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_sync_invoice_apply_result AS (
    outcome         text,       -- created | updated | unchanged | skipped
    invoice_code    text,
    message         text,
    needs_review    boolean     -- cancelled in the source after processing started (status left unchanged)
);
