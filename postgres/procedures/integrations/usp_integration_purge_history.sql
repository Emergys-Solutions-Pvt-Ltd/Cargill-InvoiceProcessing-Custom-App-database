-- =====================================================================
-- app.usp_integration_purge_history - retention: delete finished jobs (and their errors)
-- older than p_keep_days. Invoices and invoice_external_refs are never purged.
-- Request:  p_keep_days (minimum 7)
-- Response: app.udt_row_count_result - number of jobs deleted
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_purge_history(p_keep_days integer)
RETURNS app.udt_row_count_result
LANGUAGE sql
AS $$
    WITH del AS (
        DELETE FROM app.integration_sync_jobs
        WHERE finished_at < now() - make_interval(days => greatest(coalesce(p_keep_days, 90), 7))
        RETURNING 1
    )
    SELECT ROW(count(*)::integer)::app.udt_row_count_result FROM del;
$$;
