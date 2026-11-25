-- =====================================================================
-- trg_{{T}}_audit - Audit History of {{APP}} invoices: every insert / update / delete of {{S}}.{{T}}
-- is written to app.invoice_audit_log by app.ufn_invoice_audit_trigger.
-- Depends on: {{S}}.{{T}}, app.invoice_audit_log, app.ufn_invoice_audit_trigger
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_{{T}}_audit
    AFTER INSERT OR UPDATE OR DELETE ON {{S}}.{{T}}
    FOR EACH ROW EXECUTE FUNCTION app.ufn_invoice_audit_trigger();
