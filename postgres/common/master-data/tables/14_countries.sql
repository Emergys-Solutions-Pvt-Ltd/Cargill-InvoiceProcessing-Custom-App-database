-- =====================================================================
-- app.countries - Configuration > Countries (master data)
-- Shares the master-data column set (code, name, description, sort_order, is_active)
-- managed generically by app.usp_master_data_* (see 20_master_data_entities.sql).
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.countries (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_countries PRIMARY KEY,
    code        varchar(30)     NOT NULL,                       -- ISO 3166 alpha-3, e.g. ARG
    name        varchar(150)    NOT NULL,
    description varchar(500)    NULL,
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_countries_code ON app.countries (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS uq_countries_name ON app.countries (lower(name));
