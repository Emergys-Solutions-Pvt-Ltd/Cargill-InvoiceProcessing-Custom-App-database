-- =====================================================================
-- app.udt_integration_result - RESPONSE type: an integration (never the secret itself)
-- Returned by: usp_integration_list / _get / _save / _due_list (built by ufn_integration_row).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_integration_result AS (
    id                  uuid,
    provider_type       text,
    name                text,
    description         text,
    environment         text,
    source_system       text,
    is_active           boolean,
    connection          jsonb,
    auth_type           text,
    auth_settings       jsonb,
    secret_configured   boolean,
    secret_updated_at   timestamptz,
    schedule            jsonb,
    auto_sync_enabled   boolean,
    retry_policy        jsonb,
    next_run_at         timestamptz,
    last_attempt_at     timestamptz,
    last_success_at     timestamptz,
    last_status         text,
    last_job_id         uuid,
    version             integer,
    profiles            jsonb,          -- array of udt_integration_profile_result
    created_at          timestamptz,
    updated_at          timestamptz,
    updated_by_name     text
);
