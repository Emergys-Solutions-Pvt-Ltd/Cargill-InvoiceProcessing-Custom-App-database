-- =====================================================================
-- app.usp_sync_job_list - Synchronization history of one integration, newest first
-- Request:  p_integration_id, p_status, p_trigger_type (NULL = all), p_from / p_to (created_at range,
--           p_to exclusive), p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_sync_job_list_result (job JSON + paging on every row)
-- Errors:   CA400 invalid page size, CA404 integration not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_sync_job_list(
    p_integration_id    integer,
    p_status            text        DEFAULT NULL,
    p_trigger_type      text        DEFAULT NULL,
    p_from              timestamptz DEFAULT NULL,
    p_to                timestamptz DEFAULT NULL,
    p_page              integer     DEFAULT 1,
    p_page_size         integer     DEFAULT 10
)
RETURNS SETOF app.udt_sync_job_list_result
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app.integrations WHERE id = p_integration_id) THEN
        RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT j.id,
               row_number() OVER (ORDER BY j.created_at DESC, j.id DESC) AS rn,
               count(*) OVER ()::integer AS total
        FROM app.integration_sync_jobs j
        WHERE j.integration_id = p_integration_id
          AND (p_status IS NULL OR j.status = p_status)
          AND (p_trigger_type IS NULL OR j.trigger_type = p_trigger_type)
          AND (p_from IS NULL OR j.created_at >= p_from)
          AND (p_to IS NULL OR j.created_at < p_to)
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(coalesce(max(total), 0)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT to_jsonb(r), m.total, pg.pages, pg.page, p_page_size
    FROM matches m
    CROSS JOIN paging pg
    CROSS JOIN LATERAL app.ufn_sync_job_row(m.id) r
    WHERE m.rn BETWEEN (pg.page - 1) * p_page_size + 1 AND pg.page * p_page_size
    ORDER BY m.rn;
END;
$$;
