-- =====================================================================
-- sjo.erp_systems - Configuration > ERP systems (master data), e.g. JDE, SAP
-- The ERP an SJO invoice is posted to (sjo.invoice_sjo_fields.erp_system_id).
-- Shares the master-data column set (code, name, description, sort_order, is_active)
-- managed generically by app.usp_master_data_* (registered in postdeploy/30_master_data_entities.sql).
-- Depends on: app.master_data_entities
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS sjo.erp_systems (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_erp_systems PRIMARY KEY,
    code        varchar(30)     NOT NULL,                       -- e.g. JDE
    name        varchar(150)    NOT NULL,
    description varchar(500)    NULL,
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_erp_systems_code ON sjo.erp_systems (lower(code));
CREATE UNIQUE INDEX IF NOT EXISTS uq_erp_systems_name ON sjo.erp_systems (lower(name));
