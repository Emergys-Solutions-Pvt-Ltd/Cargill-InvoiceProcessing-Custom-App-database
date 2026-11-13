-- =====================================================================
-- app.usp_mailbox_attachments_done - poller: the attachment loop for one email has finished
-- Sets attachments_saved_at, so the email is not retried (gap G1).
-- Request:  p_mailbox_email_id,
--           p_error NULL  = every file was saved or skipped on purpose
--           p_error given = some files failed: status -> Failed, status_note = p_error
--                           (only while the email is still New; Ignored / Processed are kept)
-- Response: app.udt_row_count_result
-- Errors:   CA404 email not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_attachments_done(p_mailbox_email_id uuid, p_error text DEFAULT NULL)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows      integer;
BEGIN
    UPDATE app.mailbox_emails
    SET attachments_saved_at = now(),
        status      = CASE WHEN p_error IS NOT NULL AND status = 'New' THEN 'Failed' ELSE status END,
        status_note = CASE WHEN p_error IS NOT NULL THEN left(p_error, 1000) ELSE status_note END,
        updated_at  = now()
    WHERE id = p_mailbox_email_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Email not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
