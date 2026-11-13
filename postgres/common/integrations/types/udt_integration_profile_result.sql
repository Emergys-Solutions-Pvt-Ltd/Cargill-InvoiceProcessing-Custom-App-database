-- =====================================================================
-- app.udt_integration_profile_result - RESPONSE type: an extraction profile with its target module
-- Element of udt_integration_result.profiles (JSON array).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_integration_profile_result AS (
    id                      uuid,
    integration_id          uuid,
    module_id               uuid,
    module_slug             text,
    module_name             text,
    application_code        text,
    invoice_prefix          text,
    name                    text,
    is_active               boolean,
    settings                jsonb,
    key_fields              jsonb,
    invoice_code_template   text,
    field_mapping           jsonb,
    cancellation_rule       jsonb,
    default_status          text,
    initial_from            timestamptz,
    watermark               timestamptz,
    watermark_updated_at    timestamptz,
    sort_order              integer
);
