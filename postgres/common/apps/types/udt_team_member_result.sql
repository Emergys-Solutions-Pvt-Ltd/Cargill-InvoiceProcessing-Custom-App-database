-- =====================================================================
-- app.udt_team_member_result - RESPONSE type: Admin Configuration team access row
-- Returned by: usp_team_member_add
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_team_member_result AS (
    id       integer,
    name     varchar(200),
    email    varchar(255),
    alias    varchar(100),
    team     varchar(150)
);
