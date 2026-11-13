-- =====================================================================
-- app.udt_integration_profile_input - REQUEST type: one extraction profile of an integration (create or update)
-- Used by: usp_integration_save(p_profiles jsonb) via jsonb_populate_recordset; id NULL = new profile.
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_integration_profile_input AS (
    id                      uuid,
    module_id               uuid,
    name                    text,
    is_active               boolean,
    settings                jsonb,
    key_fields              jsonb,
    invoice_code_template   text,
    field_mapping           jsonb,
    cancellation_rule       jsonb,
    default_status          text,
    initial_from            timestamptz,
    sort_order              integer
);
