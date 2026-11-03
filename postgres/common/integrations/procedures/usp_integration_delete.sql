-- =====================================================================
-- app.usp_integration_delete - delete an integration, its profiles and its job history
-- Request:  p_integration_id
-- Response: app.udt_row_count_result
-- Behaviour: imported invoices are kept; their invoice_external_refs keep source_system and
--            external_key (integration / profile / job links are cleared).
-- Errors:   CA404 not found, CA409 a synchronization is running
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_delete(p_integration_id integer)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app.integrations WHERE id = p_integration_id) THEN
        RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
    END IF;
    IF EXISTS (SELECT 1 FROM app.integration_sync_jobs WHERE integration_id = p_integration_id AND status = 'running') THEN
        RAISE EXCEPTION 'A synchronization is running. Cancel it and wait for it to stop before deleting.' USING ERRCODE = 'CA409';
    END IF;

    UPDATE app.integrations SET last_job_id = NULL WHERE id = p_integration_id;
    DELETE FROM app.integrations WHERE id = p_integration_id;   -- profiles, jobs, errors cascade
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
