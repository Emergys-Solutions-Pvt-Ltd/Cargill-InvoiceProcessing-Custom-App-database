-- =====================================================================
-- app.usp_mailbox_get_by_id - one registered mailbox (Settings > Email Registration)
-- Request:  p_mailbox_id
-- Response: SETOF app.udt_mailbox_detail_result (no row when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_get_by_id(p_mailbox_id integer)
RETURNS SETOF app.udt_mailbox_detail_result
LANGUAGE sql
STABLE
AS $$
    SELECT r.*
    FROM app.mailboxes mb
    CROSS JOIN LATERAL app.ufn_mailbox_row(mb.id) r
    WHERE mb.id = p_mailbox_id;
$$;
