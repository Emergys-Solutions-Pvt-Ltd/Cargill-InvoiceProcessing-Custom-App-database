-- =====================================================================
-- objects.sql - the ordered manifest of the schema object files (the database "project file").
--
-- One \ir line per object file, in dependency order (tables, then types, helper functions and views,
-- then the usp_* functions). Every *.sql file under the module folders must be listed exactly once:
-- Build/build-schema.sh fails on unlisted, missing or duplicate files.
-- Used by:
--   Build/build-schema.sh  -> Artifacts/schema.sql (consolidated desired state)
--   deploy_schema.sql      -> local / docker bootstrap
-- Not listed here: predeploy/ (schemas, privileges) and postdeploy/ (reference data).
-- =====================================================================

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
\ir common/invoices/tables/46_invoice_audit_log.sql

-- ---- Mailbox inbox (background email reading, Inbox page) ----
\ir tables/29_mailboxes.sql
\ir tables/30_mailbox_emails.sql
\ir tables/31_mailbox_email_attachments.sql

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
\ir common/invoices/types/udt_invoice_audit_result.sql
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
\ir types/response/udt_mailbox_detail_result.sql
\ir types/response/udt_mailbox_list_result.sql
\ir types/response/udt_mailbox_email_list_result.sql
\ir types/response/udt_mailbox_email_detail_result.sql
\ir types/response/udt_mailbox_option_result.sql

-- ---- Helper functions & views ----
\ir common/shared/functions/ufn_like_contains.sql
\ir common/master-data/functions/ufn_master_data_select_sql.sql
\ir sjo/functions/ufn_invoice_sjo_fields.sql
\ir rospbu/functions/ufn_invoice_rospbu_fields.sql
\ir common/integrations/functions/ufn_integration_row.sql
\ir common/integrations/functions/ufn_sync_job_row.sql
\ir common/integrations/functions/ufn_external_ref_count.sql
\ir functions/ufn_mailbox_row.sql
\ir common/invoices/functions/ufn_invoice_audit_label.sql
\ir common/invoices/functions/ufn_invoice_audit_trigger.sql
\ir auth/views/vw_user_summary.sql
\ir gpp/invoices/views/vw_invoice_summary.sql
\ir sjo/invoices/views/vw_invoice_summary.sql
\ir rospbu/invoices/views/vw_invoice_summary.sql

-- ---- Stored functions ("procedures") ----
\ir common/apps/procedures/usp_application_list.sql
\ir common/apps/procedures/usp_app_module_get_by_slug.sql
\ir common/apps/procedures/usp_app_module_list.sql

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
\ir gpp/invoices/procedures/usp_invoice_audit_list.sql
\ir sjo/invoices/procedures/usp_invoice_list.sql
\ir sjo/invoices/procedures/usp_invoice_get_by_code.sql
\ir sjo/invoices/procedures/usp_invoice_create_batch.sql
\ir sjo/invoices/procedures/usp_invoice_update_status.sql
\ir sjo/invoices/procedures/usp_invoice_update_details.sql
\ir sjo/invoices/procedures/usp_invoice_send_to_previous_team.sql
\ir sjo/invoices/procedures/usp_attachment.sql
\ir sjo/invoices/procedures/usp_sync_invoice_apply.sql
\ir sjo/invoices/procedures/usp_invoice_audit_list.sql
\ir rospbu/invoices/procedures/usp_invoice_list.sql
\ir rospbu/invoices/procedures/usp_invoice_get_by_code.sql
\ir rospbu/invoices/procedures/usp_invoice_create_batch.sql
\ir rospbu/invoices/procedures/usp_invoice_update_status.sql
\ir rospbu/invoices/procedures/usp_invoice_update_details.sql
\ir rospbu/invoices/procedures/usp_invoice_send_to_previous_team.sql
\ir rospbu/invoices/procedures/usp_attachment.sql
\ir rospbu/invoices/procedures/usp_sync_invoice_apply.sql
\ir rospbu/invoices/procedures/usp_invoice_audit_list.sql
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
\ir procedures/mailbox/usp_mailbox_list.sql
\ir procedures/mailbox/usp_mailbox_get_by_id.sql
\ir procedures/mailbox/usp_mailbox_save.sql
\ir procedures/mailbox/usp_mailbox_delete.sql
\ir procedures/mailbox/usp_mailbox_email_list.sql
\ir procedures/mailbox/usp_mailbox_email_get_by_id.sql
\ir procedures/mailbox/usp_mailbox_email_set_status.sql
\ir procedures/mailbox/usp_mailbox_attachment_list.sql
\ir procedures/mailbox/usp_mailbox_attachment_get_by_id.sql
\ir procedures/mailbox/usp_mailbox_list_for_application.sql

-- ---- Triggers (after the tables and their trigger functions) ----
\ir gpp/invoices/triggers/trg_gpp_invoices_audit.sql
\ir sjo/invoices/triggers/trg_sjo_invoices_audit.sql
\ir rospbu/invoices/triggers/trg_rospbu_invoices_audit.sql
