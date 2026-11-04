-- =====================================================================
-- app.udt_mailbox_email_result - RESPONSE type: one stored mailbox email (no body)
-- Returned by: usp_mailbox_email_upsert
-- is_new = true when this call inserted the row; false when it already existed.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- attachments_pending = true when the email has attachments that were never fully processed (G1 retry).

-- =====================================================================
CREATE TYPE app.udt_mailbox_email_result AS (
    id                  integer,
    mailbox_id          integer,
    graph_message_id    varchar(500),
    subject             varchar(500),
    from_address        varchar(255),
    received_at         timestamptz(0),
    has_attachments     boolean,
    status              varchar(20),
    invoice_id          integer,
    is_new              boolean,
    attachments_pending boolean
);
