-- =====================================================================
-- app.app_modules - UI route slugs (/app/:appId) mapped to their parent application
-- e.g. gp-tool, freight-processing -> GP ; sjo-index-processing -> sjo
-- Depends on: app.applications
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.app_modules (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_app_modules PRIMARY KEY,
    application_id  uuid         NOT NULL CONSTRAINT fk_app_modules_app REFERENCES app.applications (id),
    slug            varchar(100)    NOT NULL CONSTRAINT uq_app_modules_slug UNIQUE,
    name            varchar(150)    NOT NULL,
    invoice_prefix  varchar(30)     NOT NULL,                       -- used for INV-<PREFIX>-nnnn ids
    is_active       boolean         NOT NULL DEFAULT true
);
