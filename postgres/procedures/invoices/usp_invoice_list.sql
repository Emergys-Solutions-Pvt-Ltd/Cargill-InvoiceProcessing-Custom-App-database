-- =====================================================================
-- app.usp_invoice_list - Invoices grid for one module (newest reception date first)
-- Request:  p_module_id (from usp_app_module_get_by_slug), p_search (invoice id, vendor,
--           CUIT or station contains, case-insensitive), p_status ('ALL' or a status),
--           p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_invoice_list_result - invoice is an app.udt_invoice_result as JSON
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_list(
    p_module_id     integer,
    p_search        text    DEFAULT NULL,
    p_status        text    DEFAULT 'ALL',
    p_page          integer DEFAULT 1,
    p_page_size     integer DEFAULT 5
)
RETURNS SETOF app.udt_invoice_list_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_pattern text := app.ufn_like_contains(p_search);
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT v.*,
               row_number() OVER (ORDER BY v.reception_date DESC, v.id DESC) AS rn,
               count(*) OVER ()::integer                                     AS total
        FROM app.vw_invoice_summary v
        WHERE v.module_id = p_module_id
          AND (coalesce(p_status, 'ALL') = 'ALL' OR v.status = p_status)
          AND (v_pattern IS NULL
               OR v.invoice_code    ILIKE v_pattern
               OR v.vendor_name     ILIKE v_pattern
               OR v.cuit            ILIKE v_pattern
               OR v.country_station ILIKE v_pattern)
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(max(total)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT to_jsonb(ROW(
               m.id, m.invoice_code, m.module_slug, m.invoice_prefix, m.application_code, m.invoice_1a, m.invoice_2a,
               m.first_invoice_number, m.second_invoice_number, m.invoice_date, m.expiry_days, m.invoice_expiry_date,
               m.support_team, m.pre_settlement_number, m.credit_note, m.currency_code, m.amount, m.invoice_subtotal,
               m.invoice_subtotal_with_tax, m.status, m.reception_date, m.email_reception_date, m.vendor_name, m.cuit,
               m.country_station, m.pdf_attachment_id, m.pdf_file_name, m.pdf_title, m.pdf_mime_type,
               m.process_id, m.process_name, m.origin_city_id, m.origin_name, m.destination_city_id,
               m.destination_name, m.team_id, m.team_name, m.assigned_user_id, m.assigned_user_name,
               m.claim_number, m.additional_info, m.filenet_id
           )::app.udt_invoice_result),
           m.total, p.pages, p.page, p_page_size
    FROM matches m CROSS JOIN paging p
    WHERE m.rn BETWEEN (p.page - 1) * p_page_size + 1 AND p.page * p_page_size
    ORDER BY m.rn;
END;
$$;
