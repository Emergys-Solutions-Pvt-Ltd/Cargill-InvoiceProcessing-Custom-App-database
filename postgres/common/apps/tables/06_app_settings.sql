-- =====================================================================
-- app.app_settings - per-module settings (Admin Configuration "Save Changes")
-- Depends on: app.app_modules, app_auth.users
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.app_settings (
    module_id               uuid         NOT NULL CONSTRAINT pk_app_settings PRIMARY KEY
                                            CONSTRAINT fk_app_settings_module REFERENCES app.app_modules (id) ON DELETE CASCADE,
    enable_notifications    boolean         NOT NULL DEFAULT true,
    max_invoices_limit      integer         NOT NULL DEFAULT 100 CONSTRAINT ck_app_settings_max CHECK (max_invoices_limit >= 0),
    updated_by              uuid         NULL CONSTRAINT fk_app_settings_user REFERENCES app_auth.users (id),
    updated_at              timestamptz(0)  NOT NULL DEFAULT now()
);
