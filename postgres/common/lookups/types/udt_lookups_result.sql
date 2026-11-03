-- =====================================================================
-- app.udt_lookups_result - RESPONSE type: all dropdown sources in one row
-- Returned by: usp_lookup_get_all. JSON arrays of udt_vendor_result, udt_lookup_value_result
-- (stations, teams) and udt_master_data_option_result (statuses: code + name + color).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_lookups_result AS (
    vendors     jsonb,
    stations    jsonb,
    teams       jsonb,
    statuses    jsonb
);
