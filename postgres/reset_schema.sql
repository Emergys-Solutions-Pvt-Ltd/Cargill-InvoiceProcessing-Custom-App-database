-- =====================================================================
-- Cargill Custom Apps - DESTRUCTIVE reset for dev / demo databases.
-- Drops schema "app" (ALL APP DATA IS LOST) and recreates it via deploy_schema.sql.
-- Other schemas (public, auth, storage, ...) are not touched.
-- Follow with seed.sql for demo data:
--   psql "<connection>" -f database/postgres/reset_schema.sql
--   psql "<connection>" -f database/postgres/seed.sql
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

DROP SCHEMA IF EXISTS app CASCADE;
\echo 'Dropped schema app'

\ir deploy_schema.sql
