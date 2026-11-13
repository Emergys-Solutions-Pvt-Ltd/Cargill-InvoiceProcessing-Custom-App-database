-- GENERATED from common/invoices/templates/procedures/usp_invoice_create_batch.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- rospbu.usp_invoice_create_batch - ROSPBU "Create Invoice" (one row) and "Bulk Upload" (many rows)
-- Request:  p_module_id (a ROSPBU module), p_created_by (user id), p_invoices = JSON array whose
--           objects have the columns of rospbu.udt_invoice_input (row_no, invoice_code, ...)
-- Response: SETOF app.udt_code_result - the invoice codes created, in request order
-- Behaviour: all-or-nothing (a function runs inside the caller's transaction). Vendors missing
--           by CUIT and stations missing by "CCC - Station Name" are created; a station value
--           that does not follow that pattern is stored as no station.

--           Vendor name, CUIT and amount are required.

--           assigned_user_id ("Assign To") must be an active user with access to the application.
-- Errors:   CA400 empty request, missing fields, status not an active app.statuses code,
--                 duplicate codes in the request, invalid assignee,
--                 module of another app
--           CA404 unknown module
--           CA409 invoice code already exists in ROSPBU, or the module's daily
--                 max_invoices_limit (app.app_settings) would be exceeded
-- =====================================================================
CREATE OR REPLACE FUNCTION rospbu.usp_invoice_create_batch(
    p_module_id     uuid,
    p_created_by    uuid,
    p_invoices      jsonb
)
RETURNS SETOF app.udt_code_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_msg           text;
    v_count         integer;
    v_limit         integer;
    v_created_today integer;
    v_app_id        uuid;
    v_schema        text;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_rospbu_invoice_input OF rospbu.udt_invoice_input ON COMMIT DROP;
    TRUNCATE tmp_rospbu_invoice_input;
    INSERT INTO tmp_rospbu_invoice_input
    SELECT * FROM jsonb_populate_recordset(NULL::rospbu.udt_invoice_input, coalesce(p_invoices, '[]'::jsonb));
    UPDATE tmp_rospbu_invoice_input SET status = coalesce(status, 'Pending');

    SELECT count(*) INTO v_count FROM tmp_rospbu_invoice_input;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'At least one invoice is required.' USING ERRCODE = 'CA400';
    END IF;

    SELECT m.application_id, a.db_schema INTO v_app_id, v_schema
    FROM app.app_modules m JOIN app.applications a ON a.id = m.application_id
    WHERE m.id = p_module_id AND m.is_active;
    IF v_app_id IS NULL THEN
        RAISE EXCEPTION 'Application module not found.' USING ERRCODE = 'CA404';
    END IF;
    IF v_schema IS DISTINCT FROM 'rospbu' THEN
        RAISE EXCEPTION 'The module does not belong to ROSPBU.' USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg('row ' || coalesce(row_no::text, '?'), ', ') INTO v_msg
    FROM tmp_rospbu_invoice_input
    WHERE row_no IS NULL OR invoice_code IS NULL OR vendor_name IS NULL OR cuit IS NULL
       OR amount IS NULL OR reception_date IS NULL;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required invoice fields (%).', v_msg USING ERRCODE = 'CA400';
    END IF;

    -- Statuses come from Settings > Configuration (app.statuses); match codes case-insensitively
    UPDATE tmp_rospbu_invoice_input r SET status = s.code
    FROM app.statuses s
    WHERE lower(s.code) = lower(r.status) AND s.is_active;

    SELECT string_agg('row ' || row_no || ': ' || status, ', ') INTO v_msg
    FROM tmp_rospbu_invoice_input r
    WHERE NOT EXISTS (SELECT 1 FROM app.statuses s WHERE s.code = r.status AND s.is_active);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid status (%). Allowed: %', v_msg,
            (SELECT string_agg(code, ', ' ORDER BY sort_order) FROM app.statuses WHERE is_active)
            USING ERRCODE = 'CA400';
    END IF;

    -- "Assign To": same rule as Invoice Details (active, Admin or has access to the application)
    SELECT string_agg('row ' || row_no, ', ') INTO v_msg
    FROM tmp_rospbu_invoice_input r
    WHERE r.assigned_user_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM app_auth.users u
        WHERE u.id = r.assigned_user_id AND u.status = 'Active'
          AND (u.role = 'Admin' OR EXISTS (SELECT 1 FROM app_auth.user_applications ua
                                           WHERE ua.user_id = u.id AND ua.application_id = v_app_id)));
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'The assigned user must be active and have access to this application (%).', v_msg
            USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(invoice_code, ', ') INTO v_msg
    FROM (SELECT invoice_code FROM tmp_rospbu_invoice_input GROUP BY invoice_code HAVING count(*) > 1) d;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate invoice ids in request: %', v_msg USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(i.invoice_code, ', ') INTO v_msg
    FROM rospbu.rospbu_invoices i JOIN tmp_rospbu_invoice_input r ON r.invoice_code = i.invoice_code;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invoice id(s) already exist: %', v_msg USING ERRCODE = 'CA409';
    END IF;

    -- Daily limit, with the module's settings row locked so concurrent batches serialise
    SELECT max_invoices_limit INTO v_limit FROM app.app_settings WHERE module_id = p_module_id FOR UPDATE;
    v_limit := coalesce(v_limit, 100);
    SELECT count(*) INTO v_created_today
    FROM rospbu.rospbu_invoices
    WHERE module_id = p_module_id AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
    IF v_created_today + v_count > v_limit THEN
        RAISE EXCEPTION 'Daily invoice limit of % would be exceeded (% already created today)', v_limit, v_created_today
            USING ERRCODE = 'CA409';
    END IF;

    -- Vendors by CUIT (first name in the request wins for new vendors)
    INSERT INTO app.vendors (legal_name, cuit)
    SELECT DISTINCT ON (cuit) vendor_name, cuit
    FROM tmp_rospbu_invoice_input
    WHERE cuit IS NOT NULL
    ORDER BY cuit, row_no
    ON CONFLICT (cuit) DO NOTHING;

    -- Stations parsed from "CCC - Station Name"
    INSERT INTO app.country_stations (country_code, station_name)
    SELECT DISTINCT upper(p.parts[1]), p.parts[2]
    FROM tmp_rospbu_invoice_input r
    CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
    WHERE p.parts IS NOT NULL
    ON CONFLICT (country_code, station_name) DO NOTHING;

    INSERT INTO rospbu.rospbu_invoices
        (invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a,
         amount, invoice_subtotal, status, reception_date, email_reception_date, assigned_user_id, created_by)
    SELECT r.invoice_code, p_module_id, v.id, cs.id, r.invoice_1a, r.invoice_2a,
           r.amount, r.amount, r.status, r.reception_date, r.email_reception_date, r.assigned_user_id, p_created_by
    FROM tmp_rospbu_invoice_input r

    LEFT JOIN app.vendors v ON v.cuit = r.cuit
    CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
    LEFT JOIN app.country_stations cs ON cs.country_code = upper(p.parts[1]) AND cs.station_name = p.parts[2]
    ORDER BY r.row_no;

    RETURN QUERY
    SELECT r.invoice_code::varchar(60)
    FROM tmp_rospbu_invoice_input r
    ORDER BY r.row_no;
END;
$$;
