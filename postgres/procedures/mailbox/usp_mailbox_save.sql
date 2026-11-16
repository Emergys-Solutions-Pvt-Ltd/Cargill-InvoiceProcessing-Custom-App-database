-- =====================================================================
-- app.usp_mailbox_save - create (p_mailbox_id NULL) or update (full replace) a registered mailbox
-- Request:  p_mailbox_id (NULL = create), p_address (stored as received, trimmed; the backend
--           lowercases it), p_folder (NULL / blank = 'inbox'; format is validated by the backend),
--           p_module_slug (target app module, required), p_is_active (NULL = true)
-- Response: app.udt_mailbox_detail_result (the saved mailbox)
-- Behaviour: create needs an active module of an active application. Update also accepts the
--            mailbox's CURRENT module when that module or its application is now inactive (D-016).
--            When address or folder changes (exact comparison), delta_link, last_polled_at and
--            last_error are cleared, so the next poll reads the new folder from the start (D-017).
--            Changing only is_active or the module keeps them.
-- Errors:   CA400 missing / too long / invalid address, folder too long, missing module,
--                 unknown or inactive module
--           CA404 mailbox not found
--           CA409 address + folder already registered (case-insensitive)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_save(
    p_mailbox_id    uuid,
    p_address       text,
    p_folder        text    DEFAULT 'inbox',
    p_module_slug   text    DEFAULT NULL,
    p_is_active     boolean DEFAULT true
)
RETURNS app.udt_mailbox_detail_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_address           text := nullif(btrim(p_address), '');
    v_folder            text := coalesce(nullif(btrim(p_folder), ''), 'inbox');
    v_slug              text := nullif(btrim(p_module_slug), '');
    v_module_id         uuid;
    v_module_active     boolean;
    v_current_address   text;
    v_current_folder    text;
    v_current_module_id uuid;
    v_location_changed  boolean;
    v_id                uuid := p_mailbox_id;
BEGIN
    IF v_address IS NULL THEN
        RAISE EXCEPTION 'Address is required.' USING ERRCODE = 'CA400';
    END IF;
    IF length(v_address) > 255 THEN
        RAISE EXCEPTION 'Address must be at most 255 characters.' USING ERRCODE = 'CA400';
    END IF;
    IF v_address !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
        RAISE EXCEPTION 'Address must be a valid email address.' USING ERRCODE = 'CA400';
    END IF;
    IF length(v_folder) > 255 THEN
        RAISE EXCEPTION 'Folder must be at most 255 characters.' USING ERRCODE = 'CA400';
    END IF;
    IF v_slug IS NULL THEN
        RAISE EXCEPTION 'Target application is required.' USING ERRCODE = 'CA400';
    END IF;

    IF v_id IS NOT NULL THEN
        SELECT address, folder, module_id INTO v_current_address, v_current_folder, v_current_module_id
        FROM app.mailboxes WHERE id = v_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Mailbox not found.' USING ERRCODE = 'CA404';
        END IF;
    END IF;

    SELECT m.id, (m.is_active AND a.is_active)
    INTO v_module_id, v_module_active
    FROM app.app_modules m
    JOIN app.applications a ON a.id = m.application_id
    WHERE m.slug = v_slug;
    -- D-016: an update may keep its current module even when it is now inactive
    IF v_module_id IS NULL
       OR (NOT v_module_active AND (v_id IS NULL OR v_module_id IS DISTINCT FROM v_current_module_id)) THEN
        RAISE EXCEPTION 'Unknown or inactive target application ''%''.', v_slug USING ERRCODE = 'CA400';
    END IF;

    IF EXISTS (SELECT 1 FROM app.mailboxes
               WHERE lower(address) = lower(v_address) AND lower(folder) = lower(v_folder)
                 AND (v_id IS NULL OR id <> v_id)) THEN
        RAISE EXCEPTION 'A mailbox with this address and folder already exists.' USING ERRCODE = 'CA409';
    END IF;

    BEGIN
        IF v_id IS NULL THEN
            INSERT INTO app.mailboxes (address, folder, module_id, is_active)
            VALUES (v_address, v_folder, v_module_id, coalesce(p_is_active, true))
            RETURNING id INTO v_id;
        ELSE
            v_location_changed := v_address IS DISTINCT FROM v_current_address
                               OR v_folder IS DISTINCT FROM v_current_folder;
            UPDATE app.mailboxes
               SET address        = v_address,
                   folder         = v_folder,
                   module_id      = v_module_id,
                   is_active      = coalesce(p_is_active, true),
                   delta_link     = CASE WHEN v_location_changed THEN NULL ELSE delta_link END,
                   last_polled_at = CASE WHEN v_location_changed THEN NULL ELSE last_polled_at END,
                   last_error     = CASE WHEN v_location_changed THEN NULL ELSE last_error END,
                   updated_at     = now()
             WHERE id = v_id;
        END IF;
    EXCEPTION
        WHEN unique_violation THEN      -- a concurrent save registered the same address + folder
            RAISE EXCEPTION 'A mailbox with this address and folder already exists.' USING ERRCODE = 'CA409';
    END;

    RETURN app.ufn_mailbox_row(v_id);
END;
$$;
