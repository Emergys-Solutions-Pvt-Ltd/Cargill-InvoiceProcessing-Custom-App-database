-- =====================================================================
-- app.usp_user_list - Settings / User Access Management grid (newest first)
-- Request:  p_search (name or email contains, case-insensitive), p_app_code ('ALL' or a code),
--           p_role ('ALL', 'Admin', 'User'), p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_user_list_result (paging columns on every row)
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_user_list(
    p_search        text    DEFAULT NULL,
    p_app_code      text    DEFAULT 'ALL',
    p_role          text    DEFAULT 'ALL',
    p_page          integer DEFAULT 1,
    p_page_size     integer DEFAULT 5
)
RETURNS SETOF app.udt_user_list_result
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
               row_number() OVER (ORDER BY v.id DESC) AS rn,
               count(*) OVER ()::integer              AS total
        FROM app.vw_user_summary v
        WHERE (v_pattern IS NULL OR v.name ILIKE v_pattern OR v.email ILIKE v_pattern)
          AND (coalesce(p_role, 'ALL') = 'ALL' OR v.role = p_role)
          AND (coalesce(p_app_code, 'ALL') = 'ALL' OR EXISTS (
                SELECT 1 FROM app.user_applications ua
                JOIN app.applications a ON a.id = ua.application_id
                WHERE ua.user_id = v.id AND a.code = p_app_code))
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(max(total)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT m.id, m.username, m.name, m.email, m.role, m.status, m.auth_provider, m.assigned_apps,
           m.total, p.pages, p.page, p_page_size
    FROM matches m CROSS JOIN paging p
    WHERE m.rn BETWEEN (p.page - 1) * p_page_size + 1 AND p.page * p_page_size
    ORDER BY m.rn;
END;
$$;
