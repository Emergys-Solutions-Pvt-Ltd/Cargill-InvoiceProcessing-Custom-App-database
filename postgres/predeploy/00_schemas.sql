-- =====================================================================
-- Pre-deployment: database-level objects pgschema does not manage (CREATE SCHEMA, default privileges).
-- Idempotent and non-destructive; runs before the schema objects on every deployment.
--   app = common objects; app_auth, gpp, sjo, rospbu = module objects
--   (app_auth, not auth: Supabase reserves schema auth for its own Supabase Auth tables)
-- Objects live in schemas Supabase does NOT expose through its REST API (only "public" is).
-- =====================================================================
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS app_auth;
CREATE SCHEMA IF NOT EXISTS gpp;
CREATE SCHEMA IF NOT EXISTS sjo;
CREATE SCHEMA IF NOT EXISTS rospbu;

-- New functions are not executable by everyone by default (applies to functions the deploying role creates)
ALTER DEFAULT PRIVILEGES IN SCHEMA app      REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_auth REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA gpp      REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA sjo      REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA rospbu   REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
