-- =====================================================================
-- app.udt_user_result - RESPONSE type: user row (Settings / UAM, auth context)
-- Returned by: usp_user_get_by_id, usp_user_create, usp_user_update
-- Never contains the password hash (see udt_user_login_result).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_user_result AS (
    id               integer,
    username         varchar(150),
    name             varchar(200),
    email            varchar(255),
    role             varchar(20),
    status           varchar(20),
    auth_provider    varchar(20),
    assigned_apps    text                  -- comma separated application codes, e.g. "GP,sjo"
);
