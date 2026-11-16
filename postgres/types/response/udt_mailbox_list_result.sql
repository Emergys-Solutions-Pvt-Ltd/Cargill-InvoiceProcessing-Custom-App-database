-- =====================================================================
-- app.udt_mailbox_list_result - RESPONSE type: one page of registered mailboxes plus paging metadata
-- Returned by: usp_mailbox_list. Same columns as udt_mailbox_detail_result; paging columns repeat
-- on every row; no rows = no matches. delta_link is never part of this type.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_list_result AS (
    id              integer,
    address         varchar(255),
    folder          varchar(255),
    module_id       integer,
    module_slug     varchar(100),
    module_name     varchar(150),
    is_active       boolean,
    last_polled_at  timestamptz(0),
    last_error      varchar(1000),
    created_at      timestamptz(0),
    updated_at      timestamptz(0),
    total_items     integer,
    total_pages     integer,
    page            integer,
    page_size       integer
);
