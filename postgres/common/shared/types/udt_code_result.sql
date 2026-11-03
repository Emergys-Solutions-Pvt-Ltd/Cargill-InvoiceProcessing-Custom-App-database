-- =====================================================================
-- app.udt_code_result - RESPONSE type: a code (invoice codes created by usp_invoice_create_batch)
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_code_result AS (
    code    varchar(60)
);
