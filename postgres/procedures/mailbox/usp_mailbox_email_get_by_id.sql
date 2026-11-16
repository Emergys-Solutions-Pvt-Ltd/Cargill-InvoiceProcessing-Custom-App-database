-- =====================================================================
-- app.usp_mailbox_email_get_by_id - one received email for the application Inbox detail page
-- Request:  p_application_code (app.applications.code; exact match), p_email_id
-- Response: SETOF app.udt_mailbox_email_detail_result; no row when the email does not exist
--           or its mailbox's module belongs to another application.
--           attachment_count = non-inline attachments
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_email_get_by_id(p_application_code text, p_email_id uuid)
RETURNS SETOF app.udt_mailbox_email_detail_result
LANGUAGE sql
STABLE
AS $$
    SELECT e.id, e.mailbox_id, mb.address, m.slug, m.name,
           e.from_name, e.from_address, e.to_addresses, e.cc_addresses,
           e.subject, e.body_text, e.received_at,
           (SELECT count(*)::integer
            FROM app.mailbox_email_attachments att
            WHERE att.mailbox_email_id = e.id AND NOT att.is_inline),
           e.status, e.status_note, e.invoice_id, e.created_at, e.updated_at
    FROM app.mailbox_emails e
    JOIN app.mailboxes mb   ON mb.id = e.mailbox_id
    JOIN app.app_modules m  ON m.id = mb.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE e.id = p_email_id
      AND a.code = p_application_code;
$$;
