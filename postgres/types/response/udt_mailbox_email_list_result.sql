-- =====================================================================
-- app.udt_mailbox_email_list_result - RESPONSE type: one page of received emails (application Inbox)
-- plus paging metadata
-- Returned by: usp_mailbox_email_list. Paging columns repeat on every row; no rows = no matches.
-- attachment_count = non-inline attachments only. No body / to / cc (see udt_mailbox_email_detail_result).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_email_list_result AS (
    id                  integer,
    mailbox_id          integer,
    mailbox_address     varchar(255),
    module_slug         varchar(100),
    module_name         varchar(150),
    from_name           varchar(150),
    from_address        varchar(255),
    subject             varchar(500),
    received_at         timestamptz(0),
    attachment_count    integer,
    status              varchar(20),          -- New | Processed | Ignored | Failed
    status_note         varchar(1000),
    invoice_id          integer,              -- set when Processed (app-specific invoice id)
    total_items         integer,
    total_pages         integer,
    page                integer,
    page_size           integer
);
