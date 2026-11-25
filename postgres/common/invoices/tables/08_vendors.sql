-- =====================================================================
-- app.vendors - invoice vendors, unique by CUIT (Argentine tax id)
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.vendors (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_vendors PRIMARY KEY,
    legal_name  varchar(255)    NOT NULL,
    cuit        varchar(20)     NOT NULL CONSTRAINT uq_vendors_cuit UNIQUE,   -- e.g. 30-50001234-9
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now()
);
