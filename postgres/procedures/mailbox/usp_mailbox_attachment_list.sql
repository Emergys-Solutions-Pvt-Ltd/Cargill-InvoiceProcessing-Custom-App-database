-- =====================================================================
-- app.usp_mailbox_attachment_list - files of one received email (Inbox detail page)
-- Request:  p_email_id
-- Response: SETOF app.udt_mailbox_attachment_result, non-inline attachments only, ordered by id;
--           no rows when the email has none or does not exist.
-- Not scoped to an application: the backend first checks the email with usp_mailbox_email_get_by_id.
-- storage_path is relative to the backend storage root; never expose it to browsers.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_attachment_list(p_email_id uuid)
RETURNS SETOF app.udt_mailbox_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, mailbox_email_id, file_name, mime_type, size_bytes, storage_path, is_inline, created_at,
           storage_provider, storage_bucket, content_sha256, storage_etag
    FROM app.mailbox_email_attachments
    WHERE mailbox_email_id = p_email_id
      AND NOT is_inline
    ORDER BY id;
$$;
