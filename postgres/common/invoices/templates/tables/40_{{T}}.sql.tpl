-- =====================================================================
-- {{S}}.{{T}} - {{APP}} invoices (Invoices grid, Create / Bulk upload, Invoice Details)
-- Every app has its own invoice table; invoice ids are unique per app.
-- Common core columns (identical in gpp / sjo / rospbu) + the {{APP}} fields.
-- Depends on: app.app_modules, app.vendors, app.country_stations, app.statuses, app.processes,
--             app.cities, app.teams, app_auth.users{{#sjo}}, app.countries, app.business_units, sjo.erp_systems{{/sjo}}
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS {{S}}.{{T}} (
    id                          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_{{T}} PRIMARY KEY,
    invoice_code                varchar(60)     NOT NULL CONSTRAINT uq_{{T}}_code UNIQUE,   -- public id, unique within {{APP}}
    module_id                   uuid         NOT NULL CONSTRAINT fk_{{T}}_module  REFERENCES app.app_modules (id),
    vendor_id                   uuid         NULL     CONSTRAINT fk_{{T}}_vendor  REFERENCES app.vendors (id),
    station_id                  uuid         NULL     CONSTRAINT fk_{{T}}_station REFERENCES app.country_stations (id),
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
    amount                      numeric(18,2)   NOT NULL CONSTRAINT ck_{{T}}_amount CHECK (amount >= 0),
    invoice_subtotal            numeric(18,2)   NULL,
    invoice_subtotal_with_tax   numeric(18,2)   NULL,
    status                      varchar(20)     NOT NULL DEFAULT 'Pending'
                                CONSTRAINT fk_{{T}}_status REFERENCES app.statuses (code) ON UPDATE CASCADE,
    reception_date              date            NOT NULL,
    email_reception_date        timestamptz(0)  NULL,
    -- Workflow / Super User fields (Invoice Details page)
    process_id                  uuid         NULL CONSTRAINT fk_{{T}}_process          REFERENCES app.processes (id),
    origin_city_id              uuid         NULL CONSTRAINT fk_{{T}}_origin_city      REFERENCES app.cities (id),
    destination_city_id         uuid         NULL CONSTRAINT fk_{{T}}_destination_city REFERENCES app.cities (id),
    team_id                     uuid         NULL CONSTRAINT fk_{{T}}_team             REFERENCES app.teams (id),   -- the "Stage"
    assigned_user_id            uuid         NULL CONSTRAINT fk_{{T}}_assigned_user    REFERENCES app_auth.users (id),
    claim_number                numeric(18,2)   NOT NULL DEFAULT 0 CONSTRAINT ck_{{T}}_claim_number CHECK (claim_number >= 0),
    additional_info             varchar(1000)   NULL,
    filenet_id                  varchar(60)     NULL,           -- document id in IBM FileNet
{{#gpp}}
    -- GPP: legacy Salesforce "GP Invoice" fields (formerly gpp.invoice_sf_fields)
    invoice_1a_2a_cancel            varchar(50)     NULL,
    first_invoice_number_cancel     varchar(5)      NULL,
    second_invoice_number_cancel    varchar(8)      NULL,
    ab_number                       varchar(255)    NULL,
    accounting_register             numeric(18,0)   NULL,
    code_of_imputation              varchar(255)    NULL,
    code_of_imputation_str          varchar(255)    NULL,
    gp_code_of_imputation           text            NULL,
    cost_center                     numeric(18,0)   NULL,
    jde_number                      varchar(20)     NULL,
    nro_de_o6                       varchar(255)    NULL,
    po_number                       varchar(255)    NULL,
    x1_number                       varchar(255)    NULL,
    owner_legacy_id                 text            NULL,
    user_legacy_id                  text            NULL,
    ros_cuit_legacy_id              text            NULL,
    adjustment_approval             varchar(100)    NULL,
    branch_plant                    varchar(100)    NULL,
    center                          varchar(100)    NULL,
    code_type                       varchar(100)    NULL,
    drei                            varchar(100)    NULL,
    adjustment_doc                  varchar(100)    NULL,
    installment_payment             varchar(100)    NULL,
    invoice_type                    varchar(100)    NULL,
    order_type                      varchar(100)    NULL,
    pending_reason                  varchar(100)    NULL,
    reject_reason                   varchar(100)    NULL,
    sub_process                     varchar(100)    NULL,
    producto                        varchar(100)    NULL,
    area                            text            NULL,
    cbs_observation                 text            NULL,
    computation_formula             text            NULL,
    expense_type                    text            NULL,
    description                     text            NULL,
    admin_observation               varchar(255)    NULL,
    approval_observation            varchar(255)    NULL,
    attachment_name_before_change   varchar(255)    NULL,
    credit_note_comments            varchar(255)    NULL,
    distribution_type               varchar(255)    NULL,
    notes                           varchar(255)    NULL,
    observation                     varchar(255)    NULL,
    reject_observation              varchar(255)    NULL,
    client_email                    varchar(255)    NULL,
    admin_approved_date             timestamptz(0)  NULL,
    approval_date                   timestamptz(0)  NULL,
    cae_expiration_date             date            NULL,
    processed_date                  timestamptz(0)  NULL,
    rejection_date                  timestamptz(0)  NULL,
    due_date_invoice                date            NULL,
    cae_number                      numeric(15,0)   NULL,
    exchange_rate                   numeric(16,2)   NULL,
    payment_term                    numeric(16,2)   NULL,
    cantidad                        numeric(18,0)   NULL,
    is_boortmal_invoice             boolean         NOT NULL DEFAULT false,
    bu_employee_approver_done       boolean         NOT NULL DEFAULT false,
    is_distribution                 boolean         NOT NULL DEFAULT false,
    is_downloaded_invoice           boolean         NOT NULL DEFAULT false,
    has_po                          boolean         NOT NULL DEFAULT false,
    is_high_priority                boolean         NOT NULL DEFAULT false,
    is_invoice_paid                 boolean         NOT NULL DEFAULT false,
    need_approval                   boolean         NOT NULL DEFAULT false,
    po_attached                     boolean         NOT NULL DEFAULT false,
    vip_control_done                boolean         NOT NULL DEFAULT false,
{{/gpp}}
{{#sjo}}
    -- SJO fields (formerly sjo.invoice_sjo_fields). NULL for invoices imported by SAP / OnBase until
    -- saved in Invoice Details; Create Invoice and Details "Save" require country, BU, ERP, ID Fiscal.
    country_id                  uuid         NULL CONSTRAINT fk_{{T}}_country REFERENCES app.countries (id),
    business_unit_id            uuid         NULL CONSTRAINT fk_{{T}}_bu      REFERENCES app.business_units (id),
    erp_system_id               uuid         NULL CONSTRAINT fk_{{T}}_erp     REFERENCES sjo.erp_systems (id),
    id_fiscal                   varchar(30)     NULL,           -- vendor tax id, e.g. 135266470
    ab_number                   varchar(30)     NULL,           -- JDE Address Book number, e.g. 39102783
    ab_name                     varchar(255)    NULL,           -- Address Book name, e.g. CITIBANK NA
    flow_turn_down              boolean         NOT NULL DEFAULT false,
    critical_vendor             boolean         NOT NULL DEFAULT false,
    urgent_invoice              boolean         NOT NULL DEFAULT false,
{{/sjo}}
    created_by                  uuid         NULL CONSTRAINT fk_{{T}}_created_by REFERENCES app_auth.users (id),
    updated_by                  uuid         NULL CONSTRAINT fk_{{T}}_updated_by REFERENCES app_auth.users (id),
    created_at                  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at                  timestamptz(0)  NOT NULL DEFAULT now(){{#sjo}},
    CONSTRAINT ck_{{T}}_id_fiscal CHECK (id_fiscal IS NULL OR btrim(id_fiscal) <> ''){{/sjo}}
);

CREATE INDEX IF NOT EXISTS ix_{{T}}_module_status   ON {{S}}.{{T}} (module_id, status) INCLUDE (reception_date, amount);
CREATE INDEX IF NOT EXISTS ix_{{T}}_module_received ON {{S}}.{{T}} (module_id, reception_date DESC);
CREATE INDEX IF NOT EXISTS ix_{{T}}_vendor          ON {{S}}.{{T}} (vendor_id);
CREATE INDEX IF NOT EXISTS ix_{{T}}_team            ON {{S}}.{{T}} (team_id);
CREATE INDEX IF NOT EXISTS ix_{{T}}_assigned_user   ON {{S}}.{{T}} (assigned_user_id);
{{#sjo}}
CREATE INDEX IF NOT EXISTS ix_{{T}}_id_fiscal       ON {{S}}.{{T}} (id_fiscal);
{{/sjo}}

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
