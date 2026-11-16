-- =====================================================================
-- app.usp_integration_delete - delete an integration, its profiles and its job history
-- Request:  p_integration_id
-- Response: app.udt_row_count_result
-- Behaviour: imported invoices are kept; their invoice_external_refs keep source_system and
--            external_key (integration / profile / job links are cleared).
-- Errors:   CA404 not found, CA409 a synchronization is running
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_delete(p_integration_id uuid)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows      integer;
    v_schema    text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app.integrations WHERE id = p_integration_id) THEN
        RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
    END IF;
    IF EXISTS (SELECT 1 FROM app.integration_sync_jobs WHERE integration_id = p_integration_id AND status = 'running') THEN
        RAISE EXCEPTION 'A synchronization is running. Cancel it and wait for it to stop before deleting.' USING ERRCODE = 'CA409';
    END IF;

    -- Imported invoices keep their source link but lose the integration / profile / job links. Done
    -- explicitly (not left to the ON DELETE SET NULL actions, whose firing order is not guaranteed).
    FOR v_schema IN SELECT DISTINCT db_schema FROM app.applications WHERE db_schema IS NOT NULL
    LOOP
        EXECUTE format('UPDATE %I.invoice_external_refs SET integration_id = NULL, profile_id = NULL,
                               first_job_id = NULL, last_job_id = NULL
                        WHERE integration_id = $1
                           OR profile_id IN (SELECT id FROM app.integration_profiles WHERE integration_id = $1)', v_schema)
            USING p_integration_id;
    END LOOP;

    UPDATE app.integrations SET last_job_id = NULL WHERE id = p_integration_id;
    DELETE FROM app.integrations WHERE id = p_integration_id;   -- profiles, jobs, errors cascade
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
