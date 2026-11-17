-- =====================================================================
-- app.mailbox_email_attachments - files saved from an app.mailbox_emails message
-- The file itself is written by the backend under the storage root (inbox/yyyy/mm/<email id>/,
-- random file name); this row keeps the original name and where the file is.
-- storage_path is relative to the backend storage root; never expose it to browsers.
-- Depends on: app.mailbox_emails
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.mailbox_email_attachments (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_mailbox_email_attachments PRIMARY KEY,
    mailbox_email_id    uuid         NOT NULL CONSTRAINT fk_mailbox_attachments_email REFERENCES app.mailbox_emails (id) ON DELETE CASCADE,
    graph_attachment_id varchar(500)    NULL,                           -- Graph attachment id (re-download, de-duplication)
    file_name           varchar(255)    NOT NULL,                       -- original name, shown to users
    mime_type           varchar(100)    NOT NULL DEFAULT 'application/pdf',
    size_bytes          bigint          NOT NULL CONSTRAINT ck_mailbox_attachments_size CHECK (size_bytes >= 0),
    storage_path        varchar(500)    NOT NULL,                       -- relative to STORAGE_DIR
    is_inline           boolean         NOT NULL DEFAULT false,
    created_at          timestamptz(0)  NOT NULL DEFAULT now(),
    storage_provider    varchar(20)     NOT NULL DEFAULT 'local',
    storage_bucket      varchar(255)    NULL,
    content_sha256      char(64)        NULL,
    storage_etag        varchar(200)    NULL,
    CONSTRAINT ck_mailbox_attachments_provider
        CHECK (storage_provider IN ('local', 's3') AND (storage_provider = 'local' OR storage_bucket IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS ix_mailbox_attachments_email ON app.mailbox_email_attachments (mailbox_email_id);
-- The same Graph attachment is stored once per email (a retried poll does not add it again)
CREATE UNIQUE INDEX IF NOT EXISTS uq_mailbox_attachments_graph_id
    ON app.mailbox_email_attachments (mailbox_email_id, graph_attachment_id) WHERE graph_attachment_id IS NOT NULL;

-- Note: about graph_attachment_id (an addition to the plan): if the poller crashes after saving an
-- attachment row and retries, the unique index stops the same PDF being added twice.
