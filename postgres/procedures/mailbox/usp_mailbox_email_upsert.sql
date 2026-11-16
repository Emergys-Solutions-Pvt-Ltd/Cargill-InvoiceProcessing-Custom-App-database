-- =====================================================================
-- app.usp_mailbox_email_upsert - poller: store one email read from Microsoft Graph
-- Request:  p_mailbox_id, Graph message fields; address lists comma separated
-- Response: app.udt_mailbox_email_result (is_new = false when the message was already stored;
--           the existing row is returned unchanged)
--           attachments_pending = has attachments and the attachment loop never finished for it

-- Errors:   CA404 mailbox not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_email_upsert(
    p_mailbox_id            uuid,
    p_graph_message_id      text,
    p_internet_message_id   text,
    p_from_name             text,
    p_from_address          text,
    p_to_addresses          text,
    p_cc_addresses          text,
    p_subject               text,
    p_body_text             text,
    p_received_at           timestamptz,
    p_has_attachments       boolean
)
RETURNS app.udt_mailbox_email_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_result    app.udt_mailbox_email_result;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM app.mailboxes WHERE id = p_mailbox_id) THEN
        RAISE EXCEPTION 'Mailbox not found.' USING ERRCODE = 'CA404';
    END IF;

    INSERT INTO app.mailbox_emails
        (mailbox_id, graph_message_id, internet_message_id, from_name, from_address,
         to_addresses, cc_addresses, subject, body_text, received_at, has_attachments)
    VALUES
        (p_mailbox_id, p_graph_message_id, left(p_internet_message_id, 500), left(p_from_name, 150), left(p_from_address, 255),
         left(nullif(p_to_addresses, ''), 1000), left(nullif(p_cc_addresses, ''), 1000),
         left(coalesce(p_subject, ''), 500), p_body_text, p_received_at, coalesce(p_has_attachments, false))
    ON CONFLICT (graph_message_id) DO NOTHING
    RETURNING id, mailbox_id, graph_message_id, subject, from_address, received_at, has_attachments, status, invoice_id, true,has_attachments  
    INTO v_result;

    IF v_result.id IS NULL THEN     -- already stored: return the existing row
        SELECT id, mailbox_id, graph_message_id, subject, from_address, received_at, has_attachments, status, invoice_id, false,has_attachments AND attachments_saved_at IS NULL
        INTO v_result
        FROM app.mailbox_emails
        WHERE graph_message_id = p_graph_message_id;
    END IF;

    RETURN v_result;
END;
$$;
