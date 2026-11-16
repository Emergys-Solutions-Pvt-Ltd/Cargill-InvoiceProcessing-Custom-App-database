-- =====================================================================
-- Database tests for the mailbox settings functions (Settings > Email Registration)
-- and app.usp_app_module_list.
-- Runs inside one transaction and ROLLS BACK: safe on a shared database.
--   psql "<connection>" -v ON_ERROR_STOP=1 -f database/postgres/tests/test_mailboxes.sql
-- Each block uses ASSERT; the first failure aborts the script with a message.
-- Creates its own test application and modules (code ZZMBX), so it does not need seed.sql.
-- Covers: 1 create + get, 2 validation, 3 inactive module on create, 4 duplicates,
-- 5 not found, 6 list (search / order / paging), 7 current inactive module on update (D-016),
-- 8 poll status reset on address / folder change (D-017), 9 delete rules (D-013).
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

CREATE TEMP TABLE t_ctx (k text PRIMARY KEY, v text) ON COMMIT DROP;

-- ---- Setup: one test application with three modules (A, B, C), all active ----
DO $$
DECLARE
    v_app   uuid;
    v_app2  uuid;
BEGIN
    INSERT INTO app.applications (code, name, description) VALUES ('ZZMBX', 'ZZ Mailbox Test', 'test only')
    RETURNING id INTO v_app;
    INSERT INTO app.applications (code, name, description, is_active) VALUES ('ZZMBX2', 'ZZ Mailbox Test 2', 'test only', false)
    RETURNING id INTO v_app2;
    INSERT INTO app.app_modules (application_id, slug, name, invoice_prefix) VALUES
        (v_app,  'zz-mbx-a', 'ZZ Mailbox Module A', 'ZZMBXA'),
        (v_app,  'zz-mbx-b', 'ZZ Mailbox Module B', 'ZZMBXB'),
        (v_app,  'zz-mbx-c', 'ZZ Mailbox Module C', 'ZZMBXC'),
        (v_app2, 'zz-mbx-x', 'ZZ Mailbox Module X', 'ZZMBXX');   -- active module of an inactive application

    ASSERT (SELECT count(*) FROM app.usp_app_module_list() WHERE slug LIKE 'zz-mbx-%') = 3,
        'module list: 3 active test modules, module of inactive application excluded';
    ASSERT (SELECT string_agg(l.slug, ',' ORDER BY l.ord)
            FROM app.usp_app_module_list() WITH ORDINALITY
                 AS l (module_id, slug, name, invoice_prefix, application_id, application_code, db_schema, ord)
            WHERE l.slug LIKE 'zz-mbx-%') = 'zz-mbx-a,zz-mbx-b,zz-mbx-c', 'module list ordered by name';
END $$;

-- ---- 1. Create + get by id ----
DO $$
DECLARE
    v_mb    app.udt_mailbox_detail_result;
    v_get   app.udt_mailbox_detail_result;
BEGIN
    v_mb := app.usp_mailbox_save(NULL, 'zz-mbx-test-one@example.com', NULL, 'zz-mbx-a');
    ASSERT v_mb.id IS NOT NULL AND v_mb.folder = 'inbox' AND v_mb.is_active, 'created with default folder and active';
    ASSERT v_mb.module_slug = 'zz-mbx-a' AND v_mb.module_name = 'ZZ Mailbox Module A', 'module slug / name resolved';
    ASSERT v_mb.last_polled_at IS NULL AND v_mb.last_error IS NULL, 'not polled yet';

    SELECT * INTO v_get FROM app.usp_mailbox_get_by_id(v_mb.id);
    ASSERT v_get.id = v_mb.id AND v_get.address = 'zz-mbx-test-one@example.com', 'get by id';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_get_by_id('00000000-0000-0000-0000-000000000000'::uuid)), 'unknown id: no row';

    INSERT INTO t_ctx VALUES ('one', v_mb.id::text);
END $$;

-- ---- 2. Validation -> CA400 ----
DO $$
DECLARE
    v_case  text;
BEGIN
    FOR v_case IN SELECT unnest(ARRAY['null', 'blank', 'format', 'long-address', 'long-folder', 'no-module', 'unknown-module'])
    LOOP
        BEGIN
            CASE v_case
                WHEN 'null'           THEN PERFORM app.usp_mailbox_save(NULL, NULL, 'inbox', 'zz-mbx-a');
                WHEN 'blank'          THEN PERFORM app.usp_mailbox_save(NULL, '   ', 'inbox', 'zz-mbx-a');
                WHEN 'format'         THEN PERFORM app.usp_mailbox_save(NULL, 'not-an-email', 'inbox', 'zz-mbx-a');
                WHEN 'long-address'   THEN PERFORM app.usp_mailbox_save(NULL, repeat('a', 250) || '@example.com', 'inbox', 'zz-mbx-a');
                WHEN 'long-folder'    THEN PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-v@example.com', repeat('f', 256), 'zz-mbx-a');
                WHEN 'no-module'      THEN PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-v@example.com', 'inbox', NULL);
                WHEN 'unknown-module' THEN PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-v@example.com', 'inbox', 'zz-no-such-module');
            END CASE;
            ASSERT false, 'expected CA400 for ' || v_case;
        EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
        END;
    END LOOP;
END $$;

-- ---- 3. Create with an inactive module or a module of an inactive application -> CA400 ----
DO $$
BEGIN
    UPDATE app.app_modules SET is_active = false WHERE slug = 'zz-mbx-c';
    BEGIN
        PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-v@example.com', 'inbox', 'zz-mbx-c');
        ASSERT false, 'expected CA400 for inactive module on create';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;
    BEGIN
        PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-v@example.com', 'inbox', 'zz-mbx-x');
        ASSERT false, 'expected CA400 for module of inactive application on create';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;
    UPDATE app.app_modules SET is_active = true WHERE slug = 'zz-mbx-c';
END $$;

-- ---- 4. Duplicate address + folder (case-insensitive) -> CA409 ----
DO $$
DECLARE
    v_one   uuid := (SELECT v::uuid FROM t_ctx WHERE k = 'one');
    v_two   app.udt_mailbox_detail_result;
BEGIN
    BEGIN
        PERFORM app.usp_mailbox_save(NULL, 'ZZ-MBX-TEST-ONE@example.com', 'INBOX', 'zz-mbx-b');
        ASSERT false, 'expected CA409 for duplicate on create';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    -- same address, other folder is fine
    v_two := app.usp_mailbox_save(NULL, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-b');
    ASSERT v_two.folder = 'archive', 'same address, other folder allowed';

    BEGIN
        PERFORM app.usp_mailbox_save(v_two.id, 'zz-mbx-test-one@example.com', 'Inbox', 'zz-mbx-b');
        ASSERT false, 'expected CA409 for duplicate on update';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN NULL;
    END;

    -- saving a row onto its own address + folder is not a duplicate
    PERFORM app.usp_mailbox_save(v_one, 'zz-mbx-test-one@example.com', 'inbox', 'zz-mbx-a');

    INSERT INTO t_ctx VALUES ('two', v_two.id::text);
END $$;

-- ---- 5. Unknown id -> CA404 (update and delete) ----
DO $$
BEGIN
    BEGIN
        PERFORM app.usp_mailbox_save('00000000-0000-0000-0000-000000000000'::uuid, 'zz-mbx-test-v@example.com', 'inbox', 'zz-mbx-a');
        ASSERT false, 'expected CA404 for update of unknown mailbox';
    EXCEPTION WHEN SQLSTATE 'CA404' THEN NULL;
    END;
    BEGIN
        PERFORM app.usp_mailbox_delete('00000000-0000-0000-0000-000000000000'::uuid);
        ASSERT false, 'expected CA404 for delete of unknown mailbox';
    EXCEPTION WHEN SQLSTATE 'CA404' THEN NULL;
    END;
END $$;

-- ---- 6. List: search, order, paging ----
DO $$
DECLARE
    v_order text;
BEGIN
    PERFORM app.usp_mailbox_save(NULL, 'zz-mbx-test-aaa@example.com', 'inbox', 'zz-mbx-c');

    -- search on address: order lower(address), lower(folder), id
    SELECT string_agg(address || '/' || folder, ',') INTO v_order FROM app.usp_mailbox_list('zz-mbx-test', 1, 100);
    ASSERT v_order = 'zz-mbx-test-aaa@example.com/inbox,zz-mbx-test-one@example.com/archive,zz-mbx-test-one@example.com/inbox',
        'list order: ' || coalesce(v_order, '<none>');
    ASSERT (SELECT total_items FROM app.usp_mailbox_list('zz-mbx-test', 1, 100) LIMIT 1) = 3, 'total_items';

    -- search on folder and on module name (case-insensitive)
    ASSERT (SELECT count(*) FROM app.usp_mailbox_list('ARCHIVE', 1, 100) WHERE address LIKE 'zz-mbx-test-%') = 1, 'search folder';
    ASSERT (SELECT string_agg(address, ',') FROM app.usp_mailbox_list('zz mailbox module c', 1, 100)) = 'zz-mbx-test-aaa@example.com',
        'search module name';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_list('zz-no-such-mailbox', 1, 10)), 'no match: no rows';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_list('zz_mbx_test', 1, 100)), 'search _ is literal, not a wildcard';

    -- paging: page 2 of 3, and a page past the end is clamped to the last page
    ASSERT (SELECT address || '/' || folder || ':' || page || '/' || total_pages
            FROM app.usp_mailbox_list('zz-mbx-test', 2, 1)) = 'zz-mbx-test-one@example.com/archive:2/3', 'page 2 of 3';
    ASSERT (SELECT page FROM app.usp_mailbox_list('zz-mbx-test', 99, 1)) = 3, 'page clamped';

    BEGIN
        PERFORM app.usp_mailbox_list(NULL, 1, 0);
        ASSERT false, 'expected CA400 for page size 0';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;
    BEGIN
        PERFORM app.usp_mailbox_list(NULL, 1, 101);
        ASSERT false, 'expected CA400 for page size 101';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;
END $$;

-- ---- 7. D-016: an update may keep its current (now inactive) module ----
DO $$
DECLARE
    v_two   uuid := (SELECT v::uuid FROM t_ctx WHERE k = 'two');   -- on module B
    v_mb    app.udt_mailbox_detail_result;
BEGIN
    UPDATE app.app_modules SET is_active = false WHERE slug IN ('zz-mbx-b', 'zz-mbx-c');
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_app_module_list() WHERE slug IN ('zz-mbx-b', 'zz-mbx-c')),
        'inactive modules not listed';

    -- keep current inactive module B and deactivate the mailbox: allowed
    v_mb := app.usp_mailbox_save(v_two, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-b', false);
    ASSERT v_mb.module_slug = 'zz-mbx-b' AND NOT v_mb.is_active, 'kept current inactive module';

    -- switch to another inactive module: CA400
    BEGIN
        PERFORM app.usp_mailbox_save(v_two, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-c', false);
        ASSERT false, 'expected CA400 for switching to another inactive module';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;

    -- the current module stays allowed even when its application is inactive
    UPDATE app.applications SET is_active = false WHERE code = 'ZZMBX';
    v_mb := app.usp_mailbox_save(v_two, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-b', true);
    ASSERT v_mb.module_slug = 'zz-mbx-b' AND v_mb.is_active, 'kept current module of inactive application';
    UPDATE app.applications SET is_active = true WHERE code = 'ZZMBX';

    -- move to active module A, then moving back to inactive B is no longer allowed
    v_mb := app.usp_mailbox_save(v_two, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-a', true);
    ASSERT v_mb.module_slug = 'zz-mbx-a', 'moved to active module';
    BEGIN
        PERFORM app.usp_mailbox_save(v_two, 'zz-mbx-test-one@example.com', 'archive', 'zz-mbx-b', true);
        ASSERT false, 'expected CA400 for moving back to an inactive module';
    EXCEPTION WHEN SQLSTATE 'CA400' THEN NULL;
    END;

    UPDATE app.app_modules SET is_active = true WHERE slug IN ('zz-mbx-b', 'zz-mbx-c');
END $$;

-- ---- 8. D-017: address / folder change clears delta_link, last_polled_at, last_error ----
DO $$
DECLARE
    v_one   uuid := (SELECT v::uuid FROM t_ctx WHERE k = 'one');
    v_mb    app.udt_mailbox_detail_result;
BEGIN
    UPDATE app.mailboxes
       SET delta_link = 'https://graph.example/delta', last_polled_at = now() - interval '1 hour',
           last_error = 'previous error', updated_at = now() - interval '1 day'
     WHERE id = v_one;

    -- is_active only: all three kept, updated_at set
    v_mb := app.usp_mailbox_save(v_one, 'zz-mbx-test-one@example.com', 'inbox', 'zz-mbx-a', false);
    ASSERT v_mb.last_polled_at IS NOT NULL AND v_mb.last_error = 'previous error', 'is_active change keeps poll status';
    ASSERT (SELECT delta_link FROM app.mailboxes WHERE id = v_one) = 'https://graph.example/delta', 'is_active change keeps delta_link';
    ASSERT v_mb.updated_at > now() - interval '1 minute', 'updated_at set on update';

    -- module only: all three kept
    v_mb := app.usp_mailbox_save(v_one, 'zz-mbx-test-one@example.com', 'inbox', 'zz-mbx-b', false);
    ASSERT v_mb.last_polled_at IS NOT NULL AND v_mb.last_error IS NOT NULL
       AND (SELECT delta_link IS NOT NULL FROM app.mailboxes WHERE id = v_one), 'module change keeps poll status';

    -- folder change: all three cleared
    v_mb := app.usp_mailbox_save(v_one, 'zz-mbx-test-one@example.com', 'junkemail', 'zz-mbx-b', false);
    ASSERT v_mb.last_polled_at IS NULL AND v_mb.last_error IS NULL
       AND (SELECT delta_link IS NULL FROM app.mailboxes WHERE id = v_one), 'folder change clears poll status';

    -- address change: all three cleared
    UPDATE app.mailboxes SET delta_link = 'https://graph.example/delta', last_polled_at = now(), last_error = 'x' WHERE id = v_one;
    v_mb := app.usp_mailbox_save(v_one, 'zz-mbx-test-renamed@example.com', 'junkemail', 'zz-mbx-b', false);
    ASSERT v_mb.address = 'zz-mbx-test-renamed@example.com' AND v_mb.last_polled_at IS NULL AND v_mb.last_error IS NULL
       AND (SELECT delta_link IS NULL FROM app.mailboxes WHERE id = v_one), 'address change clears poll status';

    -- exact comparison: a case-only change of the folder also clears them
    UPDATE app.mailboxes SET delta_link = 'https://graph.example/delta', last_polled_at = now(), last_error = 'x' WHERE id = v_one;
    v_mb := app.usp_mailbox_save(v_one, 'zz-mbx-test-renamed@example.com', 'JunkEmail', 'zz-mbx-b', false);
    ASSERT v_mb.folder = 'JunkEmail' AND v_mb.last_polled_at IS NULL
       AND (SELECT delta_link IS NULL FROM app.mailboxes WHERE id = v_one), 'case-only folder change clears poll status';
END $$;

-- ---- 9. Delete: blocked once the mailbox has emails (D-013) ----
DO $$
DECLARE
    v_one   uuid := (SELECT v::uuid FROM t_ctx WHERE k = 'one');
    v_two   uuid := (SELECT v::uuid FROM t_ctx WHERE k = 'two');
    v_msg   text;
BEGIN
    PERFORM app.usp_mailbox_email_upsert(v_one, 'zz-mbx-test-graph-id-1', NULL, 'Sender', 'sender@example.com',
        NULL, NULL, 'ZZ test', 'body', now(), false);
    BEGIN
        PERFORM app.usp_mailbox_delete(v_one);
        ASSERT false, 'expected CA409 for delete of a mailbox with emails';
    EXCEPTION WHEN SQLSTATE 'CA409' THEN v_msg := SQLERRM;
    END;
    ASSERT v_msg = 'This mailbox has received emails and can''t be deleted. Set it to Inactive instead.',
        'delete CA409 message: ' || coalesce(v_msg, '<none>');
    ASSERT EXISTS (SELECT 1 FROM app.usp_mailbox_get_by_id(v_one)), 'mailbox with emails kept';

    ASSERT (app.usp_mailbox_delete(v_two)).rows_affected = 1, 'mailbox without emails deleted';
    ASSERT NOT EXISTS (SELECT 1 FROM app.usp_mailbox_get_by_id(v_two)), 'deleted mailbox is gone';
END $$;

\echo 'All mailbox database tests passed.'
ROLLBACK;
