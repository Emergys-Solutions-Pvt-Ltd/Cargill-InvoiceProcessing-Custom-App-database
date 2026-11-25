-- =====================================================================
-- One-time migration: integer / bigint keys -> uuid, in place, for every table of the module schemas.
-- Runs from deploy_schema.sql (same transaction) before the table scripts; does nothing once no
-- integer key is left, so fresh databases (created with uuid keys) skip it.
--   1. every identity primary key gets a new uuid column (gen_random_uuid())
--   2. every foreign key column pointing at one gets the matching uuid (join on the old id); ids kept
--      inside JSON (sync job profile_stats keys) are remapped too
--   3. constraints / indexes on those columns are saved, dropped, the columns swapped, then recreated
--      with their original names and definitions
-- Any unexpected dependency (a view, policy ... on a key column) raises and rolls the deploy back.
-- =====================================================================
DO $$
DECLARE
    v_schemas   text[] := ARRAY['app', 'app_auth', 'gpp', 'sjo', 'rospbu'];
    r           record;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint k
        JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY (k.conkey)
        WHERE k.contype IN ('p', 'f')
          AND k.connamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (v_schemas))
          AND a.atttypid IN ('integer'::regtype, 'bigint'::regtype)
    ) THEN
        RETURN;
    END IF;

    -- Views (recreated by this deploy) depend on the key columns
    FOR r IN SELECT schemaname, viewname FROM pg_views WHERE schemaname = ANY (v_schemas) AND viewname LIKE 'vw\_%'
    LOOP
        EXECUTE format('DROP VIEW %I.%I CASCADE', r.schemaname, r.viewname);
    END LOOP;

    -- 1. Identity primary keys
    CREATE TEMP TABLE tmp_uuid_pk ON COMMIT DROP AS
    SELECT c.oid::regclass AS rel, a.attname AS col
    FROM pg_constraint k
    JOIN pg_class c ON c.oid = k.conrelid
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.conkey[1]
    WHERE k.contype = 'p' AND cardinality(k.conkey) = 1
      AND c.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (v_schemas))
      AND a.atttypid IN ('integer'::regtype, 'bigint'::regtype) AND a.attidentity <> '';

    -- 2. Foreign key columns pointing at them
    CREATE TEMP TABLE tmp_uuid_fk ON COMMIT DROP AS
    SELECT DISTINCT k.conrelid::regclass AS rel, a.attname AS col, k.confrelid::regclass AS ref, ra.attname AS ref_col,
           a.attnotnull AS not_null
    FROM pg_constraint k
    JOIN pg_attribute a  ON a.attrelid = k.conrelid AND a.attnum = k.conkey[1]
    JOIN pg_attribute ra ON ra.attrelid = k.confrelid AND ra.attnum = k.confkey[1]
    JOIN tmp_uuid_pk pk ON pk.rel = k.confrelid::regclass AND pk.col = ra.attname   -- not e.g. statuses.code
    WHERE k.contype = 'f' AND cardinality(k.conkey) = 1;

    CREATE TEMP TABLE tmp_uuid_cols ON COMMIT DROP AS
    SELECT rel, col FROM tmp_uuid_pk UNION SELECT rel, col FROM tmp_uuid_fk;

    FOR r IN SELECT rel FROM tmp_uuid_pk
    LOOP
        EXECUTE format('ALTER TABLE %s ADD COLUMN uuid_new_id uuid NOT NULL DEFAULT gen_random_uuid()', r.rel);
    END LOOP;

    FOR r IN SELECT * FROM tmp_uuid_fk
    LOOP
        EXECUTE format('ALTER TABLE %s ADD COLUMN %I uuid', r.rel, 'uuid_new_' || r.col);
        EXECUTE format('UPDATE %s t SET %I = x.uuid_new_id FROM %s x WHERE x.%I = t.%I',
                       r.rel, 'uuid_new_' || r.col, r.ref, r.ref_col, r.col);
    END LOOP;

    -- Ids inside JSON: per-profile stats of sync jobs are keyed by profile id
    IF to_regclass('app.integration_sync_jobs') IS NOT NULL THEN
        UPDATE app.integration_sync_jobs j
        SET profile_stats = (
            SELECT coalesce(jsonb_object_agg(coalesce(p.uuid_new_id::text, e.key), e.value), '{}'::jsonb)
            FROM jsonb_each(j.profile_stats) e
            LEFT JOIN app.integration_profiles p ON p.id::text = e.key)
        WHERE jsonb_typeof(j.profile_stats) = 'object' AND j.profile_stats <> '{}'::jsonb;
    END IF;

    -- 3. Constraints and indexes on the converted columns
    CREATE TEMP TABLE tmp_uuid_constraints ON COMMIT DROP AS
    SELECT DISTINCT k.conrelid::regclass AS rel, k.conname, k.contype, pg_get_constraintdef(k.oid) AS def
    FROM pg_constraint k
    JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY (k.conkey)
    JOIN tmp_uuid_cols u ON u.rel = k.conrelid::regclass AND u.col = a.attname
    WHERE k.contype IN ('p', 'u', 'f', 'x', 'c')
    UNION
    SELECT k.conrelid::regclass, k.conname, k.contype, pg_get_constraintdef(k.oid)
    FROM pg_constraint k
    WHERE k.contype = 'f' AND k.confrelid IN (SELECT rel FROM tmp_uuid_pk);

    CREATE TEMP TABLE tmp_uuid_indexes ON COMMIT DROP AS
    SELECT DISTINCT i.indexrelid::regclass AS idx, pg_get_indexdef(i.indexrelid) AS def
    FROM pg_index i
    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey::int2[])
    JOIN tmp_uuid_cols u ON u.rel = i.indrelid::regclass AND u.col = a.attname
    WHERE NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = i.indexrelid);

    FOR r IN SELECT * FROM tmp_uuid_constraints ORDER BY (contype = 'f') DESC
    LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.rel, r.conname);
    END LOOP;
    FOR r IN SELECT * FROM tmp_uuid_indexes
    LOOP
        EXECUTE format('DROP INDEX %s', r.idx);
    END LOOP;

    -- Swap the columns (an identity column takes its sequence with it)
    FOR r IN SELECT * FROM tmp_uuid_fk
    LOOP
        EXECUTE format('ALTER TABLE %s DROP COLUMN %I', r.rel, r.col);
        EXECUTE format('ALTER TABLE %s RENAME COLUMN %I TO %I', r.rel, 'uuid_new_' || r.col, r.col);
        IF r.not_null THEN
            EXECUTE format('ALTER TABLE %s ALTER COLUMN %I SET NOT NULL', r.rel, r.col);
        END IF;
    END LOOP;
    FOR r IN SELECT * FROM tmp_uuid_pk
    LOOP
        EXECUTE format('ALTER TABLE %s DROP COLUMN %I', r.rel, r.col);
        EXECUTE format('ALTER TABLE %s RENAME COLUMN uuid_new_id TO %I', r.rel, r.col);
    END LOOP;

    FOR r IN SELECT * FROM tmp_uuid_constraints ORDER BY (contype = 'f'), (contype <> 'p')
    LOOP
        EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s', r.rel, r.conname, r.def);
    END LOOP;
    FOR r IN SELECT * FROM tmp_uuid_indexes
    LOOP
        EXECUTE r.def;
    END LOOP;

    -- Key without a foreign key: a mailbox email's invoice (ids are per app, nothing to map from)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'mailbox_emails'
                                                         AND column_name = 'invoice_id' AND data_type <> 'uuid') THEN
        ALTER TABLE app.mailbox_emails ALTER COLUMN invoice_id TYPE uuid USING NULL;
    END IF;
END $$;
