-- =====================================================================
-- app.teams - team names used on the Admin Configuration screen
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.teams (
    id      uuid DEFAULT gen_random_uuid() CONSTRAINT pk_teams PRIMARY KEY,
    name    varchar(150)    NOT NULL CONSTRAINT uq_teams_name UNIQUE,
    -- Teams (queues) are master data managed under Settings > Configuration
    code        varchar(30)    NULL,
    description varchar(500)   NULL,
    sort_order  integer        NOT NULL DEFAULT 0,
    is_active   boolean        NOT NULL DEFAULT true,
    created_at  timestamptz(0) NOT NULL DEFAULT now(),
    updated_at  timestamptz(0) NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_teams_code ON app.teams (lower(code)) WHERE code IS NOT NULL;
