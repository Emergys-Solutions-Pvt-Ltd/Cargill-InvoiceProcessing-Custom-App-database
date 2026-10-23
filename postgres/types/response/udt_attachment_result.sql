-- =====================================================================
-- app.udt_attachment_result - RESPONSE type: invoice attachment metadata
-- Returned by: usp_attachment_get_by_id; element type of udt_invoice_detail_result.attachments
-- storage_path is relative to the backend storage root; never expose it to browsers.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_attachment_result AS (
    id                  integer,
    invoice_id          integer,
    file_name           varchar(255),
    title               varchar(255),
    category            varchar(50),
    mime_type           varchar(100),
    size_bytes          bigint,
    storage_path        varchar(500),
    is_primary          boolean,
    uploaded_at         timestamptz(0),
    application_code    varchar(50)
);
