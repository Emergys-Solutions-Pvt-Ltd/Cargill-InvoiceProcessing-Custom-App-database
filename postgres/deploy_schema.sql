-- =====================================================================
-- Cargill Custom Apps - LOCAL / DOCKER bootstrap of the PostgreSQL schema (PostgreSQL 14+)
--
-- DEV / UAT / PROD are deployed by the pipeline (Build/deploy.sh: reviewed pgschema plans that only
-- touch what changed). This script stays for developer machines and the docker-compose init hook:
--
--   psql "host=localhost port=5432 dbname=... user=..." -v ON_ERROR_STOP=1 -f database/postgres/deploy_schema.sql
--
-- One transaction: creates the schemas (predeploy/), drops and recreates every usp_ / ufn_ / vw_ / udt_
-- object, creates missing tables from objects.sql (the ordered object manifest) and loads the
-- reference data (postdeploy/). Table files are declarative: an existing local database whose tables
-- are older than the files is NOT altered here - run Build/deploy.sh against it, or recreate it.
-- =====================================================================
\set ON_ERROR_STOP on
\set QUIET on
SET client_min_messages = warning;

BEGIN;

\ir predeploy/00_schemas.sql

-- ---- Rebuild programmability: functions, views and composite types are recreated by objects.sql ----
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT p.oid::regprocedure AS sig
             FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname IN ('app', 'app_auth', 'gpp', 'sjo', 'rospbu') AND (p.proname LIKE 'usp\_%' OR p.proname LIKE 'ufn\_%')
    LOOP
        EXECUTE format('DROP FUNCTION %s CASCADE', r.sig);
    END LOOP;
    FOR r IN SELECT schemaname, viewname FROM pg_views
             WHERE schemaname IN ('app', 'app_auth', 'gpp', 'sjo', 'rospbu') AND viewname LIKE 'vw\_%'
    LOOP
        EXECUTE format('DROP VIEW %I.%I CASCADE', r.schemaname, r.viewname);
    END LOOP;
    FOR r IN SELECT n.nspname, t.typname FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
             WHERE n.nspname IN ('app', 'app_auth', 'gpp', 'sjo', 'rospbu') AND t.typtype = 'c' AND t.typname LIKE 'udt\_%'
    LOOP
        EXECUTE format('DROP TYPE %I.%I CASCADE', r.nspname, r.typname);
    END LOOP;
END $$;

\ir objects.sql

-- ---- Reference data ----
\ir postdeploy/10_applications_db_schema.sql
\ir postdeploy/20_statuses.sql
\ir postdeploy/30_master_data_entities.sql

COMMIT;

\echo 'Schema is up to date.'
