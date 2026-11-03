-- =====================================================================
-- {{S}}.udt_invoice_detail_result - RESPONSE type: {{APP}} Invoice Detail screen in one row
-- Returned by: {{S}}.usp_invoice_get_by_code (no row when the invoice does not exist)
-- Each column is JSON built from a typed row/array, giving one round trip instead of several result sets.
-- Columns after source_email are {{APP}}-specific (read by the backend's {{APP}} invoice extension).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE {{S}}.udt_invoice_detail_result AS (
    invoice        jsonb,                -- app.udt_invoice_result
    attachments    jsonb,                -- array of app.udt_attachment_result (primary first)
    line_items     jsonb,                -- array of app.udt_line_item_result
    source_email   jsonb{{#gpp}},                -- app.udt_invoice_email_result, NULL when not received by email
    ccpps          jsonb,                -- array of gpp.udt_ccpp_result
    sf_fields      jsonb                 -- gpp.udt_invoice_sf_fields_result (legacy Salesforce fields){{/gpp}}{{#sjo}},                -- app.udt_invoice_email_result, NULL when not received by email
    sjo_fields     jsonb                 -- sjo.udt_invoice_sjo_fields_result, NULL until the SJO fields are saved{{/sjo}}
);
