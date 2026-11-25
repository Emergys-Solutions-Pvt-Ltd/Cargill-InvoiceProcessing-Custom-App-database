-- =====================================================================
-- app.states - Configuration > States / provinces, each belonging to a country
-- Depends on: app.countries
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.states (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_states PRIMARY KEY,
    country_id  uuid         NOT NULL CONSTRAINT fk_states_country REFERENCES app.countries (id),
    code        varchar(30)     NULL,                           -- e.g. SF (Santa Fe)
    name        varchar(150)    NOT NULL,
    description varchar(500)    NULL,
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_states_name ON app.states (country_id, lower(name));
CREATE UNIQUE INDEX IF NOT EXISTS uq_states_code ON app.states (country_id, lower(code)) WHERE code IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_states_country ON app.states (country_id);
