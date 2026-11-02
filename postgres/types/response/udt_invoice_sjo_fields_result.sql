-- =====================================================================
-- app.udt_invoice_sjo_fields_result - RESPONSE type: SJO Invoice Processing fields
-- Element of udt_invoice_list_result.sjo_fields and udt_invoice_detail_result.sjo_fields
-- (NULL when the invoice has no app.invoice_sjo_fields row, e.g. GP / ROSPBU invoices).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_sjo_fields_result AS (
    country_id          integer,
    country_code        varchar(30),
    country_name        varchar(150),
    business_unit_id    integer,
    business_unit_code  varchar(30),
    business_unit_name  varchar(150),
    erp_system_id       integer,
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
