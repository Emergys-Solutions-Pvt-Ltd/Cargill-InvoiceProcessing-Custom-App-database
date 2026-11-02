# PostgreSQL schema (Supabase)

Everything lives in schema **`app`**. Supabase exposes only `public` through its auto-generated
REST API, so these tables (including password hashes) are reachable only through the backend.

```
postgres/
  deploy_schema.sql      Create OR update the schema: one transaction, safe to re-run, never drops data
  reset_schema.sql       DESTRUCTIVE: DROP SCHEMA app CASCADE, then deploy (dev / demo only)
  seed.sql               Demo data mirroring the frontend mock (expects empty tables)
  seed_master_data.sql   Demo Configuration data (countries, states, cities, BUs, team codes, processes);
                         re-runnable, so it can be applied to an existing database
  tables/                One file per table (01_users.sql … 13_invoice_ccpps.sql, 14-20 master data)
  types/request/         udt_invoice_input (bulk invoice rows)
  types/response/        udt_*_result composite types: the shape of every function result
  functions/             ufn_like_contains (literal, case-insensitive "contains" search)
  views/                 vw_user_summary, vw_invoice_summary (shared SELECTs)
  procedures/<area>/     app.usp_* functions: apps, users, invoices, app_config, lookups
```

## Running

psql's `\ir` resolves includes relative to the script, so you can run these from any directory.
Put the password in `PGPASSWORD` (or `~/.pgpass`), never on the command line:

```bash
export PGPASSWORD='<password>'
psql "host=<host> port=5432 dbname=postgres user=<user> sslmode=require" -f database/postgres/deploy_schema.sql
```

Fresh database with demo data (demo logins use the password `password`):

```bash
psql "<connection>" -f database/postgres/reset_schema.sql
psql "<connection>" -f database/postgres/seed.sql
```

## Request / response types

| SQL Server original | PostgreSQL equivalent |
|---|---|
| Table-valued parameter `dbo.udt_IdList` / `udt_CodeList` | Native arrays `integer[]` / `text[]` |
| TVP `dbo.udt_InvoiceInput` | `jsonb` array, converted with `jsonb_populate_recordset(NULL::app.udt_invoice_input, …)`, so the type still defines the columns |
| Result set shaped by a `udt_*Result` table variable | `RETURNS SETOF app.udt_*_result` / `RETURNS app.udt_*_result` |
| Several result sets (page info + rows) | One set: list types carry `total_items, total_pages, page, page_size` on every row |
| Four result sets for invoice detail | One row of `udt_invoice_detail_result`: `invoice` plus `attachments`, `line_items` and `ccpps` as JSON built from the typed rows |

| Function | Parameters | Returns |
|---|---|---|
| `usp_application_list` | `p_codes text[]`, `p_filter_by_codes` | `SETOF udt_application_result` |
| `usp_app_module_get_by_slug` | `p_slug` | `SETOF udt_app_module_result` |
| `usp_user_get_for_login` | `p_login` (email or username, case-insensitive) | `SETOF udt_user_login_result` |
| `usp_user_get_by_id` | `p_user_id`, `p_active_only` | `SETOF udt_user_result` |
| `usp_user_touch_last_login` | `p_user_id` | `udt_row_count_result` |
| `usp_user_list` | `p_search`, `p_app_code`, `p_role`, `p_page`, `p_page_size` | `SETOF udt_user_list_result` |
| `usp_user_create` | user fields, `p_app_codes text[]` | `udt_user_result` |
| `usp_user_update` | `p_user_id`, optional fields, `p_app_codes text[]` (NULL = keep) | `udt_user_result` |
| `usp_invoice_list` | `p_module_id`, `p_search`, `p_status`, `p_page`, `p_page_size` | `SETOF udt_invoice_list_result` |
| `usp_invoice_get_by_code` | `p_invoice_code` | `SETOF udt_invoice_detail_result` |
| `usp_invoice_create_batch` | `p_module_id`, `p_created_by`, `p_invoices jsonb` | `SETOF udt_code_result` |
| `usp_invoice_update_status` | `p_invoice_code`, `p_status` | `udt_row_count_result` |
| `usp_attachment_get_by_id` | `p_attachment_id` | `SETOF udt_attachment_result` |
| `usp_ccpp_list` | `p_invoice_code` | `SETOF udt_ccpp_result` |
| `usp_ccpp_save` | `p_invoice_code`, `p_user_id`, `p_product`, `p_status`, `p_id` (NULL = add), optional legacy SF fields | `udt_ccpp_result` |
| `usp_team_list` | – | `SETOF udt_lookup_value_result` |
| `usp_app_settings_get` | `p_module_id` | `udt_app_settings_result` |
| `usp_app_settings_save` | `p_module_id`, optional settings, `p_updated_by` | `udt_app_settings_result` |
| `usp_team_member_list` | `p_module_id`, `p_team`, `p_search`, `p_page`, `p_page_size` | `SETOF udt_team_member_list_result` |
| `usp_team_member_add` | `p_module_id`, `p_name`, `p_email`, `p_alias`, `p_team` | `udt_team_member_result` |
| `usp_team_member_remove` | `p_module_id`, `p_member_ids integer[]` | `udt_row_count_result` |
| `usp_lookup_get_all` | – | `udt_lookups_result` (incl. active statuses with colors) |
| `usp_user_delete` | `p_user_id`, `p_deleted_by` | `udt_row_count_result` |
| `usp_master_data_entities` | – | `SETOF udt_master_data_entity_result` |
| `usp_master_data_list` | `p_entity`, `p_search`, `p_parent_id`, `p_include_inactive`, `p_page`, `p_page_size` | `SETOF udt_master_data_list_result` |
| `usp_master_data_options` | `p_entity`, `p_parent_id` | `SETOF udt_master_data_option_result` |
| `usp_master_data_save` | `p_entity`, `p_id` (NULL = create), code, name, description, parent, color, order, active | `udt_master_data_result` |
| `usp_master_data_delete` | `p_entity`, `p_id` | `udt_row_count_result` |

### Invoice workflow (Invoice Details page)

`tables/21_invoice_workflow.sql` adds to `app.invoices`: `process_id` (Processes), `origin_city_id` /
`destination_city_id` (Cities), `team_id` (current team / queue, shown as "Stage"), `assigned_user_id`,
`claim_number`, `additional_info` and `filenet_id`. `usp_invoice_update_details` saves them,
`usp_invoice_send_to_previous_team` moves an invoice to the active team ordered just before its current
one, and `usp_attachment_add` registers PDFs uploaded from the viewer.

### Configuration (master data)

Countries, states (per country), cities (per state), business units, teams (queues), statuses and
processes share one column set: `code, name, description, sort_order, is_active`. States and cities
also have a parent column, and statuses a pill `color`. `app.master_data_entities` lists them. The
`usp_master_data_*` functions build their SQL from that registry with `%I` quoting, so they only
ever touch these tables. Deleting an item that is still referenced (a country with states, a team
with members, a status used by invoices) raises `CA409`; deactivate it instead.

**Statuses drive invoices**: `invoices.status` references `statuses.code` (`ON UPDATE CASCADE`),
replacing the old fixed CHECK list. Invoice functions accept any active status, matched
case-insensitively. The four core statuses are created by `tables/18_statuses.sql`.

**Errors**: functions `RAISE` with custom SQLSTATEs `CA400`, `CA404` and `CA409`. The backend
maps them to HTTP 400/404/409 and returns the message, which is written to be shown to users.
Emails, usernames and search text are compared case-insensitively.

**Calling** (named notation, so argument order does not matter):

```sql
SELECT * FROM app.usp_user_list(p_search => 'vazquez', p_page => 1, p_page_size => 5);
SELECT * FROM app.usp_invoice_create_batch(p_module_id => 1, p_created_by => 1,
  p_invoices => '[{"row_no":1,"invoice_code":"INV-GP-9001","vendor_name":"Molinos Agro S.A.",
                   "cuit":"30-50001234-9","amount":100,"status":"Pending","reception_date":"2026-10-21"}]');
```

### Legacy Salesforce fields (GP Invoice Detail page)

`app.invoice_sf_fields` is a 1:1 satellite table (one row per invoice, created lazily) holding
58 fields from the legacy Salesforce "GP Invoice" object that have no other home in this schema
(e.g. `po_number`, `cae_number`, `jde_number`, `is_high_priority`, `pending_reason` - see the
table file's own header for the full reasoning and the small number of SF fields deliberately
*not* carried over as pure SF automation/derived-formula artifacts). `app.invoices.updated_by`
(parallel to `created_by`) also comes from this reconciliation. `usp_invoice_get_by_code` returns
it as `sf_fields` (NULL until the invoice has a row). No write path exists yet - that's the
obvious next piece once the read side is confirmed against the frontend's field list.

### CCPP tab (GP Invoice Detail page)

`app.invoice_ccpps` (one invoice → many rows) already backed the `ccpps[]` array embedded in
`usp_invoice_get_by_code`'s response (used for "is CCPP Linked" and the per-row `product`). Its
UPGRADES section adds 52 more fields from a separate legacy Salesforce "GP CCPP" object (a
55-field export reconciled against this table 2026-11-02 - `../shared/handoffs/database.md`; 3
fields not carried over: the invoice link itself and two SF formulas derivable via the FK) so the
new CCPP tab (its own view/update/add screen, distinct from the unchanged Details tab) has a real
table to read and write, rather than overlapping with a second new table. `created_by` / `updated_by`
are real FKs to `app.users`, same pattern as on `app.invoices`; `owner_legacy_id` / `user_legacy_id`
are raw legacy ids (SF `Owner` is a polymorphic `Lookup(User,Group)`; SF `User` is plain text
despite the name) - same shape as `app.invoice_sf_fields`. `usp_ccpp_list` lists an invoice's rows;
`usp_ccpp_save` adds (`p_id` NULL) or updates one row, requiring only `p_product` and `p_status`.

### Invoice integrations (Settings > SAP Configuration)

Tables `23_integrations` … `28_integration_audit_log` hold integration settings (provider-specific
JSON, encrypted secret), extraction profiles (target module, mapping, cursor), the sync job queue +
history, record-level errors, `invoice_external_refs` (unique `(source_system, external_key)`: one
invoice per source document) and the audit log. Functions under `procedures/integrations/`:

| Function | Purpose |
|---|---|
| `usp_integration_list` / `_get` / `_save` / `_delete` | Configuration CRUD (`_save` replaces the profiles; `version` for concurrency) |
| `usp_integration_set_secret` / `_get_secret` | Encrypted credentials (ciphertext only; never returned by `_get`) |
| `usp_integration_due_list` / `_set_next_run` | Scheduler |
| `usp_sync_job_enqueue` / `_claim` / `_heartbeat` / `_finish` / `_release` / `_cancel` / `_recover_stale` | Job queue (one active job per integration; claim with `SKIP LOCKED`) |
| `usp_sync_page_apply` | Idempotent upsert of one page: row savepoints, counters, errors and cursor in one transaction; never overwrites status / team / assignee |
| `usp_sync_job_list` / `_get`, `usp_sync_error_add` / `_list`, `usp_integration_summary` | History, errors, dashboard |
| `usp_integration_profile_reset_cursor`, `usp_integration_purge_history`, `usp_integration_audit_add` | Full re-sync, retention, audit |
| `usp_integration_invoices_without_attachment` | ECM providers (OnBase): which invoices still need their source document attached |

`tests/test_integrations.sql` exercises them inside a rolled-back transaction.

## Changing the schema

- **Tables**: append guarded statements to the table file's UPGRADES section, for example
  `ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS po_number varchar(30);`. Leave the
  `CREATE TABLE` block alone so databases created earlier still receive the change.
- **Types / functions / views**: edit the file and re-run `deploy_schema.sql`. It drops every
  `app.usp_*` / `ufn_*` function, `vw_*` view and `udt_*` type and recreates them in one transaction.
- **New files** must be added to `deploy_schema.sql`, after anything they depend on. New tables also go in
  `seed.sql` if they need demo data.
- Functions are not executable by `PUBLIC`. The backend connects as the database owner; if you use
  a dedicated role, grant it `USAGE ON SCHEMA app` and `EXECUTE ON ALL FUNCTIONS IN SCHEMA app`.
