-- =====================================================================
-- app.udt_invoice_detail_result - RESPONSE type: Invoice Detail screen in one row
-- Returned by: usp_invoice_get_by_code (no row when the invoice does not exist)
-- Each column is JSON built from a typed row/array, giving one round trip instead of five result sets.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_detail_result AS (
    invoice        jsonb,                -- app.udt_invoice_result
    attachments    jsonb,                -- array of app.udt_attachment_result (primary first)
    line_items     jsonb,                -- array of app.udt_line_item_result
    ccpps          jsonb,                -- array of app.udt_ccpp_result
    source_email   jsonb,                -- app.udt_invoice_email_result, NULL when not received by email
    sf_fields      jsonb                 -- app.udt_invoice_sf_fields_result, NULL when the invoice has no row yet
);
