-- GENERATED from common/invoices/templates/tables/42_invoice_source_emails.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- gpp.invoice_source_emails - the email a GPP invoice PDF was received through
-- (shown by the Email button of the PDF preview on the Invoice Details page).
-- One email per invoice; the attachments that came with it point back via
-- invoice_attachments.source_email_id. The body is kept as plain text only,
-- so it can be shown without rendering sender-controlled HTML.
-- Depends on: gpp.gpp_invoices
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS gpp.invoice_source_emails (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_gpp_source_emails PRIMARY KEY,
    invoice_id      uuid         NOT NULL CONSTRAINT fk_gpp_source_emails_invoice REFERENCES gpp.gpp_invoices (id) ON DELETE CASCADE,
    message_id      varchar(255)    NULL,                           -- RFC 5322 Message-ID of the mailbox item
    from_name       varchar(150)    NULL,
    from_address    varchar(255)    NOT NULL,
    to_addresses    varchar(1000)   NOT NULL,                       -- comma separated
    cc_addresses    varchar(1000)   NULL,                           -- comma separated
    subject         varchar(500)    NOT NULL DEFAULT '',
    body_text       text            NULL,
    received_at     timestamptz(0)  NOT NULL,
    created_at      timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_gpp_source_emails_invoice ON gpp.invoice_source_emails (invoice_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
