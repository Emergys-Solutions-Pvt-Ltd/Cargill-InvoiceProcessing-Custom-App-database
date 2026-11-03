-- =====================================================================
-- app.udt_vendor_result - RESPONSE type: vendor dropdown entry
-- Element type of udt_lookups_result.vendors
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_vendor_result AS (
    id            integer,
    legal_name    varchar(255),
    cuit          varchar(20)
);
