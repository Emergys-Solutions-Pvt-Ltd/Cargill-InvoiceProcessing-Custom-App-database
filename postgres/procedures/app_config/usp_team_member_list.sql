-- =====================================================================
-- app.usp_team_member_list - Admin Configuration team access grid (newest first)
-- Request:  p_module_id, p_team ('ALL' or a team name), p_search (name, email or alias
--           contains, case-insensitive), p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_team_member_list_result (paging columns on every row)
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_team_member_list(
    p_module_id     integer,
    p_team          text    DEFAULT 'ALL',
    p_search        text    DEFAULT NULL,
    p_page          integer DEFAULT 1,
    p_page_size     integer DEFAULT 5
)
RETURNS SETOF app.udt_team_member_list_result
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
        SELECT tm.id, tm.name, tm.email, tm.alias, t.name AS team,
               row_number() OVER (ORDER BY tm.id DESC) AS rn,
               count(*) OVER ()::integer               AS total
        FROM app.app_team_members tm
        JOIN app.teams t ON t.id = tm.team_id
        WHERE tm.module_id = p_module_id
          AND (coalesce(p_team, 'ALL') = 'ALL' OR t.name = p_team)
          AND (v_pattern IS NULL OR tm.name ILIKE v_pattern OR tm.email ILIKE v_pattern OR tm.alias ILIKE v_pattern)
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(max(total)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT m.id, m.name, m.email, m.alias, m.team, m.total, p.pages, p.page, p_page_size
    FROM matches m CROSS JOIN paging p
    WHERE m.rn BETWEEN (p.page - 1) * p_page_size + 1 AND p.page * p_page_size
    ORDER BY m.rn;
END;
$$;
