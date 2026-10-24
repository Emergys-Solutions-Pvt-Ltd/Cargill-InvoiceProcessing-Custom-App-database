-- =====================================================================
-- app.ufn_integration_row - builds app.udt_integration_result for one integration
-- (profiles as a JSON array of udt_integration_profile_result, ordered for display).
-- secret_ciphertext is never part of the result: only secret_configured / secret_updated_at.
-- Shared by usp_integration_list / _get / _save / _due_list so the shape is defined once.
-- Returns NULL when the integration does not exist.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_integration_row(p_integration_id integer)
RETURNS app.udt_integration_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(
        i.id, i.provider_type, i.name, i.description, i.environment, i.source_system, i.is_active,
        i.connection, i.auth_type, i.auth_settings, i.secret_ciphertext IS NOT NULL, i.secret_updated_at,
        i.schedule, i.auto_sync_enabled, i.retry_policy, i.next_run_at, i.last_attempt_at, i.last_success_at,
        i.last_status, i.last_job_id, i.version,
        coalesce((
            SELECT jsonb_agg(to_jsonb(ROW(
                       p.id, p.integration_id, p.module_id, m.slug, m.name, a.code, m.invoice_prefix, p.name,
                       p.is_active, p.settings, p.key_fields, p.invoice_code_template, p.field_mapping,
                       p.cancellation_rule, p.default_status, p.initial_from, p.watermark,
                       p.watermark_updated_at, p.sort_order
                   )::app.udt_integration_profile_result) ORDER BY p.sort_order, p.id)
            FROM app.integration_profiles p
            JOIN app.app_modules m  ON m.id = p.module_id
            JOIN app.applications a ON a.id = m.application_id
            WHERE p.integration_id = i.id
        ), '[]'::jsonb),
        i.created_at, i.updated_at, u.name
    )::app.udt_integration_result
    FROM app.integrations i
    LEFT JOIN app.users u ON u.id = i.updated_by
    WHERE i.id = p_integration_id;
$$;
