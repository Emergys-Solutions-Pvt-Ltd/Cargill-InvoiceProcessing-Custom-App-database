-- =====================================================================
-- app.udt_mailbox_option_result - RESPONSE type: a mailbox for the Inbox "Mailbox" filter
-- Returned by: usp_mailbox_list_for_application
-- No poll status / delta_link: users without the admin role see this list.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_mailbox_option_result AS (
    id              uuid,
    address         varchar(255),
    folder          varchar(255),
    module_slug     varchar(100),
    module_name     varchar(150)
);
