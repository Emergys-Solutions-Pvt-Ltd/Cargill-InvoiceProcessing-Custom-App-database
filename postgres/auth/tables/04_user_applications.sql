-- =====================================================================
-- app_auth.user_applications - which applications each user may access
-- Depends on: app_auth.users, app.applications
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app_auth.user_applications (
    user_id         uuid         NOT NULL CONSTRAINT fk_user_apps_user REFERENCES app_auth.users (id) ON DELETE CASCADE,
    application_id  uuid         NOT NULL CONSTRAINT fk_user_apps_app  REFERENCES app.applications (id),
    assigned_at     timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT pk_user_applications PRIMARY KEY (user_id, application_id)
);
