-- =====================================================================
-- app.usp_mailbox_list - Settings > Email Configuration > Email Registration grid
-- Request:  p_search (address, folder or target module name contains, case-insensitive),
--           p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_mailbox_list_result (paging columns on every row),
--           ordered lower(address), lower(folder), id
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_list(
    p_search        text    DEFAULT NULL,
    p_page          integer DEFAULT 1,
    p_page_size     integer DEFAULT 10
)
RETURNS SETOF app.udt_mailbox_list_result
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
        SELECT mb.id,
               row_number() OVER (ORDER BY lower(mb.address), lower(mb.folder), mb.id) AS rn,
               count(*) OVER ()::integer AS total
        FROM app.mailboxes mb
        JOIN app.app_modules m ON m.id = mb.module_id
        WHERE v_pattern IS NULL
           OR mb.address ILIKE v_pattern
           OR mb.folder ILIKE v_pattern
           OR m.name ILIKE v_pattern
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(coalesce(max(total), 0)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT r.id, r.address, r.folder, r.module_id, r.module_slug, r.module_name, r.is_active,
           r.last_polled_at, r.last_error, r.created_at, r.updated_at,
           x.total, pg.pages, pg.page, p_page_size
    FROM matches x
    CROSS JOIN paging pg
    CROSS JOIN LATERAL app.ufn_mailbox_row(x.id) r
    WHERE x.rn BETWEEN (pg.page - 1) * p_page_size + 1 AND pg.page * p_page_size
    ORDER BY x.rn;
END;
$$;
