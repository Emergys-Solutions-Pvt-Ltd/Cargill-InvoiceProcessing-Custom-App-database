-- =====================================================================
-- {{S}}.udt_invoice_list_result - RESPONSE type: one page of {{APP}} invoices plus paging metadata
-- Returned by: {{S}}.usp_invoice_list. Paging columns repeat on every row; no rows = no matches.
-- Columns after page_size are {{APP}}-specific (read by the backend's {{APP}} invoice extension).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE {{S}}.udt_invoice_list_result AS (
    invoice        jsonb,                -- app.udt_invoice_result as JSON (keys = its column names)
    total_items    integer,
    total_pages    integer,
    page           integer,
    page_size      integer{{#sjo}},
    sjo_fields     jsonb                 -- sjo.udt_invoice_sjo_fields_result, NULL until the SJO fields are saved{{/sjo}}
);
