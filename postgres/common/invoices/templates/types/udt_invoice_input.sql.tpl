-- =====================================================================
-- {{S}}.udt_invoice_input - REQUEST type: one {{APP}} invoice to create (Create Invoice / Bulk Upload)
-- Used by: {{S}}.usp_invoice_create_batch(p_invoices jsonb) - the JSON array is converted
-- with jsonb_populate_recordset(NULL::{{S}}.udt_invoice_input, ...), so keys must match.
-- country_station is the UI value "CCC - Station Name".
{{#sjo}}
-- SJO: vendor_name / cuit / amount are optional; sjo_country, sjo_business_unit, sjo_erp
-- (code or name of the Configuration item) and id_fiscal are required.
{{/sjo}}
{{#rospbu}}
-- ROSPBU: vendor_name / cuit / amount are optional, and so are the ROSPBU fields (rospbu_country, ...).
{{/rospbu}}
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
    assigned_user_id        uuid{{#sjo}},             -- "Assign To"
    sjo_country             varchar(150),
    sjo_business_unit       varchar(150),
    sjo_erp                 varchar(150),
    id_fiscal               varchar(30),
    ab_number               varchar(30),
    ab_name                 varchar(255),
    flow_turn_down          boolean,
    critical_vendor         boolean,
    urgent_invoice          boolean{{/sjo}}{{#rospbu}},             -- "Assign To"
    rospbu_country          varchar(150),         -- Pais / BU / ERP: code or name of the Configuration item
    rospbu_business_unit    varchar(150),
    rospbu_erp              varchar(150),
    retencion               varchar(50),
    codigo_imputacion       varchar(255),
    nro_ar                  varchar(50),
    cantidad                numeric(18,2),
    producto                varchar(255),
    np                      varchar(4000),
    nro_remito              varchar(50),
    filial                  varchar(100),
    additional_info         varchar(1000),
    numero_documento        varchar(50),
    general_comment         varchar(1000),
    invoice_date            date,
    centro_emisor           varchar(20),
    due_date                date,
    currency_code           varchar(3),
    po_number               varchar(50),
    instrumento_pago        varchar(100),
    timbrado                varchar(50),
    bp_number               varchar(50),
    numero_liquidacion      varchar(50),
    branch_plant            varchar(100),
    tipo_operacion          varchar(100){{/rospbu}}
);
