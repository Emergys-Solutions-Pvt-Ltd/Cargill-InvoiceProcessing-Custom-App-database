-- =====================================================================
-- app.udt_mailbox_result - RESPONSE type: a mailbox the poller reads
-- Returned by: usp_mailbox_get_active
-- delta_link NULL = the next poll does a full sync of the folder.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_result AS (
    id              uuid,
    address         varchar(255),
    folder          varchar(255),
    module_id       uuid,
    delta_link      text,
    last_polled_at  timestamptz(0),
    last_error      varchar(1000)
);
