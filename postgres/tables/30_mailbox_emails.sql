-- =====================================================================
-- app.mailbox_emails - one row per email read from an app.mailboxes folder
-- Shown on the module's Inbox page. graph_message_id is unique, so reading the
-- same message twice (retry, restart, delta resync) never creates a duplicate.
-- The body is kept as plain text only, so it can be shown without rendering
-- sender-controlled HTML (same rule as app.invoice_source_emails).
-- status: New -> Processed (invoice created, invoice_id set) | Ignored | Failed
-- Depends on: app.mailboxes. invoice_id is app-specific after the invoice split, so it has no FK.
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.mailbox_emails (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_mailbox_emails PRIMARY KEY,
    mailbox_id          uuid         NOT NULL CONSTRAINT fk_mailbox_emails_mailbox REFERENCES app.mailboxes (id),
    graph_message_id    varchar(500)    NOT NULL,                       -- Microsoft Graph message id
    internet_message_id varchar(500)    NULL,                           -- RFC 5322 Message-ID header
    from_name           varchar(150)    NULL,
    from_address        varchar(255)    NULL,
    to_addresses        varchar(1000)   NULL,                           -- comma separated
    cc_addresses        varchar(1000)   NULL,                           -- comma separated
    subject             varchar(500)    NOT NULL DEFAULT '',
    body_text           text            NULL,
    received_at         timestamptz(0)  NOT NULL,
    has_attachments     boolean         NOT NULL DEFAULT false,         -- as reported by Graph
    status              varchar(20)     NOT NULL DEFAULT 'New',
    invoice_id          uuid         NULL,                           -- app-specific invoice id; no shared app.invoices table
    status_note         varchar(1000)   NULL,                           -- e.g. why it Failed
    created_at          timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at          timestamptz(0)  NOT NULL DEFAULT now(),
    -- Set when the attachment loop for this email has finished (even if every file was skipped);
    -- NULL + has_attachments = attachments still to be saved (retried by the poller)
    attachments_saved_at timestamptz(0) NULL,
    CONSTRAINT uq_mailbox_emails_graph_id UNIQUE (graph_message_id),
    CONSTRAINT ck_mailbox_emails_status CHECK (status IN ('New', 'Processed', 'Ignored', 'Failed'))
);

-- Inbox page: newest first within a mailbox, optionally filtered by status
CREATE INDEX IF NOT EXISTS ix_mailbox_emails_mailbox_received ON app.mailbox_emails (mailbox_id, received_at DESC);
CREATE INDEX IF NOT EXISTS ix_mailbox_emails_status ON app.mailbox_emails (mailbox_id, status);
