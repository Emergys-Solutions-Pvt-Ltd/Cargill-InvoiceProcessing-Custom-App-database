-- GENERATED from common/invoices/templates/triggers/trg_{{T}}_audit.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- trg_rospbu_invoices_audit - Audit History of ROSPBU invoices: every insert / update / delete of rospbu.rospbu_invoices
-- is written to app.invoice_audit_log by app.ufn_invoice_audit_trigger.
-- Depends on: rospbu.rospbu_invoices, app.invoice_audit_log, app.ufn_invoice_audit_trigger
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_rospbu_invoices_audit
    AFTER INSERT OR UPDATE OR DELETE ON rospbu.rospbu_invoices
    FOR EACH ROW EXECUTE FUNCTION app.ufn_invoice_audit_trigger();
