-- =====================================================================
-- app.usp_app_module_get_by_slug - resolves a UI route slug (/app/:appId) to its module
-- and parent application; used for every /apps/:appId route access check.
-- Request:  p_slug, e.g. 'gp-tool'
-- Response: SETOF app.udt_app_module_result (no rows when the slug is unknown or inactive)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_app_module_get_by_slug(p_slug text)
RETURNS SETOF app.udt_app_module_result
LANGUAGE sql
STABLE
AS $$
    SELECT m.id, m.slug, m.name, m.invoice_prefix, a.id, a.code
    FROM app.app_modules m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.slug = p_slug AND m.is_active AND a.is_active;
$$;
