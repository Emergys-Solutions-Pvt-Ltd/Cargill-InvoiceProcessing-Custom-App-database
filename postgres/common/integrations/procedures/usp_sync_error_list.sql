-- =====================================================================
-- app.usp_sync_error_list - error details of one job (troubleshooting)
-- Request:  p_job_id, p_stage (NULL = all), p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_sync_error_list_result, in the order they were recorded
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_error_list(
    p_job_id    uuid,
    p_stage     text    DEFAULT NULL,
    p_page      integer DEFAULT 1,
    p_page_size integer DEFAULT 20
)
RETURNS SETOF app.udt_sync_error_list_result
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT e.*, row_number() OVER (ORDER BY e.id) AS rn, count(*) OVER ()::integer AS total
        FROM app.integration_sync_errors e
        WHERE e.job_id = p_job_id AND (p_stage IS NULL OR e.stage = p_stage)
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(coalesce(max(total), 0)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT m.id, m.job_id, m.profile_id, p.name::text, m.stage::text, m.external_key::text, m.message::text,
           m.details, m.created_at, m.total, pg.pages, pg.page, p_page_size
    FROM matches m
    CROSS JOIN paging pg
    LEFT JOIN app.integration_profiles p ON p.id = m.profile_id
    WHERE m.rn BETWEEN (pg.page - 1) * p_page_size + 1 AND pg.page * p_page_size
    ORDER BY m.rn;
END;
$$;
