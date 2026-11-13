-- =====================================================================
-- app.usp_integration_save - create (p_integration_id NULL) or update an integration and
-- replace its extraction profiles in one transaction.
-- Request:  integration fields; p_expected_version (update only, optimistic concurrency);
--           p_clear_secret (true when the auth method changed); p_next_run_at (computed by the
--           backend scheduler from p_schedule); p_profiles = JSON array of
--           app.udt_integration_profile_input (id NULL = new; profiles missing from the array are deleted);
--           p_user_id (admin performing the change)
-- Response: app.udt_integration_result
-- Behaviour: deactivating an integration cancels its queued job and asks a running job to stop.
--            Profile cursors (watermark) are kept; use usp_integration_profile_reset_cursor to re-sync.
-- Errors:   CA400 missing / invalid values, unknown module or status, profile of another integration,
--                 provider type change
--           CA404 integration not found
--           CA409 name already used, or the integration was changed by someone else (version)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_save(
    p_integration_id    uuid,
    p_expected_version  integer,
    p_provider_type     text,
    p_name              text,
    p_description       text,
    p_environment       text,
    p_source_system     text,
    p_is_active         boolean,
    p_connection        jsonb,
    p_auth_type         text,
    p_auth_settings     jsonb,
    p_clear_secret      boolean,
    p_schedule          jsonb,
    p_auto_sync_enabled boolean,
    p_retry_policy      jsonb,
    p_next_run_at       timestamptz,
    p_profiles          jsonb,
    p_user_id           uuid
)
RETURNS app.udt_integration_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_id        uuid := p_integration_id;
    v_current   record;
    v_msg       text;
BEGIN
    IF nullif(btrim(p_name), '') IS NULL OR nullif(btrim(p_source_system), '') IS NULL
       OR nullif(btrim(p_provider_type), '') IS NULL OR nullif(btrim(p_auth_type), '') IS NULL THEN
        RAISE EXCEPTION 'Name, source system, provider type and authentication method are required.' USING ERRCODE = 'CA400';
    END IF;

    IF EXISTS (SELECT 1 FROM app.integrations
               WHERE lower(name) = lower(btrim(p_name)) AND (v_id IS NULL OR id <> v_id)) THEN
        RAISE EXCEPTION 'An integration named "%" already exists.', btrim(p_name) USING ERRCODE = 'CA409';
    END IF;

    -- ---- Profiles (validated before anything is written) ----
    CREATE TEMP TABLE IF NOT EXISTS tmp_profile_input OF app.udt_integration_profile_input ON COMMIT DROP;
    TRUNCATE tmp_profile_input;
    INSERT INTO tmp_profile_input
    SELECT * FROM jsonb_populate_recordset(NULL::app.udt_integration_profile_input, coalesce(p_profiles, '[]'::jsonb));

    IF EXISTS (SELECT 1 FROM tmp_profile_input WHERE nullif(btrim(name), '') IS NULL
                  OR module_id IS NULL OR nullif(btrim(invoice_code_template), '') IS NULL) THEN
        RAISE EXCEPTION 'Every extraction profile needs a name, a target application and an invoice id template.' USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(n, ', ') INTO v_msg
    FROM (SELECT lower(btrim(name)) AS n FROM tmp_profile_input GROUP BY 1 HAVING count(*) > 1) d;
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Profile names must be unique (%).', v_msg USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(t.name, ', ') INTO v_msg
    FROM tmp_profile_input t
    WHERE NOT EXISTS (SELECT 1 FROM app.app_modules m WHERE m.id = t.module_id AND m.is_active);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown or inactive target application for profile(s): %', v_msg USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(t.name || ': ' || s.status, ', ') INTO v_msg
    FROM tmp_profile_input t
    CROSS JOIN LATERAL (VALUES (coalesce(t.default_status, 'Pending')), (t.cancellation_rule ->> 'setStatus')) AS s (status)
    WHERE s.status IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM app.statuses st WHERE st.code = s.status AND st.is_active);
    IF v_msg IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown or inactive status in profile(s): %', v_msg USING ERRCODE = 'CA400';
    END IF;

    -- ---- Integration ----
    IF v_id IS NULL THEN
        INSERT INTO app.integrations
            (provider_type, name, description, environment, source_system, is_active, connection, auth_type,
             auth_settings, schedule, auto_sync_enabled, retry_policy, next_run_at, created_by, updated_by)
        VALUES
            (btrim(p_provider_type), btrim(p_name), nullif(btrim(p_description), ''), nullif(btrim(p_environment), ''),
             btrim(p_source_system), coalesce(p_is_active, true), coalesce(p_connection, '{}'::jsonb), btrim(p_auth_type),
             coalesce(p_auth_settings, '{}'::jsonb), coalesce(p_schedule, '{}'::jsonb), coalesce(p_auto_sync_enabled, false),
             coalesce(p_retry_policy, '{}'::jsonb), p_next_run_at, p_user_id, p_user_id)
        RETURNING id INTO v_id;

        IF EXISTS (SELECT 1 FROM tmp_profile_input WHERE id IS NOT NULL) THEN
            RAISE EXCEPTION 'New integrations cannot reference existing profiles.' USING ERRCODE = 'CA400';
        END IF;
    ELSE
        SELECT id, version, provider_type INTO v_current FROM app.integrations WHERE id = v_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Integration not found.' USING ERRCODE = 'CA404';
        END IF;
        IF p_expected_version IS DISTINCT FROM v_current.version THEN
            RAISE EXCEPTION 'The integration was changed by someone else. Reload it and apply your changes again.' USING ERRCODE = 'CA409';
        END IF;
        IF v_current.provider_type <> btrim(p_provider_type) THEN
            RAISE EXCEPTION 'The provider type of an integration cannot be changed.' USING ERRCODE = 'CA400';
        END IF;

        SELECT string_agg(t.id::text, ', ') INTO v_msg
        FROM tmp_profile_input t
        WHERE t.id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM app.integration_profiles p WHERE p.id = t.id AND p.integration_id = v_id);
        IF v_msg IS NOT NULL THEN
            RAISE EXCEPTION 'Profile(s) % do not belong to this integration.', v_msg USING ERRCODE = 'CA400';
        END IF;

        UPDATE app.integrations SET
            name              = btrim(p_name),
            description       = nullif(btrim(p_description), ''),
            environment       = nullif(btrim(p_environment), ''),
            source_system     = btrim(p_source_system),
            is_active         = coalesce(p_is_active, true),
            connection        = coalesce(p_connection, '{}'::jsonb),
            auth_type         = btrim(p_auth_type),
            auth_settings     = coalesce(p_auth_settings, '{}'::jsonb),
            secret_ciphertext = CASE WHEN p_clear_secret THEN NULL ELSE secret_ciphertext END,
            secret_updated_at = CASE WHEN p_clear_secret THEN NULL ELSE secret_updated_at END,
            schedule          = coalesce(p_schedule, '{}'::jsonb),
            auto_sync_enabled = coalesce(p_auto_sync_enabled, false),
            retry_policy      = coalesce(p_retry_policy, '{}'::jsonb),
            next_run_at       = p_next_run_at,
            version           = version + 1,
            updated_by        = p_user_id,
            updated_at        = now()
        WHERE id = v_id;

        DELETE FROM app.integration_profiles p
        WHERE p.integration_id = v_id
          AND NOT EXISTS (SELECT 1 FROM tmp_profile_input t WHERE t.id = p.id);

        UPDATE app.integration_profiles p SET
            module_id             = t.module_id,
            name                  = btrim(t.name),
            is_active             = coalesce(t.is_active, true),
            settings              = coalesce(t.settings, '{}'::jsonb),
            key_fields            = coalesce(t.key_fields, '[]'::jsonb),
            invoice_code_template = btrim(t.invoice_code_template),
            field_mapping         = coalesce(t.field_mapping, '{}'::jsonb),
            cancellation_rule     = t.cancellation_rule,
            default_status        = coalesce(t.default_status, 'Pending'),
            initial_from          = t.initial_from,
            sort_order            = coalesce(t.sort_order, 0),
            updated_at            = now()
        FROM tmp_profile_input t
        WHERE t.id = p.id;

        IF NOT coalesce(p_is_active, true) THEN
            UPDATE app.integration_sync_jobs
            SET status = 'cancelled', finished_at = now(), error_summary = 'Integration deactivated'
            WHERE integration_id = v_id AND status = 'queued';
            UPDATE app.integration_sync_jobs
            SET cancel_requested = true
            WHERE integration_id = v_id AND status = 'running';
        END IF;
    END IF;

    INSERT INTO app.integration_profiles
        (integration_id, module_id, name, is_active, settings, key_fields, invoice_code_template,
         field_mapping, cancellation_rule, default_status, initial_from, sort_order)
    SELECT v_id, t.module_id, btrim(t.name), coalesce(t.is_active, true), coalesce(t.settings, '{}'::jsonb),
           coalesce(t.key_fields, '[]'::jsonb), btrim(t.invoice_code_template), coalesce(t.field_mapping, '{}'::jsonb),
           t.cancellation_rule, coalesce(t.default_status, 'Pending'), t.initial_from, coalesce(t.sort_order, 0)
    FROM tmp_profile_input t
    WHERE t.id IS NULL;

    RETURN app.ufn_integration_row(v_id);
END;
$$;
