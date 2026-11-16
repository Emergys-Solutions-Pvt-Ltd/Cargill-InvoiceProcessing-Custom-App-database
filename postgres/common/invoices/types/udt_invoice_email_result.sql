-- =====================================================================
-- app.udt_invoice_email_result - RESPONSE type: the email an invoice was received through
-- Element of udt_invoice_detail_result.source_email (NULL when the invoice has no source email)
-- attachments = array of app.udt_attachment_result that came with the email.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_email_result AS (
    id              uuid,
    message_id      varchar(255),
    from_name       varchar(150),
    from_address    varchar(255),
    to_addresses    varchar(1000),
    cc_addresses    varchar(1000),
    subject         varchar(500),
    body_text       text,
    received_at     timestamptz(0),
    attachments     jsonb
);
