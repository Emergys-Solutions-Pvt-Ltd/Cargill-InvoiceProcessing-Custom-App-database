-- =====================================================================
-- app.udt_ccpp_result - RESPONSE type: CCPPs tab row
-- Element type of udt_invoice_detail_result.ccpps
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_ccpp_result AS (
    id                  integer,
    product             varchar(100),
    legal_doc_issuer    varchar(200),
    status              varchar(50),
    value               numeric(18,2),
    km                  numeric(10,2),
    tons                numeric(18,2),
    unit_rate           numeric(18,2),
    km_fc               numeric(10,2),
    tons_fc             numeric(18,2)
);
