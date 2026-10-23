-- =====================================================================
-- app.usp_app_settings_save - Admin Configuration "Save Changes" (upsert)
-- Request:  p_module_id, p_updated_by (user id); NULL p_enable_notifications /
--           p_max_invoices_limit keep the current (or default) value
-- Response: app.udt_app_settings_result (the saved settings)
-- Errors:   CA400 negative limit, CA404 unknown module
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_app_settings_save(
    p_module_id             integer,
    p_enable_notifications  boolean DEFAULT NULL,
    p_max_invoices_limit    integer DEFAULT NULL,
    p_updated_by            integer DEFAULT NULL
)
RETURNS app.udt_app_settings_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_result app.udt_app_settings_result;
BEGIN
    IF p_max_invoices_limit < 0 THEN
        RAISE EXCEPTION 'MaxInvoicesLimit cannot be negative.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.app_modules WHERE id = p_module_id) THEN
        RAISE EXCEPTION 'Application module not found.' USING ERRCODE = 'CA404';
    END IF;

    INSERT INTO app.app_settings AS t (module_id, enable_notifications, max_invoices_limit, updated_by)
    VALUES (p_module_id, coalesce(p_enable_notifications, true), coalesce(p_max_invoices_limit, 100), p_updated_by)
    ON CONFLICT (module_id) DO UPDATE
        SET enable_notifications = coalesce(p_enable_notifications, t.enable_notifications),
            max_invoices_limit   = coalesce(p_max_invoices_limit, t.max_invoices_limit),
            updated_by           = p_updated_by,
            updated_at           = now()
    RETURNING t.module_id, t.enable_notifications, t.max_invoices_limit, t.updated_at
    INTO v_result;

    RETURN v_result;
END;
$$;
