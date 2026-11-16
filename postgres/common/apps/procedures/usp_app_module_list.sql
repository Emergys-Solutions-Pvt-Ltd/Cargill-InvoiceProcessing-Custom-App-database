-- =====================================================================
-- app.usp_app_module_list - active app modules for "Target application" dropdowns
-- (Settings > Email Registration; GET /api/app-modules, admin only - D-015)
-- Request:  (none)
-- Response: SETOF app.udt_app_module_result, only active modules of active applications,
--           ordered by application, then module name
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_app_module_list()
RETURNS SETOF app.udt_app_module_result
LANGUAGE sql
STABLE
AS $$
    SELECT m.id, m.slug, m.name, m.invoice_prefix, a.id, a.code, a.db_schema
    FROM app.app_modules m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.is_active AND a.is_active
    ORDER BY a.id, lower(m.name), m.id;
$$;
