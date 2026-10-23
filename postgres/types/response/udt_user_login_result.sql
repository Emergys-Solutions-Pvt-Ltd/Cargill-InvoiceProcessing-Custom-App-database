-- =====================================================================
-- app.udt_user_login_result - RESPONSE type: user plus password hash, for login only
-- Returned by: usp_user_get_for_login
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_user_login_result AS (
    id               integer,
    username         varchar(150),
    name             varchar(200),
    email            varchar(255),
    role             varchar(20),
    status           varchar(20),
    auth_provider    varchar(20),
    assigned_apps    text,                 -- comma separated application codes, e.g. "GP,sjo"
    password_hash    varchar(255)
);
