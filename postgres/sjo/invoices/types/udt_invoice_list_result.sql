-- GENERATED from common/invoices/templates/types/udt_invoice_list_result.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.udt_invoice_list_result - RESPONSE type: one page of SJO invoices plus paging metadata
-- Returned by: sjo.usp_invoice_list. Paging columns repeat on every row; no rows = no matches.
-- Columns after page_size are SJO-specific (read by the backend's SJO invoice extension).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE sjo.udt_invoice_list_result AS (
    invoice        jsonb,                -- app.udt_invoice_result as JSON (keys = its column names)
    total_items    integer,
    total_pages    integer,
    page           integer,
    page_size      integer,
    sjo_fields     jsonb                 -- sjo.udt_invoice_sjo_fields_result, NULL until the SJO fields are saved
);
