-- =====================================================================
-- app.usp_mailbox_attachment_add - poller: register a file saved from a mailbox email
-- (the backend has already written it under the storage root).
-- Request:  p_mailbox_email_id, p_graph_attachment_id, file metadata,
--           p_storage_path (relative to the storage root), storage provider metadata
-- Response: app.udt_mailbox_attachment_result; when the same Graph attachment was already
--           registered for this email, the existing row is returned (nothing is added)
-- Errors:   CA404 email not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_attachment_add(
    p_mailbox_email_id      integer,
    p_graph_attachment_id   text,
    p_file_name             text,
    p_mime_type             text,
    p_size_bytes            bigint,
    p_storage_path          text,
    p_is_inline             boolean DEFAULT false,
    p_storage_provider      text DEFAULT 'local',
    p_storage_bucket        text DEFAULT NULL,
    p_content_sha256        text DEFAULT NULL,
    p_storage_etag          text DEFAULT NULL
)
RETURNS app.udt_mailbox_attachment_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_result    app.udt_mailbox_attachment_result;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app.mailbox_emails WHERE id = p_mailbox_email_id) THEN
        RAISE EXCEPTION 'Email not found.' USING ERRCODE = 'CA404';
    END IF;

    SELECT id, mailbox_email_id, file_name, mime_type, size_bytes, storage_path, is_inline, created_at,
           storage_provider, storage_bucket, content_sha256, storage_etag
    INTO v_result
    FROM app.mailbox_email_attachments
    WHERE mailbox_email_id = p_mailbox_email_id AND graph_attachment_id = p_graph_attachment_id;

    IF v_result.id IS NULL THEN
        INSERT INTO app.mailbox_email_attachments
            (mailbox_email_id, graph_attachment_id, file_name, mime_type, size_bytes, storage_path, is_inline,
             storage_provider, storage_bucket, content_sha256, storage_etag)
        VALUES
            (p_mailbox_email_id, p_graph_attachment_id, left(p_file_name, 255),
             coalesce(p_mime_type, 'application/pdf'), p_size_bytes, p_storage_path, coalesce(p_is_inline, false),
             coalesce(p_storage_provider, 'local'), p_storage_bucket, p_content_sha256, left(p_storage_etag, 200))
        RETURNING id, mailbox_email_id, file_name, mime_type, size_bytes, storage_path, is_inline, created_at,
                  storage_provider, storage_bucket, content_sha256, storage_etag
        INTO v_result;
    END IF;

    RETURN v_result;
END;
$$;
