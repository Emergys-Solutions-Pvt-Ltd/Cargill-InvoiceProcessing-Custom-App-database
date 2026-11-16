-- =====================================================================
-- app.udt_mailbox_detail_result - RESPONSE type: one registered mailbox for the Settings screen
-- Returned by: ufn_mailbox_row, usp_mailbox_get_by_id, usp_mailbox_save
-- module_slug / module_name come from app.app_modules via module_id.
-- delta_link (the Graph cursor) is never part of this type; the poller uses udt_mailbox_result.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_detail_result AS (
    id              uuid,
    address         varchar(255),
    folder          varchar(255),
    module_id       uuid,
    module_slug     varchar(100),
    module_name     varchar(150),
    is_active       boolean,
    last_polled_at  timestamptz(0),       -- NULL = not polled yet (also after an address / folder change)
    last_error      varchar(1000),
    created_at      timestamptz(0),
    updated_at      timestamptz(0)
);
