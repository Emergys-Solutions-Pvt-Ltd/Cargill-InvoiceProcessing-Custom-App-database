-- =====================================================================
-- app.usp_attachment_list_by_provider - page through attachments stored with one provider
-- (keyset paging by id), e.g. the local files still to copy to S3.
-- Request:  p_storage_provider (local | s3), p_after_id (0 = start), p_limit (1-500)
-- Response: SETOF app.udt_attachment_result ordered by id
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_attachment_list_by_provider(
    p_storage_provider  text,
    p_after_id          integer DEFAULT 0,
    p_limit             integer DEFAULT 100
)
RETURNS SETOF app.udt_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
           att.storage_path, att.is_primary, att.uploaded_at, a.code,
           att.storage_provider, att.storage_bucket, att.content_sha256
    FROM app.invoice_attachments att
    JOIN app.invoices i     ON i.id = att.invoice_id
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE att.storage_provider = p_storage_provider AND att.id > coalesce(p_after_id, 0)
    ORDER BY att.id
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 500);
$$;
