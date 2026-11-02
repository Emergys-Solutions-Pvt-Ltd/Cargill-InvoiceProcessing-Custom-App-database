-- =====================================================================
-- app.usp_attachment_set_storage - point an attachment at its new location after the file was
-- copied (e.g. local -> S3 migration). Only moves a row that is still where the caller expects it,
-- so concurrent / repeated migrations cannot overwrite each other.
-- Request:  p_attachment_id, p_expected_provider, new provider / bucket / path, p_content_sha256, p_storage_etag
-- Response: app.udt_row_count_result (0 = the row had already moved or does not exist)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_attachment_set_storage(
    p_attachment_id     integer,
    p_expected_provider text,
    p_storage_provider  text,
    p_storage_bucket    text,
    p_storage_path      text,
    p_content_sha256    text DEFAULT NULL,
    p_storage_etag      text DEFAULT NULL
)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    UPDATE app.invoice_attachments SET
        storage_provider = p_storage_provider,
        storage_bucket   = p_storage_bucket,
        storage_path     = p_storage_path,
        content_sha256   = coalesce(p_content_sha256, content_sha256),
        storage_etag     = left(p_storage_etag, 200)
    WHERE id = p_attachment_id AND storage_provider = p_expected_provider;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
