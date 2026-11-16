-- GENERATED from common/invoices/templates/procedures/usp_invoice_update_details.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.usp_invoice_update_details - SJO Invoice Details "Save" (Super User fields)
-- Request:  p_invoice_code and the editable fields; NULL clears a dropdown ("--None--").
--           p_process_id: an active app.processes id ("Change Process")
--           p_origin_city_id / p_destination_city_id: app.cities ids
--           p_assigned_user_id: an active user with access to the invoice's application
--           p_updated_by: the user saving (Last Modified By)
-- Response: app.udt_row_count_result
-- Errors:   CA400 unknown / inactive process, city or user, negative claim number
--           CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION sjo.usp_invoice_update_details(
    p_invoice_code          text,
    p_process_id            uuid DEFAULT NULL,
    p_origin_city_id        uuid DEFAULT NULL,
    p_destination_city_id   uuid DEFAULT NULL,
    p_claim_number          numeric DEFAULT 0,
    p_additional_info       text    DEFAULT NULL,
    p_assigned_user_id      uuid DEFAULT NULL,
    p_updated_by            uuid DEFAULT NULL
)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    uuid;
    v_app_id        uuid;
    v_rows          integer;
BEGIN
    SELECT i.id, m.application_id INTO v_invoice_id, v_app_id
    FROM sjo.sjo_invoices i JOIN app.app_modules m ON m.id = i.module_id
    WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    IF coalesce(p_claim_number, 0) < 0 THEN
        RAISE EXCEPTION 'Claim number cannot be negative.' USING ERRCODE = 'CA400';
    END IF;
    IF p_process_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app.processes WHERE id = p_process_id AND is_active) THEN
        RAISE EXCEPTION 'Selected process does not exist or is inactive.' USING ERRCODE = 'CA400';
    END IF;
    IF p_origin_city_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app.cities WHERE id = p_origin_city_id) THEN
        RAISE EXCEPTION 'Selected origin does not exist.' USING ERRCODE = 'CA400';
    END IF;
    IF p_destination_city_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app.cities WHERE id = p_destination_city_id) THEN
        RAISE EXCEPTION 'Selected destination does not exist.' USING ERRCODE = 'CA400';
    END IF;
    IF p_assigned_user_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM app_auth.users u
        WHERE u.id = p_assigned_user_id AND u.status = 'Active'
          AND (u.role = 'Admin' OR EXISTS (SELECT 1 FROM app_auth.user_applications ua
                                           WHERE ua.user_id = u.id AND ua.application_id = v_app_id))
    ) THEN
        RAISE EXCEPTION 'The assigned user must be active and have access to this application.' USING ERRCODE = 'CA400';
    END IF;

    UPDATE sjo.sjo_invoices
       SET process_id          = p_process_id,
           origin_city_id      = p_origin_city_id,
           destination_city_id = p_destination_city_id,
           claim_number        = coalesce(p_claim_number, 0),
           additional_info     = nullif(btrim(p_additional_info), ''),
           assigned_user_id    = p_assigned_user_id,
           updated_by          = coalesce(p_updated_by, updated_by),
           updated_at          = now()
     WHERE id = v_invoice_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    RETURN ROW(v_rows)::app.udt_row_count_result;
EXCEPTION
    WHEN string_data_right_truncation THEN
        RAISE EXCEPTION 'Additional info is too long (max 1000 characters).' USING ERRCODE = 'CA400';
END;
$$;
