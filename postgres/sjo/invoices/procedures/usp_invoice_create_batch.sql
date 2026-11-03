-- GENERATED from common/invoices/templates/procedures/usp_invoice_create_batch.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.usp_invoice_create_batch - SJO "Create Invoice" (one row) and "Bulk Upload" (many rows)
-- Request:  p_module_id (a SJO module), p_created_by (user id), p_invoices = JSON array whose
--           objects have the columns of sjo.udt_invoice_input (row_no, invoice_code, ...)
-- Response: SETOF app.udt_code_result - the invoice codes created, in request order
-- Behaviour: all-or-nothing (a function runs inside the caller's transaction). Vendors missing
--           by CUIT and stations missing by "CCC - Station Name" are created; a station value
--           that does not follow that pattern is stored as no station.

--           SJO: vendor / CUIT / amount are optional (amount defaults to 0); country, BU and ERP
--           (code or name of an active Configuration item) and ID Fiscal are required.

--           assigned_user_id ("Assign To") must be an active user with access to the application.
-- Errors:   CA400 empty request, missing fields, status not an active app.statuses code,
--                 duplicate codes in the request, unknown country / BU / ERP, invalid assignee,
--                 module of another app
--           CA404 unknown module
--           CA409 invoice code already exists in SJO, or the module's daily
--                 max_invoices_limit (app.app_settings) would be exceeded
-- =====================================================================
CREATE OR REPLACE FUNCTION sjo.usp_invoice_create_batch(
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
    v_app_id        integer;
    v_schema        text;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_sjo_invoice_input OF sjo.udt_invoice_input ON COMMIT DROP;
    TRUNCATE tmp_sjo_invoice_input;
    INSERT INTO tmp_sjo_invoice_input
    SELECT * FROM jsonb_populate_recordset(NULL::sjo.udt_invoice_input, coalesce(p_invoices, '[]'::jsonb));
    UPDATE tmp_sjo_invoice_input SET status = coalesce(status, 'Pending');

    SELECT count(*) INTO v_count FROM tmp_sjo_invoice_input;
    IF v_count = 0 THEN
        RAISE EXCEPTION 'At least one invoice is required.' USING ERRCODE = 'CA400';
    END IF;

    SELECT m.application_id, a.db_schema INTO v_app_id, v_schema
    FROM app.app_modules m JOIN app.applications a ON a.id = m.application_id
    WHERE m.id = p_module_id AND m.is_active;
    IF v_app_id IS NULL THEN
        RAISE EXCEPTION 'Application module not found.' USING ERRCODE = 'CA404';
    END IF;
    IF v_schema IS DISTINCT FROM 'sjo' THEN
        RAISE EXCEPTION 'The module does not belong to SJO.' USING ERRCODE = 'CA400';
    END IF;

    UPDATE tmp_sjo_invoice_input SET amount = coalesce(amount, 0), id_fiscal = nullif(btrim(id_fiscal), '');
    SELECT string_agg('row ' || coalesce(row_no::text, '?'), ', ') INTO v_msg
    FROM tmp_sjo_invoice_input
    WHERE row_no IS NULL OR invoice_code IS NULL OR reception_date IS NULL
       OR sjo_country IS NULL OR sjo_business_unit IS NULL OR sjo_erp IS NULL OR id_fiscal IS NULL;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Missing required invoice fields: Country, BU, ERP and ID Fiscal (%).', v_msg USING ERRCODE = 'CA400';
    END IF;
    -- vendor and CUIT go together: a CUIT without a vendor name cannot create the vendor
    SELECT string_agg('row ' || row_no, ', ') INTO v_msg
    FROM tmp_sjo_invoice_input WHERE (vendor_name IS NULL) <> (cuit IS NULL);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Vendor name and CUIT must be given together (%).', v_msg USING ERRCODE = 'CA400';
    END IF;

    -- Statuses come from Settings > Configuration (app.statuses); match codes case-insensitively
    UPDATE tmp_sjo_invoice_input r SET status = s.code
    FROM app.statuses s
    WHERE lower(s.code) = lower(r.status) AND s.is_active;

    SELECT string_agg('row ' || row_no || ': ' || status, ', ') INTO v_msg
    FROM tmp_sjo_invoice_input r
    WHERE NOT EXISTS (SELECT 1 FROM app.statuses s WHERE s.code = r.status AND s.is_active);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invalid status (%). Allowed: %', v_msg,
            (SELECT string_agg(code, ', ' ORDER BY sort_order) FROM app.statuses WHERE is_active)
            USING ERRCODE = 'CA400';
    END IF;

    -- "Assign To": same rule as Invoice Details (active, Admin or has access to the application)
    SELECT string_agg('row ' || row_no, ', ') INTO v_msg
    FROM tmp_sjo_invoice_input r
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
    FROM (SELECT invoice_code FROM tmp_sjo_invoice_input GROUP BY invoice_code HAVING count(*) > 1) d;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Duplicate invoice ids in request: %', v_msg USING ERRCODE = 'CA400';
    END IF;

    -- SJO lists: country / BU / ERP by code or name (active items only)
    CREATE TEMP TABLE IF NOT EXISTS tmp_sjo_invoice_refs (
        row_no integer PRIMARY KEY, country_id integer, business_unit_id integer, erp_system_id integer
    ) ON COMMIT DROP;
    TRUNCATE tmp_sjo_invoice_refs;
    INSERT INTO tmp_sjo_invoice_refs
    SELECT r.row_no,
           (SELECT c.id FROM app.countries c WHERE c.is_active
              AND (lower(c.code) = lower(btrim(r.sjo_country)) OR lower(c.name) = lower(btrim(r.sjo_country)))
            ORDER BY (lower(c.code) = lower(btrim(r.sjo_country))) DESC LIMIT 1),
           (SELECT b.id FROM app.business_units b WHERE b.is_active
              AND (lower(b.code) = lower(btrim(r.sjo_business_unit)) OR lower(b.name) = lower(btrim(r.sjo_business_unit)))
            ORDER BY (lower(b.code) = lower(btrim(r.sjo_business_unit))) DESC LIMIT 1),
           (SELECT e.id FROM sjo.erp_systems e WHERE e.is_active
              AND (lower(e.code) = lower(btrim(r.sjo_erp)) OR lower(e.name) = lower(btrim(r.sjo_erp)))
            ORDER BY (lower(e.code) = lower(btrim(r.sjo_erp))) DESC LIMIT 1)
    FROM tmp_sjo_invoice_input r;

    SELECT string_agg(
               'row ' || r.row_no || ': ' || concat_ws(', ',
                   CASE WHEN x.country_id IS NULL THEN 'country ' || r.sjo_country END,
                   CASE WHEN x.business_unit_id IS NULL THEN 'BU ' || r.sjo_business_unit END,
                   CASE WHEN x.erp_system_id IS NULL THEN 'ERP ' || r.sjo_erp END),
               '; ' ORDER BY r.row_no) INTO v_msg
    FROM tmp_sjo_invoice_input r JOIN tmp_sjo_invoice_refs x ON x.row_no = r.row_no
    WHERE x.country_id IS NULL OR x.business_unit_id IS NULL OR x.erp_system_id IS NULL;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown or inactive values (%). Add them in Settings > Configuration.', v_msg
            USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(i.invoice_code, ', ') INTO v_msg
    FROM sjo.sjo_invoices i JOIN tmp_sjo_invoice_input r ON r.invoice_code = i.invoice_code;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Invoice id(s) already exist: %', v_msg USING ERRCODE = 'CA409';
    END IF;

    -- Daily limit, with the module's settings row locked so concurrent batches serialise
    SELECT max_invoices_limit INTO v_limit FROM app.app_settings WHERE module_id = p_module_id FOR UPDATE;
    v_limit := coalesce(v_limit, 100);
    SELECT count(*) INTO v_created_today
    FROM sjo.sjo_invoices
    WHERE module_id = p_module_id AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
    IF v_created_today + v_count > v_limit THEN
        RAISE EXCEPTION 'Daily invoice limit of % would be exceeded (% already created today)', v_limit, v_created_today
            USING ERRCODE = 'CA409';
    END IF;

    -- Vendors by CUIT (first name in the request wins for new vendors)
    INSERT INTO app.vendors (legal_name, cuit)
    SELECT DISTINCT ON (cuit) vendor_name, cuit
    FROM tmp_sjo_invoice_input
    WHERE cuit IS NOT NULL
    ORDER BY cuit, row_no
    ON CONFLICT (cuit) DO NOTHING;

    -- Stations parsed from "CCC - Station Name"
    INSERT INTO app.country_stations (country_code, station_name)
    SELECT DISTINCT upper(p.parts[1]), p.parts[2]
    FROM tmp_sjo_invoice_input r
    CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
    WHERE p.parts IS NOT NULL
    ON CONFLICT (country_code, station_name) DO NOTHING;

    INSERT INTO sjo.sjo_invoices
        (invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a,
         amount, invoice_subtotal, status, reception_date, email_reception_date, assigned_user_id, created_by,
         country_id, business_unit_id, erp_system_id, id_fiscal, ab_number, ab_name,
         flow_turn_down, critical_vendor, urgent_invoice)
    SELECT r.invoice_code, p_module_id, v.id, cs.id, r.invoice_1a, r.invoice_2a,
           r.amount, r.amount, r.status, r.reception_date, r.email_reception_date, r.assigned_user_id, p_created_by,
           x.country_id, x.business_unit_id, x.erp_system_id, r.id_fiscal,
           nullif(btrim(r.ab_number), ''), nullif(btrim(r.ab_name), ''),
           coalesce(r.flow_turn_down, false), coalesce(r.critical_vendor, false), coalesce(r.urgent_invoice, false)
    FROM tmp_sjo_invoice_input r

    JOIN tmp_sjo_invoice_refs x ON x.row_no = r.row_no

    LEFT JOIN app.vendors v ON v.cuit = r.cuit
    CROSS JOIN LATERAL (SELECT regexp_match(r.country_station, '^\s*([A-Za-z]{3})\s*-\s*(.*\S)\s*$') AS parts) p
    LEFT JOIN app.country_stations cs ON cs.country_code = upper(p.parts[1]) AND cs.station_name = p.parts[2]
    ORDER BY r.row_no;

    RETURN QUERY
    SELECT r.invoice_code::varchar(60)
    FROM tmp_sjo_invoice_input r
    ORDER BY r.row_no;
END;
$$;
