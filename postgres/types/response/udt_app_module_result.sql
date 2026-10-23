-- =====================================================================
-- app.udt_app_module_result - RESPONSE type: route slug resolved to its module and application
-- Returned by: usp_app_module_get_by_slug
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_app_module_result AS (
    module_id           integer,
    slug                varchar(100),
    name                varchar(150),
    invoice_prefix      varchar(30),
    application_id      integer,
    application_code    varchar(50)
);
