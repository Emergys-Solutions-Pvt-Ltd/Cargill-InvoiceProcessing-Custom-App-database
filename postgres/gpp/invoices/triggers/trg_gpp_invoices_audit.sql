-- GENERATED from common/invoices/templates/triggers/trg_{{T}}_audit.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- trg_gpp_invoices_audit - Audit History of GPP invoices: every insert / update / delete of gpp.gpp_invoices
-- is written to app.invoice_audit_log by app.ufn_invoice_audit_trigger.
-- Depends on: gpp.gpp_invoices, app.invoice_audit_log, app.ufn_invoice_audit_trigger
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_gpp_invoices_audit
    AFTER INSERT OR UPDATE OR DELETE ON gpp.gpp_invoices
    FOR EACH ROW EXECUTE FUNCTION app.ufn_invoice_audit_trigger();
