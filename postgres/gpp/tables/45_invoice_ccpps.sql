-- =====================================================================
-- gpp.invoice_ccpps - CCPPs tab (Carta de Porte entries linked to the invoice)
-- Depends on: gpp.gpp_invoices (CCPP rows exist for GPP invoices only)
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
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
    tons_fc             numeric(18,2)   NULL
);

CREATE INDEX IF NOT EXISTS ix_invoice_ccpps_invoice ON gpp.invoice_ccpps (invoice_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
-- Legacy Salesforce "GP CCPP" object fields (55-field export, reconciled against this table
-- 2026-11-02 - ../shared/handoffs/database.md). Named/typed from the SF field, not renamed to
-- this app's conventions, same approach as gpp.invoice_sf_fields. Not carried over: Link Invoice
-- (= invoice_id, the FK itself), Link Invoice CUIT and Linked Invoice Name (SF formulas, both
-- derivable via invoice_id -> app.invoices/app.vendors - nothing to store).
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS third_jurisdiction      varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS ab                      varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS aux                     varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS bp                      varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS closed_quantity         numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS pending_quantity        numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS total_quantity          numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS cc                      varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS cia                     varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS withholding_code        varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS withholding_concept     varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS matching                varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS created_by              uuid      NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS account                 varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS cuit                    varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS line_description        text         NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS receipt_detail          varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS status1                 varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS status2                 varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS receipt_date            varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS gcia                    varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS name                    varchar(100) NULL;  -- SF "GP CCPP Name" auto-number; legacy display id, not generated here
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS iibb_destination        varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS iibb_origin             varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS closed_amount           varchar(20)  NULL;  -- SF type is Text(20) despite the name
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS line_amount             numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS matched_amount          varchar(20)  NULL;  -- SF type is Text(20) despite the name
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS pending_amount          numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS order_total_amount      numeric(16,2) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS vat                     varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS updated_by              uuid      NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS line                    numeric(18,0) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS currency                varchar(10)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS municipality            varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS order_number            varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS receipt_number          varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS observation             text         NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS origin_destination_drei varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS owner_legacy_id         text         NULL;  -- SF "Owner" Lookup(User,Group) - polymorphic, raw legacy id like invoice_sf_fields.owner_legacy_id
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS praclo                  varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS praptd                  varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS prdgl                   varchar(50)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS province                varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS pruorg                  varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS suss                    varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS tax_area                varchar(255) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS order_type              varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS receipt_type            varchar(20)  NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS take_line               varchar(100) NULL;
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS unique_ccpp             varchar(255) NULL;  -- SF External ID
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS user_legacy_id          varchar(50)  NULL;  -- SF "User" is plain Text(50), not a real Lookup despite the name
ALTER TABLE gpp.invoice_ccpps ADD COLUMN IF NOT EXISTS fiscal_zone             varchar(100) NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoice_ccpps_created_by') THEN
        ALTER TABLE gpp.invoice_ccpps ADD CONSTRAINT fk_invoice_ccpps_created_by FOREIGN KEY (created_by) REFERENCES app_auth.users (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoice_ccpps_updated_by') THEN
        ALTER TABLE gpp.invoice_ccpps ADD CONSTRAINT fk_invoice_ccpps_updated_by FOREIGN KEY (updated_by) REFERENCES app_auth.users (id);
    END IF;
END $$;
