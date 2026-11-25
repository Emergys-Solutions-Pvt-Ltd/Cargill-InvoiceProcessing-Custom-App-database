-- =====================================================================
-- gpp.invoice_ccpps - CCPPs tab (Carta de Porte entries linked to the invoice)
-- Depends on: gpp.gpp_invoices (CCPP rows exist for GPP invoices only)
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS gpp.invoice_ccpps (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_invoice_ccpps PRIMARY KEY,
    invoice_id          uuid         NOT NULL CONSTRAINT fk_gpp_ccpps_invoice REFERENCES gpp.gpp_invoices (id) ON DELETE CASCADE,
    product             varchar(100)    NOT NULL,           -- producto
    legal_doc_issuer    varchar(200)    NULL,               -- emitDocLegal
    status              varchar(50)     NOT NULL,           -- e.g. S-Sin Factura
    value               numeric(18,2)   NULL,               -- valor
    km                  numeric(10,2)   NULL,
    tons                numeric(18,2)   NULL,               -- toneladas
    unit_rate           numeric(18,2)   NULL,               -- tarifaUnitaria
    km_fc               numeric(10,2)   NULL,
    tons_fc             numeric(18,2)   NULL,
    -- Legacy Salesforce "GP CCPP" object fields (55-field export, reconciled 2026-11-02). Named/typed
    -- from the SF field, same approach as the GP invoice legacy fields. Not carried over: Link Invoice
    -- (= invoice_id), Link Invoice CUIT and Linked Invoice Name (SF formulas, derivable via invoice_id).
    third_jurisdiction      varchar(255) NULL,
    ab                      varchar(20) NULL,
    aux                     varchar(20) NULL,
    bp                      varchar(50) NULL,
    closed_quantity         numeric(16,2) NULL,
    pending_quantity        numeric(16,2) NULL,
    total_quantity          numeric(16,2) NULL,
    cc                      varchar(50) NULL,
    cia                     varchar(20) NULL,
    withholding_code        varchar(255) NULL,
    withholding_concept     varchar(255) NULL,
    matching                varchar(20) NULL,
    created_by              uuid NULL,
    account                 varchar(20) NULL,
    cuit                    varchar(20) NULL,
    line_description        text NULL,
    receipt_detail          varchar(255) NULL,
    status1                 varchar(50) NULL,
    status2                 varchar(50) NULL,
    receipt_date            varchar(50) NULL,
    gcia                    varchar(100) NULL,
    name                    varchar(100) NULL,
    iibb_destination        varchar(100) NULL,
    iibb_origin             varchar(100) NULL,
    closed_amount           varchar(20) NULL,
    line_amount             numeric(16,2) NULL,
    matched_amount          varchar(20) NULL,
    pending_amount          numeric(16,2) NULL,
    order_total_amount      numeric(16,2) NULL,
    vat                     varchar(100) NULL,
    updated_by              uuid NULL,
    line                    numeric(18,0) NULL,
    currency                varchar(10) NULL,
    municipality            varchar(100) NULL,
    order_number            varchar(20) NULL,
    receipt_number          varchar(20) NULL,
    observation             text NULL,
    origin_destination_drei varchar(255) NULL,
    owner_legacy_id         text NULL,
    praclo                  varchar(20) NULL,
    praptd                  varchar(20) NULL,
    prdgl                   varchar(50) NULL,
    province                varchar(255) NULL,
    pruorg                  varchar(20) NULL,
    suss                    varchar(100) NULL,
    tax_area                varchar(255) NULL,
    order_type              varchar(20) NULL,
    receipt_type            varchar(20) NULL,
    take_line               varchar(100) NULL,
    unique_ccpp             varchar(255) NULL,
    user_legacy_id          varchar(50) NULL,
    fiscal_zone             varchar(100) NULL,
    CONSTRAINT fk_invoice_ccpps_created_by FOREIGN KEY (created_by) REFERENCES app_auth.users (id),
    CONSTRAINT fk_invoice_ccpps_updated_by FOREIGN KEY (updated_by) REFERENCES app_auth.users (id)
);

CREATE INDEX IF NOT EXISTS ix_invoice_ccpps_invoice ON gpp.invoice_ccpps (invoice_id);
