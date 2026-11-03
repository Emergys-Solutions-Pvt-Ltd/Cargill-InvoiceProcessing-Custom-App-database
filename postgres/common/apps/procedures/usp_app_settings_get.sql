-- =====================================================================
-- app.usp_app_settings_get - Admin Configuration settings for one module
-- Request:  p_module_id
-- Response: app.udt_app_settings_result - always one row; defaults
--           (notifications on, limit 100) when the module has no settings row yet
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_app_settings_get(p_module_id integer)
RETURNS app.udt_app_settings_result
LANGUAGE sql
STABLE
AS $$
    SELECT p_module_id,
           coalesce(s.enable_notifications, true),
           coalesce(s.max_invoices_limit, 100),
           s.updated_at
    FROM (SELECT 1) x
    LEFT JOIN app.app_settings s ON s.module_id = p_module_id;
$$;
