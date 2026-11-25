-- =====================================================================
-- app_auth.users - platform users (Login, Settings / User Access Management)
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app_auth.users (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_users PRIMARY KEY,
    username        varchar(150)    NOT NULL,                       -- short login alias, e.g. "admin"
    email           varchar(255)    NOT NULL,
    name            varchar(200)    NOT NULL,
    role            varchar(20)     NOT NULL DEFAULT 'User',
    status          varchar(20)     NOT NULL DEFAULT 'Active',
    auth_provider   varchar(20)     NOT NULL DEFAULT 'LOCAL',
    password_hash   varchar(255)    NULL,                           -- NULL for Azure AD users
    last_login_at   timestamptz(0)  NULL,
    created_at      timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at      timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_role   CHECK (role IN ('Admin', 'User')),
    CONSTRAINT ck_users_status CHECK (status IN ('Active', 'Suspended')),
    CONSTRAINT ck_users_auth   CHECK (auth_provider IN ('LOCAL', 'AD'))
);

-- Case-insensitive uniqueness (emails / usernames are compared with lower())
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email    ON app_auth.users (lower(email));
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username ON app_auth.users (lower(username));
