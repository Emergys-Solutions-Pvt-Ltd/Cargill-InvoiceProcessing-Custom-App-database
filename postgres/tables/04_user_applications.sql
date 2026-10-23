-- =====================================================================
-- app.user_applications - which applications each user may access
-- Depends on: app.users, app.applications
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.user_applications (
    user_id         integer         NOT NULL CONSTRAINT fk_user_apps_user REFERENCES app.users (id) ON DELETE CASCADE,
    application_id  integer         NOT NULL CONSTRAINT fk_user_apps_app  REFERENCES app.applications (id),
    assigned_at     timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT pk_user_applications PRIMARY KEY (user_id, application_id)
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
