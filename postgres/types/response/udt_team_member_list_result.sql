-- =====================================================================
-- app.udt_team_member_list_result - RESPONSE type: one page of team members plus paging metadata
-- Returned by: usp_team_member_list. Paging columns repeat on every row; no rows = no matches.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_team_member_list_result AS (
    id             integer,
    name           varchar(200),
    email          varchar(255),
    alias          varchar(100),
    team           varchar(150),
    total_items    integer,
    total_pages    integer,
    page           integer,
    page_size      integer
);
