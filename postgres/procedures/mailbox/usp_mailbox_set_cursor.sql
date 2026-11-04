-- =====================================================================
-- app.usp_mailbox_set_cursor - poller: store the result of one poll of a mailbox
-- Request:  p_mailbox_id,
--           p_delta_link  the new Graph delta link (used only on success)
--           p_error NULL  = success: save p_delta_link, last_polled_at = now(), clear last_error
--           p_error given = failure: keep delta_link and last_polled_at, store the error
--           p_reset true  = delta link expired: set delta_link to NULL so the next poll does a full sync
-- Response: app.udt_row_count_result
-- Errors:   CA404 mailbox not found
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_set_cursor(
    p_mailbox_id    integer,
    p_delta_link    text,
    p_error         text,
    p_reset         boolean DEFAULT false
)
RETURNS app.udt_row_count_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows      integer;
BEGIN
    UPDATE app.mailboxes
    SET delta_link     = CASE WHEN p_reset THEN NULL
                              WHEN p_error IS NULL THEN p_delta_link
                              ELSE delta_link END,
        last_polled_at = CASE WHEN p_error IS NULL THEN now() ELSE last_polled_at END,
        last_error     = left(p_error, 1000)
    WHERE id = p_mailbox_id;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Mailbox not found.' USING ERRCODE = 'CA404';
    END IF;

    RETURN ROW(v_rows)::app.udt_row_count_result;
END;
$$;
