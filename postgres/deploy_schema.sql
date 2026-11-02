-- =====================================================================
-- Cargill Custom Apps - create OR update the PostgreSQL schema (Supabase / PostgreSQL 14+)
--
-- Safe to run repeatedly and atomic (one transaction): table scripts create
-- missing tables and apply their guarded UPGRADES sections; no data is dropped.
-- Programmability (usp_ functions, vw_ views, udt_ types) is dropped and recreated.
--
--   psql "host=... port=5432 dbname=postgres user=... sslmode=require" -f database/postgres/deploy_schema.sql
--
-- Everything lives in schema "app", which Supabase does NOT expose through its
-- auto-generated REST API (only "public" is), so tables are reachable only via this backend.
-- =====================================================================
\set ON_ERROR_STOP on
\set QUIET on
SET client_min_messages = warning;

BEGIN;

CREATE SCHEMA IF NOT EXISTS app;
-- New functions are not executable by everyone by default
ALTER DEFAULT PRIVILEGES IN SCHEMA app REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- ---- Tables (dependency order) ----
\ir tables/01_users.sql
\ir tables/02_applications.sql
\ir tables/03_app_modules.sql
\ir tables/04_user_applications.sql
\ir tables/05_teams.sql
\ir tables/06_app_settings.sql
\ir tables/07_app_team_members.sql
\ir tables/08_vendors.sql
\ir tables/09_country_stations.sql
\ir tables/10_invoices.sql
\ir tables/11_invoice_attachments.sql
\ir tables/12_invoice_line_items.sql
\ir tables/13_invoice_ccpps.sql

-- ---- Master data (Settings > Configuration) ----
\ir tables/14_countries.sql
\ir tables/15_states.sql
\ir tables/16_cities.sql
\ir tables/17_business_units.sql
\ir tables/18_statuses.sql
\ir tables/19_processes.sql
\ir tables/20_master_data_entities.sql
\ir tables/21_invoice_workflow.sql
\ir tables/22_invoice_source_emails.sql

-- ---- Invoice integrations (Settings > SAP Configuration, background sync) ----
\ir tables/23_integrations.sql
\ir tables/24_integration_profiles.sql
\ir tables/25_integration_sync_jobs.sql
\ir tables/26_integration_sync_errors.sql
\ir tables/27_invoice_external_refs.sql
\ir tables/28_integration_audit_log.sql

-- ---- Rebuild programmability: functions, views and composite types ----
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT p.oid::regprocedure AS sig
             FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
             WHERE n.nspname = 'app' AND (p.proname LIKE 'usp\_%' OR p.proname LIKE 'ufn\_%')
    LOOP
        EXECUTE format('DROP FUNCTION %s CASCADE', r.sig);
    END LOOP;
    FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'app' AND viewname LIKE 'vw\_%'
    LOOP
        EXECUTE format('DROP VIEW app.%I CASCADE', r.viewname);
    END LOOP;
    FOR r IN SELECT t.typname FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
             WHERE n.nspname = 'app' AND t.typtype = 'c' AND t.typname LIKE 'udt\_%'
    LOOP
        EXECUTE format('DROP TYPE app.%I CASCADE', r.typname);
    END LOOP;
END $$;

-- ---- Request types ----
\ir types/request/udt_invoice_input.sql
\ir types/request/udt_integration_profile_input.sql
\ir types/request/udt_external_invoice_input.sql
\ir types/request/udt_sync_error_input.sql

-- ---- Response types (nested types first) ----
\ir types/response/udt_code_result.sql
\ir types/response/udt_row_count_result.sql
\ir types/response/udt_application_result.sql
\ir types/response/udt_app_module_result.sql
\ir types/response/udt_user_result.sql
\ir types/response/udt_user_login_result.sql
\ir types/response/udt_user_list_result.sql
\ir types/response/udt_invoice_result.sql
\ir types/response/udt_invoice_list_result.sql
\ir types/response/udt_attachment_result.sql
\ir types/response/udt_line_item_result.sql
\ir types/response/udt_ccpp_result.sql
\ir types/response/udt_invoice_email_result.sql
\ir types/response/udt_invoice_detail_result.sql
\ir types/response/udt_app_settings_result.sql
\ir types/response/udt_team_member_result.sql
\ir types/response/udt_team_member_list_result.sql
\ir types/response/udt_lookup_value_result.sql
\ir types/response/udt_vendor_result.sql
\ir types/response/udt_lookups_result.sql
\ir types/response/udt_master_data_entity_result.sql
\ir types/response/udt_master_data_result.sql
\ir types/response/udt_master_data_list_result.sql
\ir types/response/udt_master_data_option_result.sql
\ir types/response/udt_integration_profile_result.sql
\ir types/response/udt_integration_result.sql
\ir types/response/udt_integration_secret_result.sql
\ir types/response/udt_sync_job_result.sql
\ir types/response/udt_sync_job_list_result.sql
\ir types/response/udt_sync_error_list_result.sql
\ir types/response/udt_sync_row_outcome_result.sql
\ir types/response/udt_integration_summary_result.sql

-- ---- Helper functions & views ----
\ir functions/ufn_like_contains.sql
\ir functions/ufn_master_data_select_sql.sql
\ir functions/ufn_integration_row.sql
\ir functions/ufn_sync_job_row.sql
\ir views/vw_user_summary.sql
\ir views/vw_invoice_summary.sql

-- ---- Stored functions ("procedures") ----
\ir procedures/apps/usp_application_list.sql
\ir procedures/apps/usp_app_module_get_by_slug.sql

\ir procedures/users/usp_user_get_for_login.sql
\ir procedures/users/usp_user_get_by_id.sql
\ir procedures/users/usp_user_touch_last_login.sql
\ir procedures/users/usp_user_list.sql
\ir procedures/users/usp_user_create.sql
\ir procedures/users/usp_user_update.sql
\ir procedures/users/usp_user_delete.sql

\ir procedures/invoices/usp_invoice_list.sql
\ir procedures/invoices/usp_invoice_get_by_code.sql
\ir procedures/invoices/usp_invoice_create_batch.sql
\ir procedures/invoices/usp_invoice_update_status.sql
\ir procedures/invoices/usp_attachment_get_by_id.sql
\ir procedures/invoices/usp_attachment_add.sql
\ir procedures/invoices/usp_invoice_update_details.sql
\ir procedures/invoices/usp_invoice_send_to_previous_team.sql

\ir procedures/app_config/usp_team_list.sql
\ir procedures/app_config/usp_app_settings_get.sql
\ir procedures/app_config/usp_app_settings_save.sql
\ir procedures/app_config/usp_team_member_list.sql
\ir procedures/app_config/usp_team_member_add.sql
\ir procedures/app_config/usp_team_member_remove.sql

\ir procedures/master_data/usp_master_data_entities.sql
\ir procedures/master_data/usp_master_data_list.sql
\ir procedures/master_data/usp_master_data_options.sql
\ir procedures/master_data/usp_master_data_save.sql
\ir procedures/master_data/usp_master_data_delete.sql

\ir procedures/lookups/usp_lookup_get_all.sql

\ir procedures/integrations/usp_integration_list.sql
\ir procedures/integrations/usp_integration_get.sql
\ir procedures/integrations/usp_integration_save.sql
\ir procedures/integrations/usp_integration_set_secret.sql
\ir procedures/integrations/usp_integration_get_secret.sql
\ir procedures/integrations/usp_integration_delete.sql
\ir procedures/integrations/usp_integration_audit_add.sql
\ir procedures/integrations/usp_integration_set_next_run.sql
\ir procedures/integrations/usp_integration_due_list.sql
\ir procedures/integrations/usp_integration_summary.sql
\ir procedures/integrations/usp_integration_profile_reset_cursor.sql
\ir procedures/integrations/usp_integration_purge_history.sql
\ir procedures/integrations/usp_integration_invoices_without_attachment.sql
\ir procedures/integrations/usp_sync_job_enqueue.sql
\ir procedures/integrations/usp_sync_job_claim.sql
\ir procedures/integrations/usp_sync_job_heartbeat.sql
\ir procedures/integrations/usp_sync_page_apply.sql
\ir procedures/integrations/usp_sync_job_finish.sql
\ir procedures/integrations/usp_sync_job_release.sql
\ir procedures/integrations/usp_sync_job_cancel.sql
\ir procedures/integrations/usp_sync_job_recover_stale.sql
\ir procedures/integrations/usp_sync_job_list.sql
\ir procedures/integrations/usp_sync_job_get.sql
\ir procedures/integrations/usp_sync_error_add.sql
\ir procedures/integrations/usp_sync_error_list.sql

COMMIT;

\echo 'Schema is up to date.'
