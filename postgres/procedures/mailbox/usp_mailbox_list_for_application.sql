-- =====================================================================
-- app.usp_mailbox_list_for_application - mailboxes for the application Inbox "Mailbox" filter
-- (non-admin users cannot use usp_mailbox_list / /api/mailboxes)
-- Request:  p_application_code (app.applications.code; exact match)
-- Response: SETOF app.udt_mailbox_option_result - every mailbox (active and inactive) whose module
--           belongs to the application, ordered lower(address), lower(folder), id
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_list_for_application(p_application_code text)
RETURNS SETOF app.udt_mailbox_option_result
LANGUAGE sql
STABLE
AS $$
    SELECT mb.id, mb.address, mb.folder, m.slug, m.name
    FROM app.mailboxes mb
    JOIN app.app_modules m  ON m.id = mb.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE a.code = p_application_code
    ORDER BY lower(mb.address), lower(mb.folder), mb.id;
$$;
