-- =====================================================================
-- {{S}}.invoice_external_refs - where an imported {{APP}} invoice came from (traceability + de-duplication)
-- (source_system, external_key) is unique within {{APP}}, so a source document produces one {{APP}}
-- invoice whichever integration, profile or job imports it. payload_hash detects changes so
-- unchanged records are skipped on re-sync. Never purged: links the invoice to its source,
-- profile and the first / last job that touched it.
-- Depends on: {{S}}.{{T}}, app.integrations, app.integration_profiles, app.integration_sync_jobs
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS {{S}}.invoice_external_refs (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_{{S}}_external_refs PRIMARY KEY,
    invoice_id          uuid         NOT NULL CONSTRAINT fk_{{S}}_external_refs_invoice REFERENCES {{S}}.{{T}} (id) ON DELETE CASCADE,
    source_system       varchar(100)    NOT NULL,
    external_key        varchar(200)    NOT NULL,                   -- e.g. '1010/2026/5105600123'
    integration_id      uuid         NULL CONSTRAINT fk_{{S}}_external_refs_integration REFERENCES app.integrations (id) ON DELETE SET NULL,
    profile_id          uuid         NULL CONSTRAINT fk_{{S}}_external_refs_profile REFERENCES app.integration_profiles (id) ON DELETE SET NULL,
    external_doc        jsonb           NULL,                       -- key fields by name, e.g. {"CompanyCode": "1010", ...}
    source_changed_at   timestamptz(3)  NULL,
    payload_hash        char(64)        NOT NULL,                   -- sha256 of the mapped invoice
    source_state        varchar(20)     NOT NULL DEFAULT 'active',  -- active | cancelled
    first_job_id        uuid         NULL CONSTRAINT fk_{{S}}_external_refs_first_job REFERENCES app.integration_sync_jobs (id) ON DELETE SET NULL,
    last_job_id         uuid         NULL CONSTRAINT fk_{{S}}_external_refs_last_job REFERENCES app.integration_sync_jobs (id) ON DELETE SET NULL,
    first_synced_at     timestamptz(0)  NOT NULL DEFAULT now(),
    last_synced_at      timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_{{S}}_external_refs_state CHECK (source_state IN ('active', 'cancelled'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_{{S}}_external_refs_source_key ON {{S}}.invoice_external_refs (source_system, external_key);
CREATE UNIQUE INDEX IF NOT EXISTS ux_{{S}}_external_refs_invoice ON {{S}}.invoice_external_refs (invoice_id);
CREATE INDEX IF NOT EXISTS ix_{{S}}_external_refs_integration ON {{S}}.invoice_external_refs (integration_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
