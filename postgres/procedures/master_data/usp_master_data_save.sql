-- =====================================================================
-- app.usp_master_data_save - create (p_id NULL) or update one Configuration item
-- Request:  p_entity, p_id, p_code (required for countries, BUs, statuses, processes),
--           p_name, p_description, p_parent_id (required for states / cities),
--           p_color (statuses: warning | info | success | danger | neutral), p_sort_order, p_is_active
-- Response: app.udt_master_data_result (the saved item)
-- Notes:    renaming a status code also updates invoices using it (FK ON UPDATE CASCADE)
-- Errors:   CA400 missing / invalid field or unknown parent, CA404 unknown entity or item,
--           CA409 code or name already used
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_master_data_save(
    p_entity        text,
    p_id            integer DEFAULT NULL,
    p_code          text    DEFAULT NULL,
    p_name          text    DEFAULT NULL,
    p_description   text    DEFAULT NULL,
    p_parent_id     integer DEFAULT NULL,
    p_color         text    DEFAULT NULL,
    p_sort_order    integer DEFAULT 0,
    p_is_active     boolean DEFAULT true
)
RETURNS app.udt_master_data_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_def           app.master_data_entities;
    v_parent        app.master_data_entities;
    v_code          text := nullif(btrim(p_code), '');
    v_name          text := nullif(btrim(p_name), '');
    v_description   text := nullif(btrim(p_description), '');
    v_color         text := lower(nullif(btrim(p_color), ''));
    v_exists        boolean;
    v_id            integer;
    v_set_extra     text := '';
    v_cols_extra    text := '';
    v_vals_extra    text := '';
    v_result        app.udt_master_data_result;
BEGIN
    SELECT * INTO v_def FROM app.master_data_entities WHERE entity = p_entity;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown configuration list ''%''', p_entity USING ERRCODE = 'CA404';
    END IF;

    IF v_name IS NULL THEN
        RAISE EXCEPTION '% name is required.', v_def.label USING ERRCODE = 'CA400';
    END IF;
    IF v_def.code_required AND v_code IS NULL THEN
        RAISE EXCEPTION '% code is required.', v_def.label USING ERRCODE = 'CA400';
    END IF;

    IF v_def.parent_entity IS NOT NULL THEN
        SELECT * INTO v_parent FROM app.master_data_entities WHERE entity = v_def.parent_entity;
        IF p_parent_id IS NULL THEN
            RAISE EXCEPTION '% is required for a %.', v_parent.label, lower(v_def.label) USING ERRCODE = 'CA400';
        END IF;
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM app.%I WHERE id = $1)', v_parent.table_name)
            INTO v_exists USING p_parent_id;
        IF NOT v_exists THEN
            RAISE EXCEPTION 'Selected % does not exist.', lower(v_parent.label) USING ERRCODE = 'CA400';
        END IF;
        v_set_extra  := v_set_extra  || format(', %I = $6', v_def.parent_column);
        v_cols_extra := v_cols_extra || format(', %I', v_def.parent_column);
        v_vals_extra := v_vals_extra || ', $6';
    END IF;

    IF v_def.has_color THEN
        v_color := coalesce(v_color, 'neutral');
        IF v_color NOT IN ('warning', 'info', 'success', 'danger', 'neutral') THEN
            RAISE EXCEPTION 'Color must be one of warning, info, success, danger, neutral.' USING ERRCODE = 'CA400';
        END IF;
        v_set_extra  := v_set_extra  || ', color = $7';
        v_cols_extra := v_cols_extra || ', color';
        v_vals_extra := v_vals_extra || ', $7';
    END IF;

    BEGIN
        IF p_id IS NULL THEN
            EXECUTE format(
                'INSERT INTO app.%I (code, name, description, sort_order, is_active%s) '
                || 'VALUES ($1, $2, $3, $4, $5%s) RETURNING id',
                v_def.table_name, v_cols_extra, v_vals_extra)
            INTO v_id
            USING v_code, v_name, v_description, coalesce(p_sort_order, 0), coalesce(p_is_active, true),
                  p_parent_id, v_color;
        ELSE
            EXECUTE format(
                'UPDATE app.%I SET code = $1, name = $2, description = $3, sort_order = $4, '
                || 'is_active = $5%s, updated_at = now() WHERE id = $8 RETURNING id',
                v_def.table_name, v_set_extra)
            INTO v_id
            USING v_code, v_name, v_description, coalesce(p_sort_order, 0), coalesce(p_is_active, true),
                  p_parent_id, v_color, p_id;
            IF v_id IS NULL THEN
                RAISE EXCEPTION '% not found.', v_def.label USING ERRCODE = 'CA404';
            END IF;
        END IF;
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'A % with the same code or name already exists.', lower(v_def.label)
                USING ERRCODE = 'CA409';
        WHEN string_data_right_truncation THEN
            RAISE EXCEPTION 'A value is too long for this field.' USING ERRCODE = 'CA400';
    END;

    EXECUTE 'SELECT * FROM (' || app.ufn_master_data_select_sql(p_entity) || ') b WHERE b.id = $1'
        INTO v_result USING v_id;
    RETURN v_result;
END;
$$;
