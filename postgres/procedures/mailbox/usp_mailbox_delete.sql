-- =====================================================================
-- app.usp_mailbox_delete - Settings > Email Registration "Delete"
-- Request:  p_mailbox_id
-- Response: app.udt_row_count_result
-- Behaviour: only a mailbox that never received an email can be deleted (D-013); otherwise the
--            admin sets it to Inactive. The row is locked first, so the poller cannot add an email
--            between the check and the delete (inserting an email waits for the lock).
-- Errors:   CA404 mailbox not found, CA409 the mailbox has received emails
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_delete(p_mailbox_id uuid)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows integer;
BEGIN
    PERFORM 1 FROM app.mailboxes WHERE id = p_mailbox_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mailbox not found.' USING ERRCODE = 'CA404';
    END IF;
    IF EXISTS (SELECT 1 FROM app.mailbox_emails WHERE mailbox_id = p_mailbox_id) THEN
        RAISE EXCEPTION 'This mailbox has received emails and can''t be deleted. Set it to Inactive instead.' USING ERRCODE = 'CA409';
    END IF;

    BEGIN
        DELETE FROM app.mailboxes WHERE id = p_mailbox_id;
        GET DIAGNOSTICS v_rows = ROW_COUNT;
    EXCEPTION
        WHEN foreign_key_violation THEN     -- fallback: app.mailbox_emails has no ON DELETE CASCADE
            RAISE EXCEPTION 'This mailbox has received emails and can''t be deleted. Set it to Inactive instead.' USING ERRCODE = 'CA409';
    END;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
