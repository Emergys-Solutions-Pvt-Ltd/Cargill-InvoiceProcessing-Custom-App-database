-- =====================================================================
-- app.udt_line_item_result - RESPONSE type: Invoice Overview line item
-- Element type of udt_invoice_detail_result.line_items
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_line_item_result AS (
    line_no              integer,
    code                 varchar(50),
    description          varchar(500),
    quantity             numeric(18,3),
    unit_of_measure      varchar(30),
    unit_price           numeric(18,2),
    discount             numeric(18,2),
    subtotal             numeric(18,2),
    vat_rate             numeric(5,2),
    subtotal_with_vat    numeric(18,2)
);
