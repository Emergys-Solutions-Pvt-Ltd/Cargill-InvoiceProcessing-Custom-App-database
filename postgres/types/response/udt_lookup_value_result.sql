-- =====================================================================
-- app.udt_lookup_value_result - RESPONSE type: a named dropdown value (teams, stations)
-- Returned by: usp_team_list; element type of udt_lookups_result.stations / .teams
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_lookup_value_result AS (
    name          varchar(160),
    sort_order    integer
);
