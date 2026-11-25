-- =====================================================================
-- app.invoice_audit_log - history of every invoice (Invoice Details > Audit History)
-- One row per create / update / delete of a row in gpp.gpp_invoices, sjo.sjo_invoices or
-- rospbu.rospbu_invoices, written by the trigger function app.ufn_invoice_audit_trigger.
-- changes (updates only): [{ "field": "<column>", "oldValue": "<text>", "newValue": "<text>" }],
--   reference columns (process_id, team_id, assigned_user_id ...) stored as names at the time of the change.
-- actor_user_id: the acting user (session setting app.user_id, set by the API), else created_by /
--   a changed updated_by; NULL = system (SAP / OnBase sync, mailbox, scripts).
-- No FK to the invoice: the per-app tables differ and the history outlives a deleted invoice.
-- event_seq orders events of the same second (several changes in one transaction).
-- Depends on: app_auth.users
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.invoice_audit_log (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_invoice_audit_log PRIMARY KEY,
    event_seq       bigint          GENERATED ALWAYS AS IDENTITY,
    app_schema      varchar(20)     NOT NULL CONSTRAINT ck_invoice_audit_log_app_schema CHECK (app_schema IN ('gpp', 'sjo', 'rospbu')),
    invoice_id      uuid            NOT NULL,
    invoice_code    varchar(60)     NOT NULL,
    action          varchar(20)     NOT NULL CONSTRAINT ck_invoice_audit_log_action CHECK (action IN ('Created', 'Updated', 'Deleted')),
    changes         jsonb           NULL,
    actor_user_id   uuid            NULL CONSTRAINT fk_invoice_audit_log_actor REFERENCES app_auth.users (id) ON DELETE SET NULL,
    created_at      timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_invoice_audit_log_invoice ON app.invoice_audit_log (app_schema, invoice_id, event_seq DESC);
