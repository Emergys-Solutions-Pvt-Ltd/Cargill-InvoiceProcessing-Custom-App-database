-- =====================================================================
-- sjo.erp_systems - Configuration > ERP systems (master data), e.g. JDE, SAP
-- The ERP an SJO invoice is posted to (sjo.invoice_sjo_fields.erp_system_id).
-- Shares the master-data column set (code, name, description, sort_order, is_active)
-- managed generically by app.usp_master_data_* (registered below).
-- Depends on: app.master_data_entities
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
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

INSERT INTO app.master_data_entities
    (entity, schema_name, table_name, label, parent_entity, parent_column, code_required, has_color, sort_order)
VALUES
    ('erp-systems', 'sjo', 'erp_systems', 'ERP system', NULL, NULL, true, false, 80)
ON CONFLICT (entity) DO UPDATE
    SET schema_name   = EXCLUDED.schema_name,
        table_name    = EXCLUDED.table_name,
        label         = EXCLUDED.label,
        code_required = EXCLUDED.code_required,
        sort_order    = EXCLUDED.sort_order;

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
