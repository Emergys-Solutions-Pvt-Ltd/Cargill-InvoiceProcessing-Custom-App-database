-- =====================================================================
-- app.udt_user_list_result - RESPONSE type: one page of users plus paging metadata
-- Returned by: usp_user_list. Paging columns repeat on every row; no rows = no matches.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_user_list_result AS (
    id               integer,
    username         varchar(150),
    name             varchar(200),
    email            varchar(255),
    role             varchar(20),
    status           varchar(20),
    auth_provider    varchar(20),
    assigned_apps    text,                 -- comma separated application codes, e.g. "GP,sjo"
    total_items      integer,
    total_pages      integer,
    page             integer,
    page_size        integer
);
