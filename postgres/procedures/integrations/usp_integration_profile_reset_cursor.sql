-- =====================================================================
-- app.usp_integration_profile_reset_cursor - clear a profile's watermark so the next run
-- re-extracts from initial_from (full re-sync; duplicates are impossible thanks to
-- invoice_external_refs, unchanged records are counted as skipped).
-- Request:  p_integration_id, p_profile_id
-- Response: app.udt_row_count_result
-- Errors:   CA404 profile not found, CA409 a synchronization is running
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_profile_reset_cursor(p_integration_id integer, p_profile_id integer)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    IF EXISTS (SELECT 1 FROM app.integration_sync_jobs WHERE integration_id = p_integration_id AND status = 'running') THEN
        RAISE EXCEPTION 'A synchronization is running. Reset the cursor after it finishes.' USING ERRCODE = 'CA409';
    END IF;
    UPDATE app.integration_profiles SET watermark = NULL, watermark_updated_at = now(), updated_at = now()
    WHERE id = p_profile_id AND integration_id = p_integration_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Profile not found.' USING ERRCODE = 'CA404';
    END IF;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
