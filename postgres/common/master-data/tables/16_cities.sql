-- =====================================================================
-- app.cities - Configuration > Cities, each belonging to a state
-- Depends on: app.states
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.cities (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_cities PRIMARY KEY,
    state_id    uuid         NOT NULL CONSTRAINT fk_cities_state REFERENCES app.states (id),
    code        varchar(30)     NULL,
    name        varchar(150)    NOT NULL,
    description varchar(500)    NULL,
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cities_name ON app.cities (state_id, lower(name));
CREATE INDEX IF NOT EXISTS ix_cities_state ON app.cities (state_id);
