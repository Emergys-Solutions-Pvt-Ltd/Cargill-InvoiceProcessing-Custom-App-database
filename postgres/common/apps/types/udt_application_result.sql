-- =====================================================================
-- app.udt_application_result - RESPONSE type: application tiles / menu
-- Returned by: usp_application_list
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_application_result AS (
    code           varchar(50),
    name           varchar(100),
    description    varchar(255)
);
