-- =====================================================================
-- Post-deployment: app.master_data_entities - the registry (and whitelist) of the Configuration lists
-- that app.usp_master_data_* may touch. System data, kept in sync on every deployment (idempotent upsert).
-- =====================================================================
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

-- SJO module list (table in schema sjo)
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
