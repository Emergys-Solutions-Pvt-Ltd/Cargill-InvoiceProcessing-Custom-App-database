-- =====================================================================
-- app.master_data_entities - registry of the Configuration (master data) entities.
-- app.usp_master_data_* build their SQL from this table, so it doubles as the
-- whitelist of tables those functions may touch. System data: postdeploy/30_master_data_entities.sql.
-- Depends on: the master data tables (05, 14-19)
-- Idempotent. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.master_data_entities (
    entity          varchar(40)     NOT NULL CONSTRAINT pk_master_data_entities PRIMARY KEY,  -- API name, e.g. business-units
    table_name      varchar(63)     NOT NULL CONSTRAINT uq_master_data_entities_table UNIQUE,
    label           varchar(60)     NOT NULL,                   -- singular, used in messages
    parent_entity   varchar(40)     NULL CONSTRAINT fk_master_data_entities_parent REFERENCES app.master_data_entities (entity),
    parent_column   varchar(63)     NULL,
    code_required   boolean         NOT NULL DEFAULT false,
    has_color       boolean         NOT NULL DEFAULT false,
    sort_order      integer         NOT NULL DEFAULT 0,
    schema_name     varchar(63)     NOT NULL DEFAULT 'app',    -- module schema of the table (app = common; erp-systems: sjo)
    CONSTRAINT ck_master_data_entities_parent CHECK ((parent_entity IS NULL) = (parent_column IS NULL))
);
