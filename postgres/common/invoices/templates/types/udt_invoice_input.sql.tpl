-- =====================================================================
-- {{S}}.udt_invoice_input - REQUEST type: one {{APP}} invoice to create (Create Invoice / Bulk Upload)
-- Used by: {{S}}.usp_invoice_create_batch(p_invoices jsonb) - the JSON array is converted
-- with jsonb_populate_recordset(NULL::{{S}}.udt_invoice_input, ...), so keys must match.
-- country_station is the UI value "CCC - Station Name".
{{#sjo}}
-- SJO: vendor_name / cuit / amount are optional; sjo_country, sjo_business_unit, sjo_erp
-- (code or name of the Configuration item) and id_fiscal are required.
{{/sjo}}
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE {{S}}.udt_invoice_input AS (
    row_no                  integer,              -- position in the request, for ordering / error reporting
    invoice_code            varchar(60),
    vendor_name             varchar(255),
    cuit                    varchar(20),
    country_station         varchar(160),
    invoice_1a              varchar(30),
    invoice_2a              varchar(30),
    amount                  numeric(18,2),
    status                  varchar(20),
    reception_date          date,
    email_reception_date    timestamptz(0),
    assigned_user_id        integer{{#sjo}},             -- "Assign To"
    sjo_country             varchar(150),
    sjo_business_unit       varchar(150),
    sjo_erp                 varchar(150),
    id_fiscal               varchar(30),
    ab_number               varchar(30),
    ab_name                 varchar(255),
    flow_turn_down          boolean,
    critical_vendor         boolean,
    urgent_invoice          boolean{{/sjo}}
);
