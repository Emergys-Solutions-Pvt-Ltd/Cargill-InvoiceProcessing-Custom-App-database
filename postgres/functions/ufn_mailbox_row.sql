-- =====================================================================
-- app.ufn_mailbox_row - builds app.udt_mailbox_detail_result for one registered mailbox
-- (module slug / name joined from app.app_modules). delta_link is never part of the result.
-- Shared by usp_mailbox_list / _get_by_id / _save so the shape is defined once.
-- Returns NULL when the mailbox does not exist.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_mailbox_row(p_mailbox_id integer)
RETURNS app.udt_mailbox_detail_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(
        mb.id, mb.address, mb.folder, mb.module_id, m.slug, m.name, mb.is_active,
        mb.last_polled_at, mb.last_error, mb.created_at, mb.updated_at
    )::app.udt_mailbox_detail_result
    FROM app.mailboxes mb
    JOIN app.app_modules m ON m.id = mb.module_id
    WHERE mb.id = p_mailbox_id;
$$;
