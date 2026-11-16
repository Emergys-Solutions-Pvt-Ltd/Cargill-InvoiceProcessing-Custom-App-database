-- =====================================================================
-- app.udt_mailbox_email_detail_result - RESPONSE type: one received email for the Inbox detail page
-- Returned by: usp_mailbox_email_get_by_id, usp_mailbox_email_set_status
-- to_addresses / cc_addresses are comma separated; body_text is plain text only.
-- attachment_count = non-inline attachments only.
-- The poller keeps using udt_mailbox_email_result; this type is for the Inbox screens.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_email_detail_result AS (
    id                  integer,
    mailbox_id          integer,
    mailbox_address     varchar(255),
    module_slug         varchar(100),
    module_name         varchar(150),
    from_name           varchar(150),
    from_address        varchar(255),
    to_addresses        varchar(1000),
    cc_addresses        varchar(1000),
    subject             varchar(500),
    body_text           text,
    received_at         timestamptz(0),
    attachment_count    integer,
    status              varchar(20),          -- New | Processed | Ignored | Failed
    status_note         varchar(1000),
    invoice_id          integer,
    created_at          timestamptz(0),
    updated_at          timestamptz(0)
);
