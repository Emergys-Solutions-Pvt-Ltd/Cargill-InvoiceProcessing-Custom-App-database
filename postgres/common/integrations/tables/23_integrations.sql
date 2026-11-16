-- =====================================================================
-- app.integrations - external invoice sources (Settings > SAP Configuration)
-- One row per configured connection, e.g. "SAP S/4HANA Production". provider_type selects
-- the backend provider ('sap-odata'); connection and auth_settings are provider-specific
-- JSON validated by that provider. Secrets are never stored in clear text:
-- secret_ciphertext holds the AES-256-GCM encrypted credentials (backend SecretStore).
-- source_system identifies the source for invoice de-duplication (invoice_external_refs),
-- so it must stay stable for the life of the source system (e.g. 'S4P-100').
-- Depends on: app_auth.users
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.integrations (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_integrations PRIMARY KEY,
    provider_type       varchar(50)     NOT NULL,                   -- 'sap-odata'
    name                varchar(150)    NOT NULL,
    description         varchar(1000)   NULL,
    environment         varchar(100)    NULL,                       -- e.g. 'Production', 'QA'
    source_system       varchar(100)    NOT NULL,                   -- stable source id, e.g. 'S4P-100'
    is_active           boolean         NOT NULL DEFAULT true,
    connection          jsonb           NOT NULL DEFAULT '{}'::jsonb,   -- base URL, service path, timeouts, paging ...
    auth_type           varchar(50)     NOT NULL DEFAULT 'none',        -- none | basic | oauth2-client-credentials | api-key
    auth_settings       jsonb           NOT NULL DEFAULT '{}'::jsonb,   -- non-secret auth values (token URL, client id ...)
    secret_ciphertext   text            NULL,
    secret_updated_at   timestamptz(0)  NULL,
    schedule            jsonb           NOT NULL DEFAULT '{"mode": "interval", "intervalMinutes": 60, "timezone": "UTC"}'::jsonb,
    auto_sync_enabled   boolean         NOT NULL DEFAULT false,
    retry_policy        jsonb           NOT NULL DEFAULT '{"maxAttempts": 3, "baseDelaySeconds": 60, "maxDelaySeconds": 3600}'::jsonb,
    next_run_at         timestamptz(0)  NULL,
    last_attempt_at     timestamptz(0)  NULL,
    last_success_at     timestamptz(0)  NULL,
    last_status         varchar(30)     NULL,
    last_job_id         uuid         NULL,
    version             integer         NOT NULL DEFAULT 1,             -- optimistic concurrency for edits
    created_by          uuid         NULL CONSTRAINT fk_integrations_created_by REFERENCES app_auth.users (id) ON DELETE SET NULL,
    updated_by          uuid         NULL CONSTRAINT fk_integrations_updated_by REFERENCES app_auth.users (id) ON DELETE SET NULL,
    created_at          timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at          timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_integrations_connection   CHECK (jsonb_typeof(connection) = 'object'),
    CONSTRAINT ck_integrations_auth         CHECK (jsonb_typeof(auth_settings) = 'object'),
    CONSTRAINT ck_integrations_schedule     CHECK (jsonb_typeof(schedule) = 'object'),
    CONSTRAINT ck_integrations_retry        CHECK (jsonb_typeof(retry_policy) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_integrations_name ON app.integrations (lower(name));
-- Scheduler: integrations due for an automatic run
CREATE INDEX IF NOT EXISTS ix_integrations_due ON app.integrations (next_run_at)
    WHERE auto_sync_enabled AND is_active;

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
