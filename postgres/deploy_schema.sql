-- =====================================================================
-- Cargill Custom Apps - create OR update the PostgreSQL schema (Supabase / PostgreSQL 14+)
--
-- Safe to run repeatedly and atomic (one transaction): table scripts create
-- missing tables and apply their guarded UPGRADES sections; no data is dropped.
-- Programmability (usp_ functions, vw_ views, udt_ types) is dropped and recreated in every module schema.
--
--   psql "host=... port=5432 dbname=postgres user=... sslmode=require" -f database/postgres/deploy_schema.sql
--
-- Scripts are grouped by module, each with tables/ types/ functions/ procedures/ views/:
--   auth/      users, user_applications, usp_user_*        (sign-in, User Access Management) - schema app_auth
--   common/    shared/ apps/ master-data/ lookups/ invoices/ attachments/ integrations/ - schema app
--   gpp/       General Payments: CCPP rows, legacy Salesforce "GP Invoice" fields   - schema gpp
--   sjo/       SJO Invoice Processing: ERP systems list, SJO invoice fields       - schema sjo
--   rospbu/    ROSPBU Invoice Processing (no specific objects yet)                 - schema rospbu
-- This file is the only entry point: it includes them in dependency order (tables by number).
--
-- Objects live in schemas app (common), app_auth, gpp, sjo and rospbu, which Supabase does NOT expose through its
-- auto-generated REST API (only "public" is), so tables are reachable only via this backend.
-- =====================================================================
\set ON_ERROR_STOP on
\set QUIET on
SET client_min_messages = warning;

BEGIN;

-- One schema per module: app = common objects; app_auth, gpp, sjo, rospbu = module objects
-- (app_auth, not auth: Supabase reserves schema auth for its own Supabase Auth tables, incl. its own users table)
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS app_auth;
CREATE SCHEMA IF NOT EXISTS gpp;
CREATE SCHEMA IF NOT EXISTS sjo;
CREATE SCHEMA IF NOT EXISTS rospbu;
-- New functions are not executable by everyone by default
ALTER DEFAULT PRIVILEGES IN SCHEMA app    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA app_auth REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA gpp    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA sjo    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA rospbu REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- ---- One-time conversion of integer keys to uuid (no-op once converted / on fresh databases) ----
\ir common/shared/migrations/ids_to_uuid.sql

-- ---- Tables (dependency order) ----
\ir auth/tables/01_users.sql
\ir common/apps/tables/02_applications.sql
\ir common/apps/tables/03_app_modules.sql
\ir auth/tables/04_user_applications.sql
\ir common/master-data/tables/05_teams.sql
\ir common/apps/tables/06_app_settings.sql
\ir common/apps/tables/07_app_team_members.sql
\ir common/invoices/tables/08_vendors.sql
\ir common/invoices/tables/09_country_stations.sql

-- ---- Master data (Settings > Configuration) ----
\ir common/master-data/tables/14_countries.sql
\ir common/master-data/tables/15_states.sql
\ir common/master-data/tables/16_cities.sql
\ir common/master-data/tables/17_business_units.sql
\ir common/master-data/tables/18_statuses.sql
\ir common/master-data/tables/19_processes.sql
\ir common/master-data/tables/20_master_data_entities.sql

-- ---- Invoice integrations (Settings > SAP Configuration, background sync) ----
\ir common/integrations/tables/23_integrations.sql
\ir common/integrations/tables/24_integration_profiles.sql
\ir common/integrations/tables/25_integration_sync_jobs.sql
\ir common/integrations/tables/26_integration_sync_errors.sql
\ir common/integrations/tables/28_integration_audit_log.sql
\ir sjo/tables/30_erp_systems.sql

-- ---- Invoices: one set of tables per app (generated from common/invoices/templates by
-- tools/generate-app-invoice-sql.cjs); invoice ids are unique per app ----
\ir gpp/invoices/tables/40_gpp_invoices.sql
\ir gpp/invoices/tables/41_invoice_line_items.sql
\ir gpp/invoices/tables/42_invoice_source_emails.sql
\ir gpp/invoices/tables/43_invoice_attachments.sql
\ir gpp/invoices/tables/44_invoice_external_refs.sql
\ir sjo/invoices/tables/40_sjo_invoices.sql
\ir sjo/invoices/tables/41_invoice_line_items.sql
\ir sjo/invoices/tables/42_invoice_source_emails.sql
\ir sjo/invoices/tables/43_invoice_attachments.sql
\ir sjo/invoices/tables/44_invoice_external_refs.sql
\ir rospbu/invoices/tables/40_rospbu_invoices.sql
\ir rospbu/invoices/tables/41_invoice_line_items.sql
\ir rospbu/invoices/tables/42_invoice_source_emails.sql
\ir rospbu/invoices/tables/43_invoice_attachments.sql
\ir rospbu/invoices/tables/44_invoice_external_refs.sql
\ir gpp/tables/45_invoice_ccpps.sql


-- ---- Mailbox inbox (background email reading, Inbox page) ----
\ir tables/29_mailboxes.sql
\ir tables/30_mailbox_emails.sql
\ir tables/31_mailbox_email_attachments.sql


-- ---- Rebuild programmability: functions, views and composite types ----
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

-- ---- Request types ----
\ir common/integrations/types/udt_integration_profile_input.sql
\ir common/integrations/types/udt_external_invoice_input.sql
\ir common/integrations/types/udt_sync_error_input.sql

-- ---- Response types (nested types first) ----
\ir common/shared/types/udt_code_result.sql
\ir common/shared/types/udt_row_count_result.sql
\ir common/apps/types/udt_application_result.sql
\ir common/apps/types/udt_app_module_result.sql
\ir auth/types/udt_user_result.sql
\ir auth/types/udt_user_login_result.sql
\ir auth/types/udt_user_list_result.sql
\ir common/invoices/types/udt_invoice_result.sql
\ir common/attachments/types/udt_attachment_result.sql
\ir common/invoices/types/udt_line_item_result.sql
\ir gpp/types/udt_ccpp_result.sql
\ir common/invoices/types/udt_invoice_email_result.sql
\ir gpp/types/udt_invoice_sf_fields_result.sql
\ir sjo/types/udt_invoice_sjo_fields_result.sql
\ir gpp/invoices/types/udt_invoice_input.sql
\ir gpp/invoices/types/udt_invoice_list_result.sql
\ir gpp/invoices/types/udt_invoice_detail_result.sql
\ir sjo/invoices/types/udt_invoice_input.sql
\ir sjo/invoices/types/udt_invoice_list_result.sql
\ir sjo/invoices/types/udt_invoice_detail_result.sql
\ir rospbu/invoices/types/udt_invoice_input.sql
\ir rospbu/invoices/types/udt_invoice_list_result.sql
\ir rospbu/invoices/types/udt_invoice_detail_result.sql
\ir common/apps/types/udt_app_settings_result.sql
\ir common/apps/types/udt_team_member_result.sql
\ir common/apps/types/udt_team_member_list_result.sql
\ir common/lookups/types/udt_lookup_value_result.sql
\ir common/lookups/types/udt_vendor_result.sql
\ir common/lookups/types/udt_lookups_result.sql
\ir common/master-data/types/udt_master_data_entity_result.sql
\ir common/master-data/types/udt_master_data_result.sql
\ir common/master-data/types/udt_master_data_list_result.sql
\ir common/master-data/types/udt_master_data_option_result.sql
\ir common/integrations/types/udt_integration_profile_result.sql
\ir common/integrations/types/udt_integration_result.sql
\ir common/integrations/types/udt_integration_secret_result.sql
\ir common/integrations/types/udt_sync_job_result.sql
\ir common/integrations/types/udt_sync_job_list_result.sql
\ir common/integrations/types/udt_sync_error_list_result.sql
\ir common/integrations/types/udt_sync_row_outcome_result.sql
\ir common/integrations/types/udt_sync_invoice_apply_result.sql
\ir common/integrations/types/udt_integration_summary_result.sql
\ir types/response/udt_mailbox_result.sql
\ir types/response/udt_mailbox_attachment_result.sql
\ir types/response/udt_mailbox_email_result.sql

-- ---- Helper functions & views ----
\ir common/shared/functions/ufn_like_contains.sql
\ir common/master-data/functions/ufn_master_data_select_sql.sql
\ir sjo/functions/ufn_invoice_sjo_fields.sql
\ir common/integrations/functions/ufn_integration_row.sql
\ir common/integrations/functions/ufn_sync_job_row.sql
\ir common/integrations/functions/ufn_external_ref_count.sql
\ir auth/views/vw_user_summary.sql
\ir gpp/invoices/views/vw_invoice_summary.sql
\ir sjo/invoices/views/vw_invoice_summary.sql
\ir rospbu/invoices/views/vw_invoice_summary.sql

-- ---- Stored functions ("procedures") ----
\ir common/apps/procedures/usp_application_list.sql
\ir common/apps/procedures/usp_app_module_get_by_slug.sql

\ir auth/procedures/usp_user_get_for_login.sql
\ir auth/procedures/usp_user_get_by_id.sql
\ir auth/procedures/usp_user_touch_last_login.sql
\ir auth/procedures/usp_user_list.sql
\ir auth/procedures/usp_user_create.sql
\ir auth/procedures/usp_user_update.sql
\ir auth/procedures/usp_user_delete.sql

\ir gpp/invoices/procedures/usp_invoice_list.sql
\ir gpp/invoices/procedures/usp_invoice_get_by_code.sql
\ir gpp/invoices/procedures/usp_invoice_create_batch.sql
\ir gpp/invoices/procedures/usp_invoice_update_status.sql
\ir gpp/invoices/procedures/usp_invoice_update_details.sql
\ir gpp/invoices/procedures/usp_invoice_send_to_previous_team.sql
\ir gpp/invoices/procedures/usp_attachment.sql
\ir gpp/invoices/procedures/usp_sync_invoice_apply.sql
\ir sjo/invoices/procedures/usp_invoice_list.sql
\ir sjo/invoices/procedures/usp_invoice_get_by_code.sql
\ir sjo/invoices/procedures/usp_invoice_create_batch.sql
\ir sjo/invoices/procedures/usp_invoice_update_status.sql
\ir sjo/invoices/procedures/usp_invoice_update_details.sql
\ir sjo/invoices/procedures/usp_invoice_send_to_previous_team.sql
\ir sjo/invoices/procedures/usp_attachment.sql
\ir sjo/invoices/procedures/usp_sync_invoice_apply.sql
\ir rospbu/invoices/procedures/usp_invoice_list.sql
\ir rospbu/invoices/procedures/usp_invoice_get_by_code.sql
\ir rospbu/invoices/procedures/usp_invoice_create_batch.sql
\ir rospbu/invoices/procedures/usp_invoice_update_status.sql
\ir rospbu/invoices/procedures/usp_invoice_update_details.sql
\ir rospbu/invoices/procedures/usp_invoice_send_to_previous_team.sql
\ir rospbu/invoices/procedures/usp_attachment.sql
\ir rospbu/invoices/procedures/usp_sync_invoice_apply.sql
\ir gpp/procedures/usp_ccpp_list.sql
\ir gpp/procedures/usp_ccpp_save.sql
\ir sjo/procedures/usp_invoice_sjo_fields_save.sql

\ir common/apps/procedures/usp_team_list.sql
\ir common/apps/procedures/usp_app_settings_get.sql
\ir common/apps/procedures/usp_app_settings_save.sql
\ir common/apps/procedures/usp_team_member_list.sql
\ir common/apps/procedures/usp_team_member_add.sql
\ir common/apps/procedures/usp_team_member_remove.sql

\ir common/master-data/procedures/usp_master_data_entities.sql
\ir common/master-data/procedures/usp_master_data_list.sql
\ir common/master-data/procedures/usp_master_data_options.sql
\ir common/master-data/procedures/usp_master_data_save.sql

\ir common/lookups/procedures/usp_lookup_get_all.sql

\ir common/integrations/procedures/usp_integration_list.sql
\ir common/integrations/procedures/usp_integration_get.sql
\ir common/integrations/procedures/usp_integration_save.sql
\ir common/integrations/procedures/usp_integration_set_secret.sql
\ir common/integrations/procedures/usp_integration_get_secret.sql
\ir common/integrations/procedures/usp_integration_delete.sql
\ir common/integrations/procedures/usp_integration_audit_add.sql
\ir common/integrations/procedures/usp_integration_set_next_run.sql
\ir common/integrations/procedures/usp_integration_due_list.sql
\ir common/integrations/procedures/usp_integration_summary.sql
\ir common/integrations/procedures/usp_integration_profile_reset_cursor.sql
\ir common/integrations/procedures/usp_integration_purge_history.sql
\ir common/integrations/procedures/usp_sync_job_enqueue.sql
\ir common/integrations/procedures/usp_sync_job_claim.sql
\ir common/integrations/procedures/usp_sync_job_heartbeat.sql
\ir common/integrations/procedures/usp_sync_page_apply.sql
\ir common/integrations/procedures/usp_sync_job_finish.sql
\ir common/integrations/procedures/usp_sync_job_release.sql
\ir common/integrations/procedures/usp_sync_job_cancel.sql
\ir common/integrations/procedures/usp_sync_job_recover_stale.sql
\ir common/integrations/procedures/usp_sync_job_list.sql
\ir common/integrations/procedures/usp_sync_job_get.sql
\ir common/integrations/procedures/usp_sync_error_add.sql
\ir common/integrations/procedures/usp_sync_error_list.sql

-- ---- Mailbox inbox ----
\ir procedures/mailbox/usp_mailbox_email_upsert.sql
\ir procedures/mailbox/usp_mailbox_get_active.sql
\ir procedures/mailbox/usp_mailbox_attachment_add.sql
\ir procedures/mailbox/usp_mailbox_attachments_done.sql
\ir procedures/mailbox/usp_mailbox_set_cursor.sql





COMMIT;

\echo 'Schema is up to date.'
