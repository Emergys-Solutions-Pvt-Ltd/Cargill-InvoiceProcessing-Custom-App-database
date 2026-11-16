-- =====================================================================
-- sjo.udt_invoice_sjo_fields_result - RESPONSE type: SJO Invoice Processing fields
-- Element of udt_invoice_list_result.sjo_fields and udt_invoice_detail_result.sjo_fields
-- (NULL when the invoice has no sjo.invoice_sjo_fields row, e.g. GP / ROSPBU invoices).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE sjo.udt_invoice_sjo_fields_result AS (
    country_id          uuid,
    country_code        varchar(30),
    country_name        varchar(150),
    business_unit_id    uuid,
    business_unit_code  varchar(30),
    business_unit_name  varchar(150),
    erp_system_id       uuid,
    erp_system_code     varchar(30),
    erp_system_name     varchar(150),
    id_fiscal           varchar(30),
    ab_number           varchar(30),
    ab_name             varchar(255),
    flow_turn_down      boolean,
    critical_vendor     boolean,
    urgent_invoice      boolean,
    updated_at          timestamptz(0)
);
