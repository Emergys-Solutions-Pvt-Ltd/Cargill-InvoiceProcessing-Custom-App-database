-- GENERATED from common/invoices/templates/tables/40_{{T}}.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.sjo_invoices - SJO invoices (Invoices grid, Create / Bulk upload, Invoice Details)
-- Every app has its own invoice table; invoice ids are unique per app.
-- Common core columns (identical in gpp / sjo / rospbu) + the SJO fields.
-- Depends on: app.app_modules, app.vendors, app.country_stations, app.statuses, app.processes,
--             app.cities, app.teams, app_auth.users, app.countries, app.business_units, sjo.erp_systems
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS sjo.sjo_invoices (
    id                          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_sjo_invoices PRIMARY KEY,
    invoice_code                varchar(60)     NOT NULL CONSTRAINT uq_sjo_invoices_code UNIQUE,   -- public id, unique within SJO
    module_id                   uuid         NOT NULL CONSTRAINT fk_sjo_invoices_module  REFERENCES app.app_modules (id),
    vendor_id                   uuid         NULL     CONSTRAINT fk_sjo_invoices_vendor  REFERENCES app.vendors (id),
    station_id                  uuid         NULL     CONSTRAINT fk_sjo_invoices_station REFERENCES app.country_stations (id),
    invoice_1a                  varchar(30)     NULL,           -- "1a Invoice" column
    invoice_2a                  varchar(30)     NULL,           -- "2a Invoice" column
    first_invoice_number        varchar(20)     NULL,           -- 1° Invoice Number (point of sale)
    second_invoice_number       varchar(20)     NULL,           -- 2° Invoice Number
    invoice_date                date            NULL,
    expiry_days                 integer         NULL,
    invoice_expiry_date         timestamptz(0)  NULL,
    support_team                boolean         NOT NULL DEFAULT false,
    pre_settlement_number       varchar(30)     NULL,
    credit_note                 boolean         NOT NULL DEFAULT false,
    currency_code               char(3)         NOT NULL DEFAULT 'ARS',
    amount                      numeric(18,2)   NOT NULL CONSTRAINT ck_sjo_invoices_amount CHECK (amount >= 0),
    invoice_subtotal            numeric(18,2)   NULL,
    invoice_subtotal_with_tax   numeric(18,2)   NULL,
    status                      varchar(20)     NOT NULL DEFAULT 'Pending'
                                CONSTRAINT fk_sjo_invoices_status REFERENCES app.statuses (code) ON UPDATE CASCADE,
    reception_date              date            NOT NULL,
    email_reception_date        timestamptz(0)  NULL,
    -- Workflow / Super User fields (Invoice Details page)
    process_id                  uuid         NULL CONSTRAINT fk_sjo_invoices_process          REFERENCES app.processes (id),
    origin_city_id              uuid         NULL CONSTRAINT fk_sjo_invoices_origin_city      REFERENCES app.cities (id),
    destination_city_id         uuid         NULL CONSTRAINT fk_sjo_invoices_destination_city REFERENCES app.cities (id),
    team_id                     uuid         NULL CONSTRAINT fk_sjo_invoices_team             REFERENCES app.teams (id),   -- the "Stage"
    assigned_user_id            uuid         NULL CONSTRAINT fk_sjo_invoices_assigned_user    REFERENCES app_auth.users (id),
    claim_number                numeric(18,2)   NOT NULL DEFAULT 0 CONSTRAINT ck_sjo_invoices_claim_number CHECK (claim_number >= 0),
    additional_info             varchar(1000)   NULL,
    filenet_id                  varchar(60)     NULL,           -- document id in IBM FileNet

    -- SJO fields (formerly sjo.invoice_sjo_fields). NULL for invoices imported by SAP / OnBase until
    -- saved in Invoice Details; Create Invoice and Details "Save" require country, BU, ERP, ID Fiscal.
    country_id                  uuid         NULL CONSTRAINT fk_sjo_invoices_country REFERENCES app.countries (id),
    business_unit_id            uuid         NULL CONSTRAINT fk_sjo_invoices_bu      REFERENCES app.business_units (id),
    erp_system_id               uuid         NULL CONSTRAINT fk_sjo_invoices_erp     REFERENCES sjo.erp_systems (id),
    id_fiscal                   varchar(30)     NULL,           -- vendor tax id, e.g. 135266470
    ab_number                   varchar(30)     NULL,           -- JDE Address Book number, e.g. 39102783
    ab_name                     varchar(255)    NULL,           -- Address Book name, e.g. CITIBANK NA
    flow_turn_down              boolean         NOT NULL DEFAULT false,
    critical_vendor             boolean         NOT NULL DEFAULT false,
    urgent_invoice              boolean         NOT NULL DEFAULT false,

    created_by                  uuid         NULL CONSTRAINT fk_sjo_invoices_created_by REFERENCES app_auth.users (id),
    updated_by                  uuid         NULL CONSTRAINT fk_sjo_invoices_updated_by REFERENCES app_auth.users (id),
    created_at                  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at                  timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_sjo_invoices_id_fiscal CHECK (id_fiscal IS NULL OR btrim(id_fiscal) <> '')
);

CREATE INDEX IF NOT EXISTS ix_sjo_invoices_module_status   ON sjo.sjo_invoices (module_id, status) INCLUDE (reception_date, amount);
CREATE INDEX IF NOT EXISTS ix_sjo_invoices_module_received ON sjo.sjo_invoices (module_id, reception_date DESC);
CREATE INDEX IF NOT EXISTS ix_sjo_invoices_vendor          ON sjo.sjo_invoices (vendor_id);
CREATE INDEX IF NOT EXISTS ix_sjo_invoices_team            ON sjo.sjo_invoices (team_id);
CREATE INDEX IF NOT EXISTS ix_sjo_invoices_assigned_user   ON sjo.sjo_invoices (assigned_user_id);

CREATE INDEX IF NOT EXISTS ix_sjo_invoices_id_fiscal       ON sjo.sjo_invoices (id_fiscal);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
