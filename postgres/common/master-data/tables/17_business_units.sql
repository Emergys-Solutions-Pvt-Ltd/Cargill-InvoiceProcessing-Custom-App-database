-- =====================================================================
-- app.business_units - Configuration > Business units (BUs)
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.business_units (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_business_units PRIMARY KEY,
    code        varchar(30)     NOT NULL,                       -- e.g. ROSPBU
    name        varchar(150)    NOT NULL,
    description varchar(500)    NULL,
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_business_units_code ON app.business_units (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS uq_business_units_name ON app.business_units (lower(name));
