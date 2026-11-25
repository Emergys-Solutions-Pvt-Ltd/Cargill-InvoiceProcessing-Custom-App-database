-- =====================================================================
-- app.ufn_invoice_audit_trigger - AFTER INSERT / UPDATE / DELETE row trigger of the per-app invoice tables
-- (trg_<app>_invoices_audit in <app>/invoices/triggers). Writes app.invoice_audit_log:
--   INSERT -> 'Created'; DELETE -> 'Deleted';
--   UPDATE -> 'Updated' with the changed columns [{ field, oldValue, newValue }] (reference ids as names);
--             bookkeeping columns (updated_at / updated_by / created_at / created_by) are ignored and an
--             UPDATE that changes nothing else writes no row.
-- Actor: the session setting app.user_id (the API sets it with set_config(..., true) for user actions),
--        else created_by (INSERT) / updated_by when the statement changed it (UPDATE), else NULL = system.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_invoice_audit_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_setting   text := nullif(current_setting('app.user_id', true), '');
    v_actor     uuid;
    v_old       jsonb;
    v_new       jsonb;
    v_changes   jsonb;
BEGIN
    IF v_setting ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_actor := v_setting::uuid;
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO app.invoice_audit_log (app_schema, invoice_id, invoice_code, action, changes, actor_user_id)
        VALUES (TG_TABLE_SCHEMA, NEW.id, NEW.invoice_code, 'Created', NULL, coalesce(v_actor, NEW.created_by));
        RETURN NULL;
    END IF;

    IF TG_OP = 'DELETE' THEN
        INSERT INTO app.invoice_audit_log (app_schema, invoice_id, invoice_code, action, changes, actor_user_id)
        VALUES (TG_TABLE_SCHEMA, OLD.id, OLD.invoice_code, 'Deleted', NULL, v_actor);
        RETURN NULL;
    END IF;

    v_old := to_jsonb(OLD) - ARRAY['updated_at', 'updated_by', 'created_at', 'created_by'];
    v_new := to_jsonb(NEW) - ARRAY['updated_at', 'updated_by', 'created_at', 'created_by'];

    SELECT jsonb_agg(jsonb_build_object(
               'field',    n.key,
               'oldValue', app.ufn_invoice_audit_label(n.key, v_old ->> n.key),
               'newValue', app.ufn_invoice_audit_label(n.key, n.value #>> '{}'))
           ORDER BY n.key)
      INTO v_changes
      FROM jsonb_each(v_new) n
     WHERE n.value IS DISTINCT FROM v_old -> n.key;

    IF v_changes IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_actor IS NULL AND NEW.updated_by IS DISTINCT FROM OLD.updated_by THEN
        v_actor := NEW.updated_by;
    END IF;

    INSERT INTO app.invoice_audit_log (app_schema, invoice_id, invoice_code, action, changes, actor_user_id)
    VALUES (TG_TABLE_SCHEMA, NEW.id, NEW.invoice_code, 'Updated', v_changes, v_actor);
    RETURN NULL;
END;
$$;
