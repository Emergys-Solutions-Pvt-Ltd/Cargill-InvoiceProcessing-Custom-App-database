-- =====================================================================
-- app.master_data_entities - registry of the Configuration (master data) entities.
-- app.usp_master_data_* build their SQL from this table, so it doubles as the
-- whitelist of tables those functions may touch. System data: kept in sync here.
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
    CONSTRAINT ck_master_data_entities_parent CHECK ((parent_entity IS NULL) = (parent_column IS NULL))
);

INSERT INTO app.master_data_entities
    (entity, table_name, label, parent_entity, parent_column, code_required, has_color, sort_order)
VALUES
    ('countries',      'countries',      'Country',       NULL,        NULL,         true,  false, 10),
    ('states',         'states',         'State',         'countries', 'country_id', false, false, 20),
    ('cities',         'cities',         'City',          'states',    'state_id',   false, false, 30),
    ('business-units', 'business_units', 'Business unit', NULL,        NULL,         true,  false, 40),
    ('teams',          'teams',          'Team',          NULL,        NULL,         false, false, 50),
    ('statuses',       'statuses',       'Status',        NULL,        NULL,         true,  true,  60),
    ('processes',      'processes',      'Process',       NULL,        NULL,         true,  false, 70)
ON CONFLICT (entity) DO UPDATE
    SET table_name    = EXCLUDED.table_name,
        label         = EXCLUDED.label,
        parent_entity = EXCLUDED.parent_entity,
        parent_column = EXCLUDED.parent_column,
        code_required = EXCLUDED.code_required,
        has_color     = EXCLUDED.has_color,
        sort_order    = EXCLUDED.sort_order;

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
