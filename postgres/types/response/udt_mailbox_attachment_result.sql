-- =====================================================================
-- app.udt_mailbox_attachment_result - RESPONSE type: a file saved from a mailbox email
-- Returned by: usp_mailbox_attachment_add (later also usp_mailbox_attachment_get_by_id)
-- storage_path is relative to the backend storage root; never expose it to browsers.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_attachment_result AS (
    id                  integer,
    mailbox_email_id    integer,
    file_name           varchar(255),
    mime_type           varchar(100),
    size_bytes          bigint,
    storage_path        varchar(500),
    is_inline           boolean,
    created_at          timestamptz(0),
    storage_provider    varchar(20),
    storage_bucket      varchar(255),
    content_sha256      char(64),
    storage_etag        varchar(200)
);
