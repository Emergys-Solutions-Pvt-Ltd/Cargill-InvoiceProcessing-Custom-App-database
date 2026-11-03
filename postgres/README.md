# PostgreSQL schema (Supabase)

One PostgreSQL schema per module. Supabase exposes only `public` through its auto-generated REST API,
so these tables (including password hashes) are reachable only through the backend.

| Schema | Module (folder) | Objects |
|---|---|---|
| `app` | common (`common/`) | apps, master data, vendors / stations, integrations, lookups; shared result types |
| `app_auth` | auth (`auth/`) | users, user_applications, vw_user_summary, usp_user_* |
| `gpp` | GPP (`gpp/`) | **gpp_invoices** (+ legacy SF columns) and its child tables, invoice_ccpps, usp_invoice_* / usp_ccpp_* |
| `sjo` | SJO (`sjo/`) | **sjo_invoices** (+ SJO columns) and its child tables, erp_systems, usp_invoice_* / usp_invoice_sjo_fields_save |
| `rospbu` | ROSPBU (`rospbu/`) | **rospbu_invoices** and its child tables, usp_invoice_* |

The auth schema is `app_auth`, not `auth`: Supabase reserves `auth` for Supabase Auth (it has its own
`auth.users`). Objects reference each other schema-qualified (`app_auth.users`, `gpp.invoice_ccpps`, ...).
Databases deployed before the split are migrated by `deploy_schema.sql` itself: it moves the module
tables out of `app` with `ALTER TABLE ... SET SCHEMA` (rows, keys, indexes and identity sequences kept).
Master-data lists record their table's schema in `app.master_data_entities.schema_name` (erp-systems: sjo).

```
postgres/
  deploy_schema.sql      Create OR update the schema: one transaction, safe to re-run, never drops data
  reset_schema.sql       DESTRUCTIVE: DROP SCHEMA app CASCADE, then deploy (dev / demo only)
  seed.sql               Demo data mirroring the frontend mock (expects empty tables)
  seed_master_data.sql   Demo Configuration data (countries, states, cities, BUs, team codes, processes);
                         re-runnable, so it can be applied to an existing database
  auth/                  users, user_applications, usp_user_*, vw_user_summary (sign-in, User Access Management)
  common/                objects every app shares
    shared/              udt_code_result, udt_row_count_result, ufn_like_contains
    apps/                applications, app_modules, app_settings, app_team_members
    master-data/         teams, countries, states, cities, business_units, statuses, processes, registry
    lookups/             usp_lookup_get_all (dropdown sources)
    invoices/            vendors, country_stations, shared invoice result types, templates/ (the per-app
                         invoice SQL, see below) and migrations/ (one-time split of the old app.invoices)
    attachments/         udt_attachment_result (attachment tables are per app)
    integrations/        integrations, profiles, sync jobs / errors, audit log, usp_sync_page_apply
  gpp/                   General Payments: invoices/ (generated), invoice_ccpps + usp_ccpp_*
  sjo/                   SJO Invoice Processing: invoices/ (generated), erp_systems, SJO field functions
  rospbu/                ROSPBU Invoice Processing: invoices/ (generated)
  tools/                 generate-app-invoice-sql.cjs (writes <app>/invoices/** from the templates)

Each module folder holds tables/ (one file per table, globally numbered in dependency order),
types/ (udt_*_input request and udt_*_result response composite types), functions/ (ufn_*),
procedures/ (usp_* functions, in the module's schema) and views/ (vw_*). deploy_schema.sql includes them all.
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

### Invoices: one table set per app

There is no common invoice table. Each app has its own invoices table in its schema -
`gpp.gpp_invoices`, `sjo.sjo_invoices`, `rospbu.rospbu_invoices` - with its own child tables
(`<app>.invoice_line_items`, `invoice_source_emails`, `invoice_attachments`, `invoice_external_refs`)
and its own functions (`<app>.usp_invoice_list`, `usp_invoice_get_by_code`, `usp_invoice_create_batch`,
`usp_invoice_update_details` / `_status`, `usp_invoice_send_to_previous_team`, `usp_attachment_*`,
`usp_sync_invoice_apply`, `usp_integration_invoices_without_attachment`) and `<app>.vw_invoice_summary`.
Invoice codes and attachment ids are unique **per app**; `app.applications.db_schema` maps each app to
its schema.

- **Common core columns** (identical in every app table): code, module, vendor / CUIT, station, invoice
  numbers and dates, amounts, status (FK to `app.statuses`), reception dates, and the workflow fields of
  the Invoice Details page (process, origin / destination, team = "Stage", assigned user, claim, additional
  info, FileNet id, created / updated by).
- **App columns**: `gpp_invoices` also holds the legacy Salesforce "GP Invoice" fields (returned as
  `sf_fields`); `sjo_invoices` holds the SJO fields (country, BU, ERP, ID Fiscal, A.B. Number / Name,
  Flow Turn Down / Critical Vendor / Urgent Invoice - NULL until saved, returned as `sjo_fields`).
  CCPP rows (`gpp.invoice_ccpps`) belong to GPP invoices only.
- **Shared shapes** stay in `app`: `udt_invoice_result`, `udt_attachment_result`, `udt_line_item_result`,
  `udt_invoice_email_result`; each app has its own `udt_invoice_input` / `_list_result` / `_detail_result`.
- **Generated, not copied**: the per-app SQL is written once in `common/invoices/templates/*.sql.tpl`
  (placeholders `{{S}}` schema, `{{T}}` table, sections `{{#sjo}}...{{/sjo}}`) and generated into
  `<app>/invoices/` by `node database/postgres/tools/generate-app-invoice-sql.cjs` (`--check` fails
  when the generated files are out of date). Edit the templates, then regenerate and deploy.
- **Integrations**: `app.usp_sync_page_apply` keeps the job, counters, errors and watermark and calls
  the profile module's `<app>.usp_sync_invoice_apply` for each row.
- **Migration**: databases created before the split are migrated by `deploy_schema.sql` itself
  (`<app>/invoices/migrations/split_from_app_invoices.sql` copies each app's rows keeping ids, then
  `common/invoices/migrations/drop_app_invoices.sql` checks the counts and drops `app.invoices` and its
  child tables). It only dropped the foreign key `app.mailbox_emails.fk_mailbox_emails_invoice` of the
  mailbox tables (not created by these scripts); their owner must point them at the app's table.

### Configuration (master data)

Countries, states (per country), cities (per state), business units, teams (queues), statuses and
processes share one column set: `code, name, description, sort_order, is_active`. States and cities
also have a parent column, and statuses a pill `color`. `app.master_data_entities` lists them. The
`usp_master_data_*` functions build their SQL from that registry with `%I` quoting, so they only
ever touch these tables. Deleting an item that is still referenced (a country with states, a team
with members, a status used by invoices) raises `CA409`; deactivate it instead.

**Statuses drive invoices**: `invoices.status` references `statuses.code` (`ON UPDATE CASCADE`),
replacing the old fixed CHECK list. Invoice functions accept any active status, matched
case-insensitively. The four core statuses are created by `common/master-data/tables/18_statuses.sql`.

**Errors**: functions `RAISE` with custom SQLSTATEs `CA400`, `CA404` and `CA409`. The backend
maps them to HTTP 400/404/409 and returns the message, which is written to be shown to users.
Emails, usernames and search text are compared case-insensitively.

**Calling** (named notation, so argument order does not matter):

```sql
SELECT * FROM app_auth.usp_user_list(p_search => 'vazquez', p_page => 1, p_page_size => 5);
SELECT * FROM app.usp_invoice_create_batch(p_module_id => 1, p_created_by => 1,
  p_invoices => '[{"row_no":1,"invoice_code":"INV-GP-9001","vendor_name":"Molinos Agro S.A.",
                   "cuit":"30-50001234-9","amount":100,"status":"Pending","reception_date":"2026-10-21"}]');
```

### Legacy Salesforce fields (GP Invoice Detail page)

58 fields from the legacy Salesforce "GP Invoice" object with no other home (e.g. `po_number`,
`cae_number`, `jde_number`, `is_high_priority`, `pending_reason`) are columns of `gpp.gpp_invoices`
(formerly the 1:1 table `gpp.invoice_sf_fields`). `gpp.usp_invoice_get_by_code` returns them as
`sf_fields` (`gpp.udt_invoice_sf_fields_result`). No write path exists yet.

### SJO invoice fields (SJO Invoice Processing: list, Create / Bulk Upload, Invoice Details)

Country, BU and ERP (FKs to `app.countries`, `app.business_units` and the master-data list
`sjo.erp_systems` - Configuration > ERP Systems, `30_erp_systems.sql`), ID Fiscal, A.B. Number / A.B.
Name and the Flow Turn Down / Critical Vendor / Urgent Invoice flags are columns of `sjo.sjo_invoices`
(formerly the 1:1 table `sjo.invoice_sjo_fields`). Invoice ID is `invoice_code`, Assign To is
`assigned_user_id`. `sjo.usp_invoice_create_batch` requires country / BU / ERP (code or name) and
`id_fiscal` (vendor / CUIT / amount optional); `sjo.usp_invoice_list` (column `sjo_fields`, searchable
by ID Fiscal / A.B.) and `sjo.usp_invoice_get_by_code` return them via `sjo.ufn_invoice_sjo_fields`;
`sjo.usp_invoice_sjo_fields_save` is the Invoice Details "Save". `seed_master_data.sql` adds the
Central American countries, BU `CFN` and ERPs `JDE` / `SAP`.

### CCPP tab (GP Invoice Detail page)

`gpp.invoice_ccpps` (one invoice → many rows) already backed the `ccpps[]` array embedded in
`usp_invoice_get_by_code`'s response (used for "is CCPP Linked" and the per-row `product`). Its
UPGRADES section adds 52 more fields from a separate legacy Salesforce "GP CCPP" object (a
55-field export reconciled against this table 2026-11-02 - `../shared/handoffs/database.md`; 3
fields not carried over: the invoice link itself and two SF formulas derivable via the FK) so the
new CCPP tab (its own view/update/add screen, distinct from the unchanged Details tab) has a real
table to read and write, rather than overlapping with a second new table. `created_by` / `updated_by`
are real FKs to `app_auth.users`, same pattern as on the invoice tables; `owner_legacy_id` / `user_legacy_id`
are raw legacy ids (SF `Owner` is a polymorphic `Lookup(User,Group)`; SF `User` is plain text
despite the name). `invoice_id` references `gpp.gpp_invoices` (CCPP is GPP only). `usp_ccpp_list` lists an invoice's rows;
`usp_ccpp_save` adds (`p_id` NULL) or updates one row, requiring only `p_product` and `p_status`.

### Invoice integrations (Settings > SAP Configuration)

Tables `23_integrations` … `28_integration_audit_log` hold integration settings (provider-specific
JSON, encrypted secret), extraction profiles (target module, mapping, cursor), the sync job queue +
history, record-level errors, `invoice_external_refs` (unique `(source_system, external_key)`: one
invoice per source document) and the audit log. Functions under `common/integrations/procedures/`:

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
  `ALTER TABLE app.vendors ADD COLUMN IF NOT EXISTS email varchar(255);`. Leave the
  `CREATE TABLE` block alone so databases created earlier still receive the change.
- **Types / functions / views**: edit the file and re-run `deploy_schema.sql`. It drops every
  `usp_*` / `ufn_*` function, `vw_*` view and `udt_*` type of every module schema and recreates them in one transaction.
- **New files** must be added to `deploy_schema.sql`, after anything they depend on. New tables also go in
  `seed.sql` if they need demo data.
- Functions are not executable by `PUBLIC`. The backend connects as the database owner; if you use
  a dedicated role, grant it `USAGE ON SCHEMA app` and `EXECUTE ON ALL FUNCTIONS IN SCHEMA app`.
