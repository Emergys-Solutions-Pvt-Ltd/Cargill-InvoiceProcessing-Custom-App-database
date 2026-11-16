-- =====================================================================
-- app.integration_profiles - what to extract from an integration and where it goes
-- One profile per target app module (e.g. General Payments, SJO): provider-specific
-- extraction settings (OData entity set, $filter, $select ...), the mapping of source fields
-- to the application's invoice fields, and the incremental cursor (watermark).
-- Depends on: app.integrations, app.app_modules
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.integration_profiles (
    id                      uuid DEFAULT gen_random_uuid() CONSTRAINT pk_integration_profiles PRIMARY KEY,
    integration_id          uuid         NOT NULL CONSTRAINT fk_integration_profiles_integration
                                            REFERENCES app.integrations (id) ON DELETE CASCADE,
    module_id               uuid         NOT NULL CONSTRAINT fk_integration_profiles_module REFERENCES app.app_modules (id),
    name                    varchar(100)    NOT NULL,
    is_active               boolean         NOT NULL DEFAULT true,
    settings                jsonb           NOT NULL DEFAULT '{}'::jsonb,   -- provider-specific extraction settings
    key_fields              jsonb           NOT NULL DEFAULT '[]'::jsonb,   -- source fields forming the external key
    invoice_code_template   varchar(200)    NOT NULL,                       -- e.g. 'INV-{prefix}-SAP-{SupplierInvoice}-{FiscalYear}'
    field_mapping           jsonb           NOT NULL DEFAULT '{}'::jsonb,   -- invoice field -> { path, transform, constant }
    cancellation_rule       jsonb           NULL,                           -- { field, operator, values, setStatus, onlyWhenStatusIn }
    default_status          varchar(20)     NOT NULL DEFAULT 'Pending',
    initial_from            timestamptz(0)  NULL,                           -- first sync starts here (incremental profiles)
    watermark               timestamptz(3)  NULL,                           -- highest source change time fully processed
    watermark_updated_at    timestamptz(0)  NULL,
    sort_order              integer         NOT NULL DEFAULT 0,
    created_at              timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at              timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_integration_profiles_settings CHECK (jsonb_typeof(settings) = 'object'),
    CONSTRAINT ck_integration_profiles_keys     CHECK (jsonb_typeof(key_fields) = 'array'),
    CONSTRAINT ck_integration_profiles_mapping  CHECK (jsonb_typeof(field_mapping) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_integration_profiles_name ON app.integration_profiles (integration_id, lower(name));
CREATE INDEX IF NOT EXISTS ix_integration_profiles_module ON app.integration_profiles (module_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
