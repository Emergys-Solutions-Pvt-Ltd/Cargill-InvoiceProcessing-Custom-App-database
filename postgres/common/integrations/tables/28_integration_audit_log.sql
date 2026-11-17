-- =====================================================================
-- app.integration_audit_log - who changed or triggered what on an integration
-- action: created | updated | deleted | secret_rotated | connection_tested | sync_requested |
--         job_retried | job_cancelled | cursor_reset
-- details lists changed field names and outcomes, never values of secrets.
-- Rows survive the integration (integration_id is cleared, details keep its name).
-- Depends on: app.integrations, app_auth.users
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.integration_audit_log (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_integration_audit_log PRIMARY KEY,
    integration_id  uuid         NULL CONSTRAINT fk_integration_audit_integration REFERENCES app.integrations (id) ON DELETE SET NULL,
    actor_user_id   uuid         NULL CONSTRAINT fk_integration_audit_actor REFERENCES app_auth.users (id) ON DELETE SET NULL,
    action          varchar(30)     NOT NULL,
    details         jsonb           NULL,
    created_at      timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_integration_audit_integration ON app.integration_audit_log (integration_id, created_at DESC);
