-- =====================================================================
-- {{S}}.invoice_attachments - {{APP}} invoice PDFs and supporting documents
-- Stored by the backend attachment storage service: 'local' = storage_path below STORAGE_DIR;
-- 's3' = object key storage_path in storage_bucket (layout <App>/<YYYY>/<Mon>/<file name>).
-- Checksum + ETag for integrity checks. Attachment ids are unique per app.
-- Depends on: {{S}}.{{T}}, {{S}}.invoice_source_emails
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS {{S}}.invoice_attachments (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_{{S}}_attachments PRIMARY KEY,
    invoice_id          uuid         NOT NULL CONSTRAINT fk_{{S}}_attachments_invoice REFERENCES {{S}}.{{T}} (id) ON DELETE CASCADE,
    file_name           varchar(255)    NOT NULL,
    title               varchar(255)    NULL,
    category            varchar(50)     NOT NULL,                   -- Invoice Document, Tax Document, Manifest
    mime_type           varchar(100)    NOT NULL DEFAULT 'application/pdf',
    size_bytes          bigint          NULL,
    storage_path        varchar(500)    NOT NULL,
    is_primary          boolean         NOT NULL DEFAULT false,
    uploaded_at         timestamptz(0)  NOT NULL DEFAULT now(),
    -- Attachments that arrived with the source email (NULL = uploaded by a user)
    source_email_id     uuid         NULL CONSTRAINT fk_{{S}}_attachments_source_email
                                             REFERENCES {{S}}.invoice_source_emails (id) ON DELETE SET NULL,
    storage_provider    varchar(20)     NOT NULL DEFAULT 'local',
    storage_bucket      varchar(255)    NULL,
    content_sha256      char(64)        NULL,
    storage_etag        varchar(200)    NULL,
    CONSTRAINT ck_{{S}}_attachments_provider
        CHECK (storage_provider IN ('local', 's3') AND (storage_provider = 'local' OR storage_bucket IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS ix_{{S}}_attachments_invoice ON {{S}}.invoice_attachments (invoice_id);
-- At most one primary PDF per invoice
CREATE UNIQUE INDEX IF NOT EXISTS ux_{{S}}_attachments_primary ON {{S}}.invoice_attachments (invoice_id) WHERE is_primary;
-- One attachment row per S3 object
CREATE UNIQUE INDEX IF NOT EXISTS ux_{{S}}_attachments_s3_object
    ON {{S}}.invoice_attachments (storage_bucket, storage_path) WHERE storage_provider = 's3';
-- Migration of local files to S3 pages through local rows
CREATE INDEX IF NOT EXISTS ix_{{S}}_attachments_provider ON {{S}}.invoice_attachments (storage_provider, id);
CREATE INDEX IF NOT EXISTS ix_{{S}}_attachments_source_email ON {{S}}.invoice_attachments (source_email_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
