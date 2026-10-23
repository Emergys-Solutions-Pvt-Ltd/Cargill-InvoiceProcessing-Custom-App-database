-- =====================================================================
-- app.udt_invoice_result - RESPONSE type: invoice header (Invoices grid row / Invoice Detail)
-- Nested in udt_invoice_list_result and udt_invoice_detail_result.
-- pdf_* columns describe the primary attachment (NULL when the invoice has none).
-- process / origin / destination / team (stage) / assigned user / claim / FileNet are the
-- workflow fields edited on the Invoice Details page.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_result AS (
    id                           integer,
    invoice_code                 varchar(60),
    module_slug                  varchar(100),
    invoice_prefix               varchar(30),
    application_code             varchar(50),
    invoice_1a                   varchar(30),
    invoice_2a                   varchar(30),
    first_invoice_number         varchar(20),
    second_invoice_number        varchar(20),
    invoice_date                 date,
    expiry_days                  integer,
    invoice_expiry_date          timestamptz(0),
    support_team                 boolean,
    pre_settlement_number        varchar(30),
    credit_note                  boolean,
    currency_code                char(3),
    amount                       numeric(18,2),
    invoice_subtotal             numeric(18,2),
    invoice_subtotal_with_tax    numeric(18,2),
    status                       varchar(20),
    reception_date               date,
    email_reception_date         timestamptz(0),
    vendor_name                  varchar(255),
    cuit                         varchar(20),
    country_station              varchar(160),
    pdf_attachment_id            integer,
    pdf_file_name                varchar(255),
    pdf_title                    varchar(255),
    pdf_mime_type                varchar(100),
    process_id                   integer,
    process_name                 varchar(150),
    origin_city_id               integer,
    origin_name                  varchar(150),
    destination_city_id          integer,
    destination_name             varchar(150),
    team_id                      integer,
    team_name                    varchar(150),
    assigned_user_id             integer,
    assigned_user_name           varchar(200),
    claim_number                 numeric(18,2),
    additional_info              varchar(1000),
    filenet_id                   varchar(60)
);
