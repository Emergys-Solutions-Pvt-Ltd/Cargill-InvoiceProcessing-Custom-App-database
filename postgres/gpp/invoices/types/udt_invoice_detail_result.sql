-- GENERATED from common/invoices/templates/types/udt_invoice_detail_result.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- gpp.udt_invoice_detail_result - RESPONSE type: GPP Invoice Detail screen in one row
-- Returned by: gpp.usp_invoice_get_by_code (no row when the invoice does not exist)
-- Each column is JSON built from a typed row/array, giving one round trip instead of several result sets.
-- Columns after source_email are GPP-specific (read by the backend's GPP invoice extension).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE gpp.udt_invoice_detail_result AS (
    invoice        jsonb,                -- app.udt_invoice_result
    attachments    jsonb,                -- array of app.udt_attachment_result (primary first)
    line_items     jsonb,                -- array of app.udt_line_item_result
    source_email   jsonb,                -- app.udt_invoice_email_result, NULL when not received by email
    ccpps          jsonb,                -- array of gpp.udt_ccpp_result
    sf_fields      jsonb                 -- gpp.udt_invoice_sf_fields_result (legacy Salesforce fields)
);
