-- =====================================================================
-- app.usp_invoice_create_batch - "Create Invoice" (one row) and "Bulk Upload" (many rows)
-- Request:  p_module_id, p_created_by (user id), p_invoices = JSON array whose objects have
--           the columns of app.udt_invoice_input (row_no, invoice_code, vendor_name, cuit, ...)
-- Response: SETOF app.udt_code_result - the invoice codes created, in request order
-- Behaviour: all-or-nothing (a function runs inside the caller's transaction). Vendors missing
--           by CUIT and stations missing by "CCC - Station Name" are created; a station value
--           that does not follow that pattern is stored as no station.
-- Errors:   CA400 empty request, missing fields, status not an active app.statuses code,
--                 duplicate codes in the request
--           CA404 unknown module
--           CA409 invoice code already exists, or the module's daily
--                 max_invoices_limit (app.app_settings) would be exceeded
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_create_batch(
    p_module_id     integer,
    p_created_by    integer,
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
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_invoice_input OF app.udt_invoice_input ON COMMIT DROP;
    TRUNCATE tmp_invoice_input;
    INSERT INTO tmp_invoice_input
    SELECT * FROM jsonb_populate_recordset(NULL::app.udt_invoice_input, coalesce(p_invoices, '[]'::jsonb));
    UPDATE tmp_invoice_input SET status = coalesce(status, 'Pending');

    SELECT count(*) INTO v_count FROM tmp_invoice_input;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'At least one invoice is required.' USING ERRCODE = 'CA400';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM app.app_modules WHERE id = p_module_id AND is_active) THEN
        RAISE EXCEPTION 'Application module not found.' USING ERRCODE = 'CA404';
    END IF;

    SELECT string_agg('row ' || coalesce(row_no::text, '?'), ', ') INTO v_msg
    FROM tmp_invoice_input
    WHERE row_no IS NULL OR invoice_code IS NULL OR vendor_name IS NULL OR cuit IS NULL
       OR amount IS NULL OR reception_date IS NULL;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required invoice fields (%).', v_msg USING ERRCODE = 'CA400';
    END IF;

    -- Statuses come from Settings > Configuration (app.statuses); match codes case-insensitively
    UPDATE tmp_invoice_input r SET status = s.code
    FROM app.statuses s
    WHERE lower(s.code) = lower(r.status) AND s.is_active;

    SELECT string_agg('row ' || row_no || ': ' || status, ', ') INTO v_msg
    FROM tmp_invoice_input r
    WHERE NOT EXISTS (SELECT 1 FROM app.statuses s WHERE s.code = r.status AND s.is_active);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid status (%). Allowed: %', v_msg,
            (SELECT string_agg(code, ', ' ORDER BY sort_order) FROM app.statuses WHERE is_active)
            USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(invoice_code, ', ') INTO v_msg
    FROM (SELECT invoice_code FROM tmp_invoice_input GROUP BY invoice_code HAVING count(*) > 1) d;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate invoice ids in request: %', v_msg USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(i.invoice_code, ', ') INTO v_msg
    FROM app.invoices i JOIN tmp_invoice_input r ON r.invoice_code = i.invoice_code;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invoice id(s) already exist: %', v_msg USING ERRCODE = 'CA409';
    END IF;

    -- Daily limit, with the module's settings row locked so concurrent batches serialise
    SELECT max_invoices_limit INTO v_limit FROM app.app_settings WHERE module_id = p_module_id FOR UPDATE;
    v_limit := coalesce(v_limit, 100);
    SELECT count(*) INTO v_created_today
    FROM app.invoices
    WHERE module_id = p_module_id AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
    IF v_created_today + v_count > v_limit THEN
        RAISE EXCEPTION 'Daily invoice limit of % would be exceeded (% already created today)', v_limit, v_created_today
            USING ERRCODE = 'CA409';
    END IF;

    -- Vendors by CUIT (first name in the request wins for new vendors)
    INSERT INTO app.vendors (legal_name, cuit)
    SELECT DISTINCT ON (cuit) vendor_name, cuit
    FROM tmp_invoice_input
    ORDER BY cuit, row_no
    ON CONFLICT (cuit) DO NOTHING;

    -- Stations parsed from "CCC - Station Name"
    INSERT INTO app.country_stations (country_code, station_name)
    SELECT DISTINCT upper(p.parts[1]), p.parts[2]
    FROM tmp_invoice_input r
    CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
    WHERE p.parts IS NOT NULL
    ON CONFLICT (country_code, station_name) DO NOTHING;

    RETURN QUERY
    WITH inserted AS (
        INSERT INTO app.invoices
            (invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a,
             amount, invoice_subtotal, status, reception_date, email_reception_date, created_by)
        SELECT r.invoice_code, p_module_id, v.id, cs.id, r.invoice_1a, r.invoice_2a,
               r.amount, r.amount, r.status, r.reception_date, r.email_reception_date, p_created_by
        FROM tmp_invoice_input r
        JOIN app.vendors v ON v.cuit = r.cuit
        CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
        LEFT JOIN app.country_stations cs ON cs.country_code = upper(p.parts[1]) AND cs.station_name = p.parts[2]
        RETURNING invoice_code
    )
    SELECT ins.invoice_code::varchar(60)
    FROM inserted ins
    JOIN tmp_invoice_input r ON r.invoice_code = ins.invoice_code
    ORDER BY r.row_no;
END;
$$;
