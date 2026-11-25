-- GENERATED from common/invoices/templates/procedures/usp_invoice_audit_list.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.usp_invoice_audit_list - SJO Invoice Details > Audit History
-- Request:  p_invoice_code
-- Response: SETOF app.udt_invoice_audit_result, newest first (created / updated / deleted events with the
--           changed fields and the acting user; actor_name NULL = system)
-- Errors:   CA404 invoice not found
-- =====================================================================
CREATE OR REPLACE FUNCTION sjo.usp_invoice_audit_list(p_invoice_code text)
RETURNS SETOF app.udt_invoice_audit_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_invoice_id    uuid;
BEGIN
    SELECT id INTO v_invoice_id FROM sjo.sjo_invoices WHERE invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN QUERY
    SELECT a.id, a.action, a.changes, a.actor_user_id, u.name, a.created_at
      FROM app.invoice_audit_log a
      LEFT JOIN app_auth.users u ON u.id = a.actor_user_id
     WHERE a.app_schema = 'sjo' AND a.invoice_id = v_invoice_id
     ORDER BY a.event_seq DESC;
END;
$$;
