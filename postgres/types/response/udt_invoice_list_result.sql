-- =====================================================================
-- app.udt_invoice_list_result - RESPONSE type: one page of invoices plus paging metadata
-- Returned by: usp_invoice_list. Paging columns repeat on every row; no rows = no matches.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_list_result AS (
    invoice        jsonb,                -- app.udt_invoice_result as JSON (keys = its column names)
    total_items    integer,
    total_pages    integer,
    page           integer,
    page_size      integer
);
