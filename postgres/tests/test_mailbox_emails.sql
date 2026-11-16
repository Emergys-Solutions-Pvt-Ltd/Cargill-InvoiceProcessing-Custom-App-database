-- =====================================================================
-- Database tests for the application Inbox functions (Feature: email-inbox, D-023):
-- usp_mailbox_email_list / _get_by_id / _set_status, usp_mailbox_attachment_list / _get_by_id,
-- usp_mailbox_list_for_application.
-- Runs inside one transaction and ROLLS BACK: safe on a shared database.
--   psql "<connection>" -v ON_ERROR_STOP=1 -f database/postgres/tests/test_mailbox_emails.sql
-- Each block uses ASSERT; the first failure aborts the script with a message.
-- Creates its own test applications, modules and mailboxes (codes ZZINB / ZZINB2), so it does not
-- need seed.sql. Emails via usp_mailbox_email_upsert, attachments via usp_mailbox_attachment_add.
-- Covers: 1 scope per application, 2 status filter, 3 mailbox filter, 4 search, 5 order / paging /
-- row content / attachment_count, 6 detail, 7 status changes and note rules, 8 attachments,
-- 9 mailbox options per application.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

CREATE TEMP TABLE t_ctx (k text PRIMARY KEY, v text) ON COMMIT DROP;

-- ---- Setup ----
-- Application ZZINB: module A (mailboxes "2/inbox" and "2/Archive"), module B (mailbox "1/inbox", inactive)
-- Application ZZINB2: module X (mailbox "3/inbox")
-- Emails (T = 2026-01-01 10:00 UTC):
--   e1  A 2/inbox    T+1h  Alice Vendor <alice@vendor.example>   'ZZINB Invoice 100'  New, 2 PDFs + 1 inline
--   e2  B 1/inbox    T+2h  Bob Supplier <bob@supplier.example>   'ZZINB Statement'    Failed ('Download failed')
--   e3  A 2/inbox    T+3h  Carol <carol@vendor.example>          'ZZINB 50%_off'      New
--   e4  A 2/Archive  T+3h  <dave@other.example> (no name)        'ZZINB Reminder'     New (same time as e3, higher id)
--   e5  A 2/inbox    T+4h  Erin <erin@vendor.example>            'ZZINB Paid'         Processed, invoice_id 123
--   ex  X 3/inbox    T+5h  Alice Vendor <alice@vendor.example>   'ZZINB Other app'    New (other application)
DO $$
DECLARE
    v_t     timestamptz := '2026-01-01 10:00:00+00';
    v_app   integer;
    v_app2  integer;
    v_a     integer;
    v_a2    integer;
    v_b     integer;
    v_x     integer;
    v_e1    integer;
    v_e2    integer;
    v_e3    integer;
    v_e4    integer;
    v_e5    integer;
    v_ex    integer;
    v_att1  integer;
BEGIN
    INSERT INTO app.applications (code, name, description) VALUES ('ZZINB', 'ZZ Inbox Test', 'test only')
    RETURNING id INTO v_app;
    INSERT INTO app.applications (code, name, description) VALUES ('ZZINB2', 'ZZ Inbox Test 2', 'test only')
    RETURNING id INTO v_app2;
    INSERT INTO app.app_modules (application_id, slug, name, invoice_prefix) VALUES
        (v_app,  'zz-inb-a', 'ZZ Inbox Module A', 'ZZINBA'),
        (v_app,  'zz-inb-b', 'ZZ Inbox Module B', 'ZZINBB'),
        (v_app2, 'zz-inb-x', 'ZZ Inbox Module X', 'ZZINBX');

    v_a  := (app.usp_mailbox_save(NULL, 'zz-inb-mailbox-2@example.com', 'inbox',   'zz-inb-a')).id;
    v_a2 := (app.usp_mailbox_save(NULL, 'zz-inb-mailbox-2@example.com', 'Archive', 'zz-inb-a')).id;
    v_b  := (app.usp_mailbox_save(NULL, 'zz-inb-mailbox-1@example.com', 'inbox',   'zz-inb-b', false)).id;
    v_x  := (app.usp_mailbox_save(NULL, 'zz-inb-mailbox-3@example.com', 'inbox',   'zz-inb-x')).id;

    v_e1 := (app.usp_mailbox_email_upsert(v_a, 'zz-inb-test-graph-1', NULL, 'Alice Vendor', 'alice@vendor.example',
             'ap@example.com, ap2@example.com', 'cc@example.com', 'ZZINB Invoice 100', 'Plain body', v_t + interval '1 hour', true)).id;
    v_e2 := (app.usp_mailbox_email_upsert(v_b, 'zz-inb-test-graph-2', NULL, 'Bob Supplier', 'bob@supplier.example',
             NULL, NULL, 'ZZINB Statement', 'body', v_t + interval '2 hours', true)).id;
    v_e3 := (app.usp_mailbox_email_upsert(v_a, 'zz-inb-test-graph-3', NULL, 'Carol', 'carol@vendor.example',
             NULL, NULL, 'ZZINB 50%_off', 'body', v_t + interval '3 hours', false)).id;
    v_e4 := (app.usp_mailbox_email_upsert(v_a2, 'zz-inb-test-graph-4', NULL, NULL, 'dave@other.example',
             NULL, NULL, 'ZZINB Reminder', 'body', v_t + interval '3 hours', false)).id;
    v_e5 := (app.usp_mailbox_email_upsert(v_a, 'zz-inb-test-graph-5', NULL, 'Erin', 'erin@vendor.example',
             NULL, NULL, 'ZZINB Paid', 'body', v_t + interval '4 hours', false)).id;
    v_ex := (app.usp_mailbox_email_upsert(v_x, 'zz-inb-test-graph-6', NULL, 'Alice Vendor', 'alice@vendor.example',
             NULL, NULL, 'ZZINB Other app', 'body', v_t + interval '5 hours', false)).id;

    v_att1 := (app.usp_mailbox_attachment_add(v_e1, 'zz-inb-att-1', 'invoice.pdf', 'application/pdf', 1000,
               'inbox/2026/01/zz/a.pdf')).id;
    PERFORM app.usp_mailbox_attachment_add(v_e1, 'zz-inb-att-2', 'second.pdf', 'application/pdf', 2000,
               'inbox/2026/01/zz/b.pdf');
    PERFORM app.usp_mailbox_attachment_add(v_e1, 'zz-inb-att-3', 'logo.png', 'image/png', 10,
               'inbox/2026/01/zz/c.png', true);

    PERFORM app.usp_mailbox_attachments_done(v_e2, 'Download failed');     -- New -> Failed
    UPDATE app.mailbox_emails SET status = 'Processed', invoice_id = 123 WHERE id = v_e5;

    INSERT INTO t_ctx VALUES
        ('a', v_a::text), ('a2', v_a2::text), ('b', v_b::text), ('x', v_x::text),
        ('e1', v_e1::text), ('e2', v_e2::text), ('e3', v_e3::text), ('e4', v_e4::text), ('e5', v_e5::text),
        ('ex', v_ex::text), ('att1', v_att1::text);

    ASSERT (SELECT status FROM app.mailbox_emails WHERE id = v_e2) = 'Failed', 'setup: e2 Failed';
END $$;

-- ---- 1. Scope per application ----
DO $$
DECLARE
    v_ex    integer := (SELECT v::integer FROM t_ctx WHERE k = 'ex');
    v_x     integer := (SELECT v::integer FROM t_ctx WHERE k = 'x');
    v_order text;
    v_msg   text;
BEGIN
    SELECT string_agg(subject, ',') INTO v_order FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 1, 100);
    ASSERT v_order = 'ZZINB Paid,ZZINB Reminder,ZZINB 50%_off,ZZINB Statement,ZZINB Invoice 100',
        'list ZZINB (newest first, other application excluded): ' || coalesce(v_order, '<none>');
    ASSERT (SELECT total_items FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 1, 100) LIMIT 1) = 5, 'total_items';

    SELECT string_agg(subject, ',') INTO v_order FROM app.usp_mailbox_email_list('ZZINB2');
    ASSERT v_order = 'ZZINB Other app', 'list ZZINB2: ' || coalesce(v_order, '<none>');
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_list('ZZ-NO-SUCH-APP')), 'unknown application: no rows';

    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_get_by_id('ZZINB', v_ex)), 'get: other application -> no row';
    ASSERT EXISTS (SELECT 1 FROM app.usp_mailbox_email_get_by_id('ZZINB2', v_ex)), 'get: own application -> row';

    BEGIN
        PERFORM app.usp_mailbox_email_set_status('ZZINB', v_ex, 'Ignored');
        ASSERT false, 'expected CA404 for set_status on an email of another application';
    EXCEPTION WHEN SQLSTATE 'CA404' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'Email not found.', 'CA404 message: ' || coalesce(v_msg, '<none>');
    ASSERT (SELECT status FROM app.mailbox_emails WHERE id = v_ex) = 'New', 'other application email unchanged';

    v_msg := NULL;
    BEGIN
        PERFORM app.usp_mailbox_email_set_status('ZZINB', -1, 'Ignored');
        ASSERT false, 'expected CA404 for set_status on an unknown email';
    EXCEPTION WHEN SQLSTATE 'CA404' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'Email not found.', 'CA404 message unknown id';

    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_list('ZZINB', NULL, v_x)),
        'mailbox filter with a mailbox of another application: no rows';
END $$;

-- ---- 2. Status filter ----
DO $$
DECLARE
    v_order text;
    v_msg   text;
    v_case  text;
BEGIN
    SELECT string_agg(subject, ',') INTO v_order FROM app.usp_mailbox_email_list('ZZINB', 'New', NULL, NULL, 1, 100);
    ASSERT v_order = 'ZZINB Reminder,ZZINB 50%_off,ZZINB Invoice 100', 'status New: ' || coalesce(v_order, '<none>');
    ASSERT (SELECT string_agg(subject || ':' || status_note, ',') FROM app.usp_mailbox_email_list('ZZINB', 'Failed'))
        = 'ZZINB Statement:Download failed', 'status Failed with note';
    ASSERT (SELECT string_agg(subject || ':' || invoice_id, ',') FROM app.usp_mailbox_email_list('ZZINB', 'Processed'))
        = 'ZZINB Paid:123', 'status Processed with invoice_id';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_list('ZZINB', 'Ignored')), 'status Ignored: none yet';

    FOR v_case IN SELECT unnest(ARRAY['Bogus', 'new', ''])
    LOOP
        v_msg := NULL;
        BEGIN
            PERFORM app.usp_mailbox_email_list('ZZINB', v_case);
            ASSERT false, 'expected CA400 for status ''' || v_case || '''';
        EXCEPTION WHEN SQLSTATE 'CA400' THEN v_msg := SQLERRM;
        END;
        ASSERT v_msg = 'Status must be New, Processed, Ignored or Failed.', 'status CA400 message: ' || coalesce(v_msg, '<none>');
    END LOOP;
END $$;

-- ---- 3. Mailbox filter ----
DO $$
DECLARE
    v_a     integer := (SELECT v::integer FROM t_ctx WHERE k = 'a');
    v_b     integer := (SELECT v::integer FROM t_ctx WHERE k = 'b');
BEGIN
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, v_a))
        = 'ZZINB Paid,ZZINB 50%_off,ZZINB Invoice 100', 'mailbox A filter';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, v_b))
        = 'ZZINB Statement', 'mailbox B filter (inactive mailbox still listed)';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', 'New', v_a))
        = 'ZZINB 50%_off,ZZINB Invoice 100', 'mailbox + status filter';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_list('ZZINB', NULL, -1)), 'unknown mailbox: no rows';
END $$;

-- ---- 4. Search (subject, from name, from address; case-insensitive; literal % and _) ----
DO $$
BEGIN
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'ALICE'))
        = 'ZZINB Invoice 100', 'search from name (other application excluded)';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'supplier.EXAMPLE'))
        = 'ZZINB Statement', 'search from address';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'reminder'))
        = 'ZZINB Reminder', 'search subject';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'other.example'))
        = 'ZZINB Reminder', 'search from address when from name is NULL';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, '%_o'))
        = 'ZZINB 50%_off', 'search % and _ are literal';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'zzin_')), 'search _ is not a wildcard';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', 'New', NULL, 'vendor'))
        = 'ZZINB 50%_off,ZZINB Invoice 100', 'search + status filter';
    ASSERT (SELECT count(*) FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, '   ')) = 5, 'blank search = no filter';
END $$;

-- ---- 5. Order, paging, row content, attachment_count ----
DO $$
DECLARE
    v_a     integer := (SELECT v::integer FROM t_ctx WHERE k = 'a');
    v_e1    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e1');
    v_row   app.udt_mailbox_email_list_result;
    v_msg   text;
BEGIN
    -- e3 and e4 have the same received_at: higher id first
    ASSERT (SELECT string_agg(subject || ':' || page || '/' || total_pages || ':' || total_items || ':' || page_size, ',')
            FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 2, 2))
        = 'ZZINB 50%_off:2/3:5:2,ZZINB Statement:2/3:5:2', 'page 2 of 3 (page size 2)';
    ASSERT (SELECT string_agg(subject || ':' || page, ',') FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 99, 2))
        = 'ZZINB Invoice 100:3', 'page past the end clamped to the last page';
    ASSERT (SELECT min(page) FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 0, 2)) = 1, 'page 0 clamped to 1';
    ASSERT (SELECT min(page) FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, NULL, 2)) = 1, 'page NULL = 1';
    ASSERT (SELECT count(*) FROM app.usp_mailbox_email_list('ZZINB')) = 5, 'default page size 10';

    BEGIN
        PERFORM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 1, 0);
        ASSERT false, 'expected CA400 for page size 0';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'PageSize must be between 1 and 100.', 'page size CA400 message';
    BEGIN
        PERFORM app.usp_mailbox_email_list('ZZINB', NULL, NULL, NULL, 1, 101);
        ASSERT false, 'expected CA400 for page size 101';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;

    SELECT * INTO v_row FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'Invoice 100');
    ASSERT v_row.id = v_e1 AND v_row.mailbox_id = v_a AND v_row.mailbox_address = 'zz-inb-mailbox-2@example.com',
        'row: id / mailbox';
    ASSERT v_row.module_slug = 'zz-inb-a' AND v_row.module_name = 'ZZ Inbox Module A', 'row: module slug / name';
    ASSERT v_row.from_name = 'Alice Vendor' AND v_row.from_address = 'alice@vendor.example'
       AND v_row.received_at = '2026-01-01 11:00:00+00'::timestamptz, 'row: from / received_at';
    ASSERT v_row.attachment_count = 2, 'attachment_count ignores the inline attachment: ' || v_row.attachment_count;
    ASSERT v_row.status = 'New' AND v_row.status_note IS NULL AND v_row.invoice_id IS NULL, 'row: status';
    ASSERT (SELECT attachment_count FROM app.usp_mailbox_email_list('ZZINB', NULL, NULL, 'Statement')) = 0,
        'attachment_count 0 when nothing was saved';
END $$;

-- ---- 6. Detail ----
DO $$
DECLARE
    v_e1    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e1');
    v_d     app.udt_mailbox_email_detail_result;
BEGIN
    SELECT * INTO v_d FROM app.usp_mailbox_email_get_by_id('ZZINB', v_e1);
    ASSERT v_d.id = v_e1 AND v_d.mailbox_address = 'zz-inb-mailbox-2@example.com' AND v_d.module_slug = 'zz-inb-a'
       AND v_d.module_name = 'ZZ Inbox Module A', 'detail: mailbox / module';
    ASSERT v_d.to_addresses = 'ap@example.com, ap2@example.com' AND v_d.cc_addresses = 'cc@example.com', 'detail: to / cc';
    ASSERT v_d.subject = 'ZZINB Invoice 100' AND v_d.body_text = 'Plain body', 'detail: subject / body';
    ASSERT v_d.attachment_count = 2 AND v_d.status = 'New' AND v_d.created_at IS NOT NULL AND v_d.updated_at IS NOT NULL,
        'detail: attachment_count / status / timestamps';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_email_get_by_id('ZZINB', -1)), 'detail: unknown id -> no row';
END $$;

-- ---- 7. Status changes and note rules ----
DO $$
DECLARE
    v_e1    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e1');
    v_e2    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e2');
    v_e3    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e3');
    v_e5    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e5');
    v_old   timestamptz := '2026-01-01 00:00:00+00';
    v_d     app.udt_mailbox_email_detail_result;
    v_msg   text;
    v_case  text;
BEGIN
    -- New -> Ignored with a note (trimmed); updated_at set
    UPDATE app.mailbox_emails SET updated_at = v_old WHERE id = v_e1;
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'Ignored', '  Duplicate of an earlier email  ');
    ASSERT v_d.id = v_e1 AND v_d.status = 'Ignored' AND v_d.status_note = 'Duplicate of an earlier email',
        'New -> Ignored with trimmed note';
    ASSERT v_d.updated_at > v_old AND v_d.attachment_count = 2 AND v_d.module_slug = 'zz-inb-a', 'returns the full detail row';
    ASSERT (SELECT string_agg(subject, ',') FROM app.usp_mailbox_email_list('ZZINB', 'Ignored')) = 'ZZINB Invoice 100',
        'Ignored email listed under Ignored';

    -- Same status again: no-op (note and updated_at unchanged), still returns the row
    UPDATE app.mailbox_emails SET updated_at = v_old WHERE id = v_e1;
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'Ignored', 'another note');
    ASSERT v_d.id = v_e1 AND v_d.status = 'Ignored' AND v_d.status_note = 'Duplicate of an earlier email'
       AND v_d.updated_at = v_old, 'Ignored -> Ignored is a no-op';

    -- Ignored -> New without a note: note cleared
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'New');
    ASSERT v_d.status = 'New' AND v_d.status_note IS NULL, 'Ignored -> New clears the note';

    -- New -> Ignored without a note keeps the current (NULL) note
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'Ignored', NULL);
    ASSERT v_d.status = 'Ignored' AND v_d.status_note IS NULL, 'New -> Ignored without note';

    -- Ignored -> New with a note: note stored
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'New', ' Restored by user ');
    ASSERT v_d.status = 'New' AND v_d.status_note = 'Restored by user', 'Ignored -> New with note';

    -- New -> Ignored with a blank note keeps the current note
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'Ignored', '   ');
    ASSERT v_d.status = 'Ignored' AND v_d.status_note = 'Restored by user', 'New -> Ignored, blank note keeps current note';

    -- Ignored -> New with a blank note: note NULL
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e1, 'New', '   ');
    ASSERT v_d.status = 'New' AND v_d.status_note IS NULL, 'Ignored -> New, blank note = NULL';

    -- New -> New: no-op, returns the row
    UPDATE app.mailbox_emails SET updated_at = v_old WHERE id = v_e3;
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e3, 'New');
    ASSERT v_d.id = v_e3 AND v_d.status = 'New' AND v_d.updated_at = v_old, 'New -> New is a no-op';

    -- Failed -> New: CA409
    BEGIN
        PERFORM app.usp_mailbox_email_set_status('ZZINB', v_e2, 'New');
        ASSERT false, 'expected CA409 for Failed -> New';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'A failed email can only be ignored.', 'Failed -> New message: ' || coalesce(v_msg, '<none>');
    ASSERT (SELECT status FROM app.mailbox_emails WHERE id = v_e2) = 'Failed', 'Failed email unchanged';

    -- Failed -> Ignored without a note keeps the failure note
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e2, 'Ignored');
    ASSERT v_d.status = 'Ignored' AND v_d.status_note = 'Download failed', 'Failed -> Ignored keeps the current note';

    -- Processed -> Ignored / New: CA409
    FOR v_case IN SELECT unnest(ARRAY['Ignored', 'New'])
    LOOP
        v_msg := NULL;
        BEGIN
            PERFORM app.usp_mailbox_email_set_status('ZZINB', v_e5, v_case);
            ASSERT false, 'expected CA409 for Processed -> ' || v_case;
        EXCEPTION WHEN SQLSTATE 'CA409' THEN v_msg := SQLERRM;
        END;
        ASSERT v_msg = 'This email is linked to an invoice and can''t be changed.',
            'Processed -> ' || v_case || ' message: ' || coalesce(v_msg, '<none>');
    END LOOP;
    ASSERT (SELECT status FROM app.mailbox_emails WHERE id = v_e5) = 'Processed', 'Processed email unchanged';

    -- New email with an invoice_id: CA409
    UPDATE app.mailbox_emails SET invoice_id = 77 WHERE id = v_e3;
    v_msg := NULL;
    BEGIN
        PERFORM app.usp_mailbox_email_set_status('ZZINB', v_e3, 'Ignored');
        ASSERT false, 'expected CA409 for an email with invoice_id';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'This email is linked to an invoice and can''t be changed.', 'invoice_id CA409 message';
    UPDATE app.mailbox_emails SET invoice_id = NULL WHERE id = v_e3;

    -- Invalid status: CA400
    FOR v_case IN SELECT unnest(ARRAY['<null>', 'Processed', 'Failed', 'ignored', 'Bogus'])
    LOOP
        v_msg := NULL;
        BEGIN
            PERFORM app.usp_mailbox_email_set_status('ZZINB', v_e3, nullif(v_case, '<null>'));
            ASSERT false, 'expected CA400 for status ' || v_case;
        EXCEPTION WHEN SQLSTATE 'CA400' THEN v_msg := SQLERRM;
        END;
        ASSERT v_msg = 'Status must be New or Ignored.', 'status CA400 message: ' || coalesce(v_msg, '<none>');
    END LOOP;

    -- Note longer than 1000 characters (after trimming): CA400; exactly 1000 with spaces around: OK
    v_msg := NULL;
    BEGIN
        PERFORM app.usp_mailbox_email_set_status('ZZINB', v_e3, 'Ignored', repeat('n', 1001));
        ASSERT false, 'expected CA400 for a note of 1001 characters';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'Note must be at most 1000 characters.', 'note CA400 message: ' || coalesce(v_msg, '<none>');
    v_d := app.usp_mailbox_email_set_status('ZZINB', v_e3, 'Ignored', '  ' || repeat('n', 1000) || '  ');
    ASSERT v_d.status = 'Ignored' AND length(v_d.status_note) = 1000, 'note of 1000 characters after trim accepted';
END $$;

-- ---- 8. Attachments ----
DO $$
DECLARE
    v_e1    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e1');
    v_e3    integer := (SELECT v::integer FROM t_ctx WHERE k = 'e3');
    v_att1  integer := (SELECT v::integer FROM t_ctx WHERE k = 'att1');
    v_att   app.udt_mailbox_attachment_result;
BEGIN
    ASSERT (SELECT string_agg(file_name, ',') FROM app.usp_mailbox_attachment_list(v_e1)) = 'invoice.pdf,second.pdf',
        'attachment list: non-inline only, ordered by id';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_attachment_list(v_e1) WHERE is_inline), 'no inline attachments listed';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_attachment_list(v_e3)), 'email without attachments: no rows';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_attachment_list(-1)), 'unknown email: no rows';

    SELECT * INTO v_att FROM app.usp_mailbox_attachment_get_by_id(v_att1);
    ASSERT v_att.id = v_att1 AND v_att.mailbox_email_id = v_e1 AND v_att.file_name = 'invoice.pdf'
       AND v_att.mime_type = 'application/pdf' AND v_att.size_bytes = 1000
       AND v_att.storage_path = 'inbox/2026/01/zz/a.pdf' AND v_att.storage_provider = 'local', 'attachment get by id';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_attachment_get_by_id(-1)), 'unknown attachment: no row';
END $$;

-- ---- 9. Mailbox options per application (active and inactive) ----
DO $$
DECLARE
    v_b     integer := (SELECT v::integer FROM t_ctx WHERE k = 'b');
    v_order text;
BEGIN
    SELECT string_agg(address || '/' || folder, ',') INTO v_order FROM app.usp_mailbox_list_for_application('ZZINB');
    ASSERT v_order = 'zz-inb-mailbox-1@example.com/inbox,zz-inb-mailbox-2@example.com/Archive,zz-inb-mailbox-2@example.com/inbox',
        'options ZZINB (inactive included, ordered address, folder): ' || coalesce(v_order, '<none>');
    ASSERT (SELECT module_slug || '|' || module_name FROM app.usp_mailbox_list_for_application('ZZINB') WHERE id = v_b)
        = 'zz-inb-b|ZZ Inbox Module B', 'option module slug / name';
    ASSERT (SELECT string_agg(address || '/' || folder, ',') FROM app.usp_mailbox_list_for_application('ZZINB2'))
        = 'zz-inb-mailbox-3@example.com/inbox', 'options ZZINB2';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_list_for_application('ZZ-NO-SUCH-APP')), 'unknown application: no rows';
END $$;

\echo 'All mailbox email (Inbox) database tests passed.'
ROLLBACK;
