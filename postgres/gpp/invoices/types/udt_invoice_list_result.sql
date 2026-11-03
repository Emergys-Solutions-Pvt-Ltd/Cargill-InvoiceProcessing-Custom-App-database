-- GENERATED from common/invoices/templates/types/udt_invoice_list_result.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- gpp.udt_invoice_list_result - RESPONSE type: one page of GPP invoices plus paging metadata
-- Returned by: gpp.usp_invoice_list. Paging columns repeat on every row; no rows = no matches.
-- Columns after page_size are GPP-specific (read by the backend's GPP invoice extension).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE gpp.udt_invoice_list_result AS (
    invoice        jsonb,                -- app.udt_invoice_result as JSON (keys = its column names)
    total_items    integer,
    total_pages    integer,
    page           integer,
    page_size      integer
);
