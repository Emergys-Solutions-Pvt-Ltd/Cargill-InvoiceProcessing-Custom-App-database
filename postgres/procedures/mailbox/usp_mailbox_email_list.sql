-- =====================================================================
-- app.usp_mailbox_email_list - application Inbox grid (received emails, newest first)
-- Request:  p_application_code (app.applications.code, e.g. GP; exact match) - only emails of mailboxes
--           whose module belongs to this application are listed,
--           p_status (NULL = all; else New, Processed, Ignored or Failed),
--           p_mailbox_id (NULL = all; a mailbox of another application returns no rows),
--           p_search (subject, from name or from address contains, case-insensitive),
--           p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app.udt_mailbox_email_list_result (paging columns on every row),
--           ordered received_at DESC, id DESC; attachment_count = non-inline attachments
-- Errors:   CA400 invalid page size, invalid status
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_mailbox_email_list(
    p_application_code  text,
    p_status            text    DEFAULT NULL,
    p_mailbox_id        uuid    DEFAULT NULL,
    p_search            text    DEFAULT NULL,
    p_page              integer DEFAULT 1,
    p_page_size         integer DEFAULT 10
)
RETURNS SETOF app.udt_mailbox_email_list_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_pattern text := app.ufn_like_contains(p_search);
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;
    IF p_status IS NOT NULL AND p_status NOT IN ('New', 'Processed', 'Ignored', 'Failed') THEN
        RAISE EXCEPTION 'Status must be New, Processed, Ignored or Failed.' USING ERRCODE = 'CA400';
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT e.id, e.mailbox_id, mb.address AS mailbox_address, m.slug AS module_slug, m.name AS module_name,
               e.from_name, e.from_address, e.subject, e.received_at, e.status, e.status_note, e.invoice_id,
               row_number() OVER (ORDER BY e.received_at DESC, e.id DESC) AS rn,
               count(*) OVER ()::integer AS total
        FROM app.mailbox_emails e
        JOIN app.mailboxes mb   ON mb.id = e.mailbox_id
        JOIN app.app_modules m  ON m.id = mb.module_id
        JOIN app.applications a ON a.id = m.application_id
        WHERE a.code = p_application_code
          AND (p_status IS NULL OR e.status = p_status)
          AND (p_mailbox_id IS NULL OR e.mailbox_id = p_mailbox_id)
          AND (v_pattern IS NULL
               OR e.subject ILIKE v_pattern
               OR e.from_name ILIKE v_pattern
               OR e.from_address ILIKE v_pattern)
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(coalesce(max(total), 0)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT x.id, x.mailbox_id, x.mailbox_address, x.module_slug, x.module_name,
           x.from_name, x.from_address, x.subject, x.received_at,
           (SELECT count(*)::integer
            FROM app.mailbox_email_attachments att
            WHERE att.mailbox_email_id = x.id AND NOT att.is_inline),
           x.status, x.status_note, x.invoice_id,
           x.total, pg.pages, pg.page, p_page_size
    FROM matches x
    CROSS JOIN paging pg
    WHERE x.rn BETWEEN (pg.page - 1) * p_page_size + 1 AND pg.page * p_page_size
    ORDER BY x.rn;
END;
$$;
