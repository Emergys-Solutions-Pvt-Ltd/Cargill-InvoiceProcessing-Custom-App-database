-- =====================================================================
-- app.udt_invoice_input - REQUEST type: one invoice to create (Create Invoice / Bulk Upload)
-- Used by: app.usp_invoice_create_batch(p_invoices jsonb) - the JSON array is converted
-- with jsonb_populate_recordset(NULL::app.udt_invoice_input, ...), so keys must match.
-- country_station is the UI value "CCC - Station Name".
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_input AS (
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
    email_reception_date    timestamptz(0)
);
