-- =====================================================================
-- app.app_settings - per-module settings (Admin Configuration "Save Changes")
-- Depends on: app.app_modules, app.users
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.app_settings (
    module_id               integer         NOT NULL CONSTRAINT pk_app_settings PRIMARY KEY
                                            CONSTRAINT fk_app_settings_module REFERENCES app.app_modules (id) ON DELETE CASCADE,
    enable_notifications    boolean         NOT NULL DEFAULT true,
    max_invoices_limit      integer         NOT NULL DEFAULT 100 CONSTRAINT ck_app_settings_max CHECK (max_invoices_limit >= 0),
    updated_by              integer         NULL CONSTRAINT fk_app_settings_user REFERENCES app.users (id),
    updated_at              timestamptz(0)  NOT NULL DEFAULT now()
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
