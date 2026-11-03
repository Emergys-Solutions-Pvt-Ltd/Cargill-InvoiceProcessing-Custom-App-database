-- GENERATED from common/invoices/templates/procedures/usp_attachment.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo attachment functions - SJO invoice files (sjo.invoice_attachments)
--   usp_attachment_add              register a stored file on an invoice (optionally the primary PDF)
--   usp_attachment_get_by_id        metadata for the signed file download
--   usp_attachment_list_by_provider keyset page of attachments stored with one provider (S3 migration)
--   usp_attachment_set_storage      repoint an attachment after its file was copied
--   usp_attachment_storage_context  application code of an invoice (storage folder), no row = not found
-- Results use app.udt_attachment_result (application_code = sjo).
-- =====================================================================

-- Errors: CA404 invoice not found
CREATE OR REPLACE FUNCTION sjo.usp_attachment_add(
    p_invoice_code      text,
    p_file_name         text,
    p_title             text,
    p_category          text,
    p_mime_type         text,
    p_size_bytes        bigint,
    p_storage_path      text,
    p_is_primary        boolean DEFAULT false,
    p_storage_provider  text DEFAULT 'local',
    p_storage_bucket    text DEFAULT NULL,
    p_content_sha256    text DEFAULT NULL,
    p_storage_etag      text DEFAULT NULL
)
RETURNS app.udt_attachment_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    integer;
    v_app_code      text;
    v_result        app.udt_attachment_result;
BEGIN
    SELECT i.id, a.code INTO v_invoice_id, v_app_code
    FROM sjo.sjo_invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    IF p_is_primary THEN
        UPDATE sjo.invoice_attachments SET is_primary = false WHERE invoice_id = v_invoice_id AND is_primary;
    END IF;

    INSERT INTO sjo.invoice_attachments
        (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary,
         storage_provider, storage_bucket, content_sha256, storage_etag)
    VALUES
        (v_invoice_id, p_file_name, nullif(btrim(p_title), ''), coalesce(nullif(btrim(p_category), ''), 'Uploaded Document'),
         coalesce(p_mime_type, 'application/pdf'), p_size_bytes, p_storage_path, coalesce(p_is_primary, false),
         coalesce(p_storage_provider, 'local'), p_storage_bucket, p_content_sha256, left(p_storage_etag, 200))
    RETURNING id, invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary, uploaded_at, v_app_code,
              storage_provider, storage_bucket, content_sha256
    INTO v_result;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION sjo.usp_attachment_get_by_id(p_attachment_id integer)
RETURNS SETOF app.udt_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
           att.storage_path, att.is_primary, att.uploaded_at, 'sjo'::varchar,
           att.storage_provider, att.storage_bucket, att.content_sha256
    FROM sjo.invoice_attachments att
    WHERE att.id = p_attachment_id;
$$;

CREATE OR REPLACE FUNCTION sjo.usp_attachment_list_by_provider(
    p_storage_provider  text,
    p_after_id          integer DEFAULT 0,
    p_limit             integer DEFAULT 100
)
RETURNS SETOF app.udt_attachment_result
LANGUAGE sql
STABLE
AS $$
    SELECT att.id, att.invoice_id, att.file_name, att.title, att.category, att.mime_type, att.size_bytes,
           att.storage_path, att.is_primary, att.uploaded_at, 'sjo'::varchar,
           att.storage_provider, att.storage_bucket, att.content_sha256
    FROM sjo.invoice_attachments att
    WHERE att.storage_provider = p_storage_provider AND att.id > coalesce(p_after_id, 0)
    ORDER BY att.id
    LIMIT least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

-- Only moves a row that is still where the caller expects it, so concurrent / repeated migrations
-- cannot overwrite each other. Response: rows_affected 0 = already moved or not found.
CREATE OR REPLACE FUNCTION sjo.usp_attachment_set_storage(
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
    UPDATE sjo.invoice_attachments SET
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

CREATE OR REPLACE FUNCTION sjo.usp_attachment_storage_context(p_invoice_code text)
RETURNS SETOF app.udt_code_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(a.code)::app.udt_code_result
    FROM sjo.sjo_invoices i
    JOIN app.app_modules m  ON m.id = i.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE i.invoice_code = p_invoice_code;
$$;
