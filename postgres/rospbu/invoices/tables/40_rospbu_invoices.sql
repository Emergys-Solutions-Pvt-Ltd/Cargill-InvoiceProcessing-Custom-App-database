-- GENERATED from common/invoices/templates/tables/40_{{T}}.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- rospbu.rospbu_invoices - ROSPBU invoices (Invoices grid, Create / Bulk upload, Invoice Details)
-- Every app has its own invoice table; invoice ids are unique per app.
-- Common core columns (identical in gpp / sjo / rospbu) + the ROSPBU fields.
-- Depends on: app.app_modules, app.vendors, app.country_stations, app.statuses, app.processes,
--             app.cities, app.teams, app_auth.users, app.countries, app.business_units, sjo.erp_systems
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS rospbu.rospbu_invoices (
    id                          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_rospbu_invoices PRIMARY KEY,
    invoice_code                varchar(60)     NOT NULL CONSTRAINT uq_rospbu_invoices_code UNIQUE,   -- public id, unique within ROSPBU
    module_id                   uuid         NOT NULL CONSTRAINT fk_rospbu_invoices_module  REFERENCES app.app_modules (id),
    vendor_id                   uuid         NULL     CONSTRAINT fk_rospbu_invoices_vendor  REFERENCES app.vendors (id),
    station_id                  uuid         NULL     CONSTRAINT fk_rospbu_invoices_station REFERENCES app.country_stations (id),
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
    amount                      numeric(18,2)   NOT NULL CONSTRAINT ck_rospbu_invoices_amount CHECK (amount >= 0),
    invoice_subtotal            numeric(18,2)   NULL,
    invoice_subtotal_with_tax   numeric(18,2)   NULL,
    status                      varchar(20)     NOT NULL DEFAULT 'Pending'
                                CONSTRAINT fk_rospbu_invoices_status REFERENCES app.statuses (code) ON UPDATE CASCADE,
    reception_date              date            NOT NULL,
    email_reception_date        timestamptz(0)  NULL,
    -- Workflow / Super User fields (Invoice Details page)
    process_id                  uuid         NULL CONSTRAINT fk_rospbu_invoices_process          REFERENCES app.processes (id),
    origin_city_id              uuid         NULL CONSTRAINT fk_rospbu_invoices_origin_city      REFERENCES app.cities (id),
    destination_city_id         uuid         NULL CONSTRAINT fk_rospbu_invoices_destination_city REFERENCES app.cities (id),
    team_id                     uuid         NULL CONSTRAINT fk_rospbu_invoices_team             REFERENCES app.teams (id),   -- the "Stage"
    assigned_user_id            uuid         NULL CONSTRAINT fk_rospbu_invoices_assigned_user    REFERENCES app_auth.users (id),
    claim_number                numeric(18,2)   NOT NULL DEFAULT 0 CONSTRAINT ck_rospbu_invoices_claim_number CHECK (claim_number >= 0),
    additional_info             varchar(1000)   NULL,
    filenet_id                  varchar(60)     NULL,           -- document id in IBM FileNet

    -- ROSPBU fields ("ROSPBU Invoice Edit" page). Total de la FC = amount, Fecha de Fc = invoice_date,
    -- Moneda de la Fc = currency_code, Adicional Info = additional_info (common columns). All optional.
    country_id                  uuid         NULL CONSTRAINT fk_rospbu_invoices_country REFERENCES app.countries (id),        -- Pais
    business_unit_id            uuid         NULL CONSTRAINT fk_rospbu_invoices_bu      REFERENCES app.business_units (id),   -- BU
    erp_system_id               uuid         NULL CONSTRAINT fk_rospbu_invoices_erp     REFERENCES sjo.erp_systems (id),      -- ERP
    retencion                   varchar(50)     NOT NULL DEFAULT 'No aplica',
    codigo_imputacion           varchar(255)    NULL,
    nro_ar                      varchar(50)     NULL,
    cantidad                    numeric(18,2)   NULL,
    producto                    varchar(255)    NULL,
    np                          varchar(4000)   NULL,
    nro_remito                  varchar(50)     NULL,           -- N de remito
    filial                      varchar(100)    NULL,
    numero_documento            varchar(50)     NULL,
    general_comment             varchar(1000)   NULL,
    centro_emisor               varchar(20)     NULL,
    due_date                    date            NULL,           -- Fecha de Vencimiento
    po_number                   varchar(50)     NULL,           -- N de OC
    instrumento_pago            varchar(100)    NULL,
    timbrado                    varchar(50)     NULL,
    bp_number                   varchar(50)     NULL,
    numero_liquidacion          varchar(50)     NULL,
    branch_plant                varchar(100)    NULL,
    tipo_operacion              varchar(100)    NULL,           -- G_TIPO_OPER

    created_by                  uuid         NULL CONSTRAINT fk_rospbu_invoices_created_by REFERENCES app_auth.users (id),
    updated_by                  uuid         NULL CONSTRAINT fk_rospbu_invoices_updated_by REFERENCES app_auth.users (id),
    created_at                  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at                  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_rospbu_invoices_module_status   ON rospbu.rospbu_invoices (module_id, status) INCLUDE (reception_date, amount);
CREATE INDEX IF NOT EXISTS ix_rospbu_invoices_module_received ON rospbu.rospbu_invoices (module_id, reception_date DESC);
CREATE INDEX IF NOT EXISTS ix_rospbu_invoices_vendor          ON rospbu.rospbu_invoices (vendor_id);
CREATE INDEX IF NOT EXISTS ix_rospbu_invoices_team            ON rospbu.rospbu_invoices (team_id);
CREATE INDEX IF NOT EXISTS ix_rospbu_invoices_assigned_user   ON rospbu.rospbu_invoices (assigned_user_id);

