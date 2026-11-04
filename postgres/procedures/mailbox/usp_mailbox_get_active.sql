-- =====================================================================
-- app.usp_mailbox_get_active - poller: the mailboxes to read on this run
-- Request:  (none)
-- Response: SETOF app.udt_mailbox_result, only is_active rows, in id order
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_get_active()
RETURNS SETOF app.udt_mailbox_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, address, folder, module_id, delta_link, last_polled_at, last_error
    FROM app.mailboxes
    WHERE is_active
    ORDER BY id;
$$;
