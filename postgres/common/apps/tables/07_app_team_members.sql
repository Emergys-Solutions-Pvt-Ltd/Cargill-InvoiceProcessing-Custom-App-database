-- =====================================================================
-- app.app_team_members - team access list per module (Admin Configuration)
-- Depends on: app.app_modules, app.teams, app_auth.users
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.app_team_members (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_app_team_members PRIMARY KEY,
    module_id   uuid         NOT NULL CONSTRAINT fk_team_members_module REFERENCES app.app_modules (id) ON DELETE CASCADE,
    team_id     uuid         NOT NULL CONSTRAINT fk_team_members_team   REFERENCES app.teams (id),
    user_id     uuid         NULL     CONSTRAINT fk_team_members_user   REFERENCES app_auth.users (id),
    name        varchar(200)    NOT NULL,
    email       varchar(255)    NOT NULL,
    alias       varchar(100)    NOT NULL,
    created_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_team_members ON app.app_team_members (module_id, lower(email));
