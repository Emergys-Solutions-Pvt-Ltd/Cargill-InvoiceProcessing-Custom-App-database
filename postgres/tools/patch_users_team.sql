-- =====================================================================
-- One-off patch: Settings > Users team assignment (2026-11-25)
-- Applies only the users/team objects instead of the full deploy_schema.sql.
-- deploy_schema.sql already contains all of this; after a full deploy this file is not needed.
--
--   psql "<conn>" -v ON_ERROR_STOP=1 -f postgres/tools/patch_users_team.sql
--
-- Safe to re-run (one transaction). Adds app_auth.users.team_id (NULL for existing users),
-- the FK to app.teams, and recreates the user view / result types / usp_user_* functions
-- that return or accept the team. No data is dropped.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- Tables (idempotent: only the guarded UPGRADES sections do anything on an existing DB)
\ir ../auth/tables/01_users.sql
\ir ../common/master-data/tables/05_teams.sql

-- Drop the objects whose shape changed. CASCADE also drops usp_user_get_by_id / _list / _create /
-- _update (they return these types); all of them are recreated below.
DROP VIEW IF EXISTS app_auth.vw_user_summary CASCADE;
DROP TYPE IF EXISTS app_auth.udt_user_list_result CASCADE;
DROP TYPE IF EXISTS app_auth.udt_user_result CASCADE;
-- Old signatures, in case they survived (e.g. a different return type)
DROP FUNCTION IF EXISTS app_auth.usp_user_create(text, text, text, text, text, text, text[]);
DROP FUNCTION IF EXISTS app_auth.usp_user_update(uuid, text, text, text, text[], text);

\ir ../auth/types/udt_user_result.sql
\ir ../auth/types/udt_user_list_result.sql
\ir ../auth/views/vw_user_summary.sql
\ir ../auth/procedures/usp_user_get_by_id.sql
\ir ../auth/procedures/usp_user_list.sql
\ir ../auth/procedures/usp_user_create.sql
\ir ../auth/procedures/usp_user_update.sql

-- Same rule as deploy_schema.sql: functions are not executable by PUBLIC
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_get_by_id(uuid, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_list(text, text, text, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_create(text, text, text, text, text, text, text[], uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_update(uuid, text, text, text, text[], text, uuid, boolean) FROM PUBLIC;

COMMIT;

\echo 'Users team patch applied.'
