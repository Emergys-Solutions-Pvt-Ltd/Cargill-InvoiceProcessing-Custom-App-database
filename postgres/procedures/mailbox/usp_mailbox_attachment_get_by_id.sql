-- =====================================================================
-- app.usp_mailbox_attachment_get_by_id - one file saved from a mailbox email (signed file download)
-- Request:  p_attachment_id
-- Response: SETOF app.udt_mailbox_attachment_result; no row when not found
-- Not scoped to an application: the backend only reaches it through a signed URL it issued.
-- storage_path is relative to the backend storage root; never expose it to browsers.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_attachment_get_by_id(p_attachment_id integer)
RETURNS SETOF app.udt_mailbox_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, mailbox_email_id, file_name, mime_type, size_bytes, storage_path, is_inline, created_at,
           storage_provider, storage_bucket, content_sha256, storage_etag
    FROM app.mailbox_email_attachments
    WHERE id = p_attachment_id;
$$;
