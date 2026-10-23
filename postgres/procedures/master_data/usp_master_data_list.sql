-- =====================================================================
-- app.usp_master_data_list - Settings > Configuration grid for one entity
-- Request:  p_entity (countries | states | cities | business-units | teams | statuses | processes),
--           p_search (code, name or description contains, case-insensitive),
--           p_parent_id (states: country id, cities: state id; NULL = all),
--           p_include_inactive, p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_master_data_list_result, ordered by sort_order then name
-- Errors:   CA400 invalid page size, CA404 unknown entity
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_master_data_list(
    p_entity            text,
    p_search            text    DEFAULT NULL,
    p_parent_id         integer DEFAULT NULL,
    p_include_inactive  boolean DEFAULT true,
    p_page              integer DEFAULT 1,
    p_page_size         integer DEFAULT 10
)
RETURNS SETOF app.udt_master_data_list_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_select    text := app.ufn_master_data_select_sql(p_entity);
    v_pattern   text := app.ufn_like_contains(p_search);
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;

    RETURN QUERY EXECUTE
        'WITH base AS (' || v_select || '),
         matches AS (
             SELECT b.*,
                    row_number() OVER (ORDER BY b.sort_order, lower(b.name), b.id) AS rn,
                    count(*) OVER ()::integer AS total
             FROM base b
             WHERE ($1::text IS NULL OR b.name ILIKE $1 OR b.code ILIKE $1 OR b.description ILIKE $1)
               AND ($2::integer IS NULL OR b.parent_id = $2)
               AND ($3 OR b.is_active)
         ),
         paging AS (
             SELECT pages, least(greatest(coalesce($4, 1), 1), pages) AS page
             FROM (SELECT greatest(1, ceil(max(total)::numeric / $5))::integer AS pages FROM matches) t
         )
         SELECT m.id, m.code, m.name, m.description, m.parent_id, m.parent_name, m.color,
                m.sort_order, m.is_active, m.updated_at, m.total, p.pages, p.page, $5
         FROM matches m CROSS JOIN paging p
         WHERE m.rn BETWEEN (p.page - 1) * $5 + 1 AND p.page * $5
         ORDER BY m.rn'
    USING v_pattern, p_parent_id, coalesce(p_include_inactive, true), p_page, p_page_size;
END;
$$;
