-- =====================================================================
-- app.usp_mailbox_email_set_status - application Inbox "Ignore" / "Move back to New"
-- Request:  p_application_code (app.applications.code; exact match), p_email_id,
--           p_status ('New' or 'Ignored'), p_note (optional, trimmed, max 1000 characters)
-- Response: app.udt_mailbox_email_detail_result (the email after the change)
-- Behaviour: allowed New -> Ignored, Failed -> Ignored, Ignored -> New. Setting the current status
--            again changes nothing (also not the note) and returns the row.
--            Ignored: status_note = p_note when given, otherwise the current note is kept.
--            New:     status_note = p_note (NULL when not given).
--            The email row is locked FOR UPDATE; updated_at = now() on a change.
-- Errors:   CA400 status not New / Ignored, note too long
--           CA404 email not found or it belongs to another application
--           CA409 the email is Processed or linked to an invoice; Failed -> New
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_email_set_status(
    p_application_code  text,
    p_email_id          uuid,
    p_status            text,
    p_note              text DEFAULT NULL
)
RETURNS app.udt_mailbox_email_detail_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_note          text := nullif(btrim(p_note), '');
    v_current       text;
    v_invoice_id    uuid;
    v_result        app.udt_mailbox_email_detail_result;
BEGIN
    IF p_status IS NULL OR p_status NOT IN ('New', 'Ignored') THEN
        RAISE EXCEPTION 'Status must be New or Ignored.' USING ERRCODE = 'CA400';
    END IF;
    IF length(v_note) > 1000 THEN
        RAISE EXCEPTION 'Note must be at most 1000 characters.' USING ERRCODE = 'CA400';
    END IF;

    SELECT e.status, e.invoice_id
    INTO v_current, v_invoice_id
    FROM app.mailbox_emails e
    JOIN app.mailboxes mb   ON mb.id = e.mailbox_id
    JOIN app.app_modules m  ON m.id = mb.module_id
    JOIN app.applications a ON a.id = m.application_id
    WHERE e.id = p_email_id
      AND a.code = p_application_code
    FOR UPDATE OF e;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Email not found.' USING ERRCODE = 'CA404';
    END IF;

    IF v_current = 'Processed' OR v_invoice_id IS NOT NULL THEN
        RAISE EXCEPTION 'This email is linked to an invoice and can''t be changed.' USING ERRCODE = 'CA409';
    END IF;

    IF v_current IS DISTINCT FROM p_status THEN
        IF v_current = 'Failed' AND p_status = 'New' THEN
            RAISE EXCEPTION 'A failed email can only be ignored.' USING ERRCODE = 'CA409';
        END IF;

        UPDATE app.mailbox_emails
           SET status      = p_status,
               status_note = CASE WHEN p_status = 'Ignored' THEN coalesce(v_note, status_note) ELSE v_note END,
               updated_at  = now()
         WHERE id = p_email_id;
    END IF;

    SELECT * INTO v_result FROM app.usp_mailbox_email_get_by_id(p_application_code, p_email_id);
    RETURN v_result;
END;
$$;
