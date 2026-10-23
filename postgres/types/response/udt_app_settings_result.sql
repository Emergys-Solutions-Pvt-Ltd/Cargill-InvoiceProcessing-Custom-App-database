-- =====================================================================
-- app.udt_app_settings_result - RESPONSE type: Admin Configuration settings for one module
-- Returned by: usp_app_settings_get, usp_app_settings_save
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_app_settings_result AS (
    module_id               integer,
    enable_notifications    boolean,
    max_invoices_limit      integer,
    updated_at              timestamptz(0)
);
