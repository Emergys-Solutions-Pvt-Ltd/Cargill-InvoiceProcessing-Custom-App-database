# Agent changelog — Cargill-InvoiceProcessing-Custom-App-database

What each agent changed in this repo, and why. Newest entry on top. Never delete or rewrite old entries.
Written for a future developer who has no context.

## Entry format
```markdown
## YYYY-MM-DD — <short title> (Feature: <feature-name>)
**Agent:** database-agent · **Status:** Done | Partial | Blocked · **Handoffs:** H-xx-yy-nnn

### What changed
- `path/to/file` — what changed

### Why
<the reason / the request it answers>

### Cross-repo impact
- <repo>: <what they must know or do> (handoff ID)

### New env vars / dependencies / commands for the user
- None

### Still to do / known issues
- None
```

---

## 2026-11-16 — DACPAC-style database project: build, pgschema plans, Vela pipeline (Feature: database-devops)
**Agent:** database-agent · **Status:** Done locally (no real environment deployed) · **Handoffs:** none

### What changed
- `docs/ASSESSMENT.md` — phase-1 assessment (inventory, verified tool behaviour, risks).
- Table files folded declaratively: every UPGRADES section merged into its `CREATE TABLE` (verified: a build of the new
  files and of the old files are identical for pgschema in all 5 schemas). Reference rows moved to
  `postgres/postdeploy/{10_applications_db_schema,20_statuses,30_master_data_entities}.sql`; schemas / default privileges
  to `postgres/predeploy/00_schemas.sql`; `postgres/objects.sql` = ordered object manifest.
- `postgres/deploy_schema.sql` — now local bootstrap only (predeploy + objects.sql + postdeploy).
- `common/shared/migrations/ids_to_uuid.sql` moved to `ManualMigrations/Schema/2026-11-12_ids_to_uuid.sql`.
- `postgres/seed_master_data.sql` — fixed: updated the removed `app.invoices`; now updates each app's invoice table
  (fresh docker databases failed to seed before).
- New: `Build/{common,build-schema,validate-schema,generate-plan,deploy,verify}.sh`, `Build/lib/dbproject.py`,
  `config/project.conf`, `config/environments/{dev,uat,prod,local}.env`, `Docker/Dockerfile`, `.vela.yml`, `.sqlfluff`,
  `.gitattributes`, `.gitignore`, `.dockerignore`, `tests/deploy/{scenarios,run-local}.sh`, `docs/DEPLOYMENT.md`,
  `ManualMigrations/README.md`; README / CLAUDE.md / DECISIONS (D-DB-004) updated.

### Why
User request: source-controlled PostgreSQL project with build, validation, schema comparison, generated deployment
SQL + JSON plan, DEV/UAT/PROD deployments through Vela, open-source tools only.

### Cross-repo impact
- backend: `docker-compose.yml` still mounts `postgres/` and runs `deploy_schema.sql` + `seed.sql` (still works).
  No object definitions changed.

### New env vars / dependencies / commands for the user
- Vela repo secrets `{dev,uat,prod}_db_{host,port,name,user,password}`; tool image to publish (replace `TOOLS_IMAGE`).
- `bash tests/deploy/run-local.sh` (Docker) runs the deployment scenario tests.

### Still to do / known issues
- Not run in Vela or against Supabase yet (no access): first DEV run must be watched. `dev` / `uat` branches do not exist yet.

---

## 2026-11-16 — Mailbox settings + Inbox objects converted from integer ids to uuid (Feature: email-configuration + email-inbox)
**Agent:** database-agent · **Status:** Done (not deployed; nothing executed against any DB) · **Handoffs:** none (contract in parent `DECISIONS.md` D-024, D-025)

### What changed
Every id / `*_id` type column, parameter and local variable became `uuid`. Counts and paging (`attachment_count`,
`total_items`, `total_pages`, `page`, `page_size`, `p_page`, `p_page_size`, `v_rows`) stay `integer`. Function names,
parameter names and order, defaults, behaviour, error codes and messages are unchanged.
- `postgres/types/response/udt_mailbox_detail_result.sql`, `udt_mailbox_list_result.sql` — `id`, `module_id` → uuid.
- `postgres/types/response/udt_mailbox_email_list_result.sql`, `udt_mailbox_email_detail_result.sql` — `id`, `mailbox_id`,
  `invoice_id` → uuid.
- `postgres/types/response/udt_mailbox_option_result.sql` — `id` → uuid.
- `postgres/functions/ufn_mailbox_row.sql` — `ufn_mailbox_row(p_mailbox_id uuid)`.
- `postgres/procedures/mailbox/usp_mailbox_save.sql` — `p_mailbox_id uuid`; locals `v_id`, `v_module_id`,
  `v_current_module_id` uuid. Create still takes the new id from `INSERT … RETURNING id` (table default `gen_random_uuid()`).
- `usp_mailbox_delete(p_mailbox_id uuid)`, `usp_mailbox_get_by_id(p_mailbox_id uuid)`.
- `usp_mailbox_email_list(p_application_code text, p_status text DEFAULT NULL, p_mailbox_id uuid DEFAULT NULL,
  p_search text DEFAULT NULL, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)`.
- `usp_mailbox_email_get_by_id(p_application_code text, p_email_id uuid)`.
- `usp_mailbox_email_set_status(p_application_code text, p_email_id uuid, p_status text, p_note text DEFAULT NULL)`;
  local `v_invoice_id` uuid.
- `usp_mailbox_attachment_list(p_email_id uuid)`, `usp_mailbox_attachment_get_by_id(p_attachment_id uuid)`.
- `usp_mailbox_list` and `usp_mailbox_list_for_application` — no text change needed (no id parameters); they return the
  converted types. `common/apps/procedures/usp_app_module_list.sql` — checked, no change (already returns uuid ids).
- `postgres/tests/test_mailboxes.sql`, `postgres/tests/test_mailbox_emails.sql` — ids read from `t_ctx` with `::uuid`;
  unknown ids use `'00000000-0000-0000-0000-000000000000'::uuid` instead of `-1`; test `invoice_id` values 123 / 77 became
  fixed uuids `…000000000123` / `…000000000077`. Order assertions that relied on increasing integer ids were rewritten:
  the e3 / e4 received_at tie (list order `received_at DESC, id DESC`) now computes the expected pair order at setup from
  the two uuids (`t_ctx 'tie34'`), and the attachment list checks the file set by name plus "returned order = order by id".
- `postgres/deploy_schema.sql` — no change (same file names; its DROP loop removes the old integer overloads on a full run).

### Why
Ashish Shende's "GUID changes" commit (0e25c59, merged locally in b9a4560) converted all tables, types and functions to uuid
ids (D-024). These mailbox / Inbox files were written before that merge and still used integer ids, so they no longer matched
`app.mailboxes`, `app.mailbox_emails`, `app.mailbox_email_attachments` and `app.app_modules`. D-025 approved the conversion.

### Cross-repo impact
- Backend and frontend convert their side at the same time (D-025): ids are strings (uuid) in the API.
- Supabase: `CREATE OR REPLACE` with a new parameter type creates an overload, so the old integer-signature functions
  must be dropped there first (and the changed types recreated). The main session builds that paste-ready script (D-019).

### New env vars / dependencies / commands for the user
- None in this repo. Supabase script: see Cross-repo impact.

### Still to do / known issues
- Not executed anywhere (no local DB). Tests not run.
- "ordered by id" (attachment list, tie-breakers in `usp_mailbox_list`, `usp_mailbox_email_list`,
  `usp_mailbox_list_for_application`, and `a.id` in `usp_app_module_list`) is still deterministic but no longer means
  insertion order. Left unchanged on purpose (no behaviour change in this task).

## 2026-11-05 — Inbox functions: received emails per application (Feature: email-inbox)
**Agent:** database-agent · **Status:** Done (not deployed; nothing executed against any DB) · **Handoffs:** none (contract fixed in parent `DECISIONS.md` D-023)

### What changed
- `postgres/types/response/udt_mailbox_email_list_result.sql` — new type: `id, mailbox_id, mailbox_address, module_slug,
  module_name, from_name, from_address, subject, received_at, attachment_count integer, status, status_note, invoice_id,
  total_items, total_pages, page, page_size`.
- `postgres/types/response/udt_mailbox_email_detail_result.sql` — new type: `id, mailbox_id, mailbox_address, module_slug,
  module_name, from_name, from_address, to_addresses, cc_addresses, subject, body_text, received_at, attachment_count,
  status, status_note, invoice_id, created_at, updated_at`.
- `postgres/types/response/udt_mailbox_option_result.sql` — new type: `id, address, folder, module_slug, module_name`.
- `postgres/procedures/mailbox/usp_mailbox_email_list.sql` — `app.usp_mailbox_email_list(p_application_code text,
  p_status text DEFAULT NULL, p_mailbox_id integer DEFAULT NULL, p_search text DEFAULT NULL, p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 10) RETURNS SETOF app.udt_mailbox_email_list_result`. Scope: mailbox → module → application
  with `code = p_application_code` (exact match, same as other functions using `applications.code`). Search subject / from name /
  from address via `ufn_like_contains`. Order `received_at DESC, id DESC`. Page clamped. `attachment_count` = non-inline
  attachments. CA400 'PageSize must be between 1 and 100.' and 'Status must be New, Processed, Ignored or Failed.'
- `postgres/procedures/mailbox/usp_mailbox_email_get_by_id.sql` — `app.usp_mailbox_email_get_by_id(p_application_code text,
  p_email_id integer) RETURNS SETOF app.udt_mailbox_email_detail_result`; no row when not found or another application.
- `postgres/procedures/mailbox/usp_mailbox_email_set_status.sql` — `app.usp_mailbox_email_set_status(p_application_code text,
  p_email_id integer, p_status text, p_note text DEFAULT NULL) RETURNS app.udt_mailbox_email_detail_result`.
  New→Ignored, Failed→Ignored, Ignored→New; same status = no-op (note not changed either) that returns the row.
  CA400 'Status must be New or Ignored.' / 'Note must be at most 1000 characters.' (after trim);
  CA404 'Email not found.' (also another application); CA409 'This email is linked to an invoice and can''t be changed.'
  (status Processed or invoice_id set — checked before the no-op) and 'A failed email can only be ignored.' (Failed→New).
  Note: Ignored = given note or keep current; New = given note or NULL; blank note = not given. Row locked `FOR UPDATE OF e`;
  `updated_at = now()` on a change. Returns the row through `usp_mailbox_email_get_by_id`.
- `postgres/procedures/mailbox/usp_mailbox_attachment_list.sql` — `app.usp_mailbox_attachment_list(p_email_id integer)
  RETURNS SETOF app.udt_mailbox_attachment_result` (existing type, unchanged): non-inline only, ordered by id.
- `postgres/procedures/mailbox/usp_mailbox_attachment_get_by_id.sql` — `app.usp_mailbox_attachment_get_by_id(p_attachment_id integer)
  RETURNS SETOF app.udt_mailbox_attachment_result`; no row when not found (inline attachments are returned too).
- `postgres/procedures/mailbox/usp_mailbox_list_for_application.sql` — `app.usp_mailbox_list_for_application(p_application_code text)
  RETURNS SETOF app.udt_mailbox_option_result`: active and inactive mailboxes of the application, ordered
  `lower(address), lower(folder), id`.
- `postgres/deploy_schema.sql` — `\ir` lines only: the three types after `udt_mailbox_list_result`; the six functions after
  `usp_mailbox_delete`. The drop loop already drops every `app.usp_*` / `app.udt_*`, so they are recreated on each run.
- `postgres/tests/test_mailbox_emails.sql` — new test (BEGIN … ROLLBACK; own applications `ZZINB` / `ZZINB2`, modules,
  mailboxes; emails via `usp_mailbox_email_upsert`, attachments via `usp_mailbox_attachment_add`): scope per application
  (list / get / set_status CA404), status filter + CA400, mailbox filter, search (incl. literal `%` / `_`), order incl. same
  `received_at` tie-break, paging + clamping + page size CA400, row content, `attachment_count` ignores inline, detail,
  every allowed / refused status change with exact CA409 messages, note rules, attachment list / get, mailbox options.

### Why
The application Inbox (parent `DECISIONS.md` D-020, D-021, D-023) lists received emails per application, shows one email
with its PDFs, and lets users Ignore / restore an email. No table change: every column already exists in
`tables/30_mailbox_emails.sql` and `31_mailbox_email_attachments.sql`. New result types are used so the poller's
`udt_mailbox_email_result` and the mailbox settings types stay unchanged.

### Cross-repo impact
- backend: the functions and types above are the DB → BE contract for `/api/apps/:appId/mailbox-emails`,
  `/api/apps/:appId/mailboxes` and `/api/files/mailbox-attachments/{id}` (D-023). `p_application_code` is
  `app.applications.code` as resolved by `requireAppAccess` (exact match). The attachment functions are not scoped to an
  application: the backend must check the email with `usp_mailbox_email_get_by_id` first.
- No existing `usp_*` / `udt_*` signature changed; poller and mailbox settings functions untouched.

### New env vars / dependencies / commands for the user
- None new. Deploy to Supabase via the paste-ready SQL the main session prepares (D-019): the 3 types, then the 6 functions,
  then optionally the test (without `\set` / `\echo`; it rolls back).

### Still to do / known issues
- Not executed against any database: only static checks (all 196 `\ir` paths exist, files re-read, no non-ASCII).
  The test is the first real check.
- New files use LF line endings; most existing files use CRLF (no effect on PostgreSQL).

## 2026-11-04 — Mailbox settings functions and app module list (Feature: email-configuration)
**Agent:** database-agent · **Status:** Done (not deployed; not run against any DB) · **Handoffs:** H-BE-DB-001, H-BE-DB-002, H-DB-USR-002

### What changed
- `postgres/types/response/udt_mailbox_detail_result.sql` — new type: `id, address, folder, module_id, module_slug,
  module_name, is_active, last_polled_at, last_error, created_at, updated_at` (no `delta_link`).
- `postgres/types/response/udt_mailbox_list_result.sql` — new type: the same 11 columns + `total_items, total_pages, page, page_size`.
- `postgres/functions/ufn_mailbox_row.sql` — new helper `app.ufn_mailbox_row(p_mailbox_id integer) RETURNS app.udt_mailbox_detail_result`
  (joins `app.app_modules` for slug / name; NULL when not found). Single place the row shape is built.
- `postgres/procedures/mailbox/usp_mailbox_list.sql` — `app.usp_mailbox_list(p_search text DEFAULT NULL, p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 10) RETURNS SETOF app.udt_mailbox_list_result`; search address / folder / module name via
  `ufn_like_contains`; order `lower(address), lower(folder), id`; CA400 page size outside 1-100. Same pattern as `usp_sync_job_list`.
- `postgres/procedures/mailbox/usp_mailbox_get_by_id.sql` — `app.usp_mailbox_get_by_id(p_mailbox_id integer)
  RETURNS SETOF app.udt_mailbox_detail_result` (no row = not found).
- `postgres/procedures/mailbox/usp_mailbox_save.sql` — `app.usp_mailbox_save(p_mailbox_id integer, p_address text,
  p_folder text DEFAULT 'inbox', p_module_slug text DEFAULT NULL, p_is_active boolean DEFAULT true) RETURNS app.udt_mailbox_detail_result`.
  NULL id = create. CA400 required / length / email format / missing, unknown or inactive module; CA404 unknown id;
  CA409 duplicate address + folder (case-insensitive, incl. unique_violation race). On update the current module is accepted
  even when inactive (D-016). An address or folder change (exact comparison) clears `delta_link`, `last_polled_at`, `last_error` (D-017).
  Row locked FOR UPDATE on update; `updated_at = now()`.
- `postgres/procedures/mailbox/usp_mailbox_delete.sql` — `app.usp_mailbox_delete(p_mailbox_id integer) RETURNS app.udt_row_count_result`.
  CA404 not found; CA409 "This mailbox has received emails and can't be deleted. Set it to Inactive instead." (D-013);
  FOR UPDATE lock + `foreign_key_violation` fallback to the same CA409.
- `postgres/common/apps/procedures/usp_app_module_list.sql` — `app.usp_app_module_list() RETURNS SETOF app.udt_app_module_result`
  (existing type): active modules of active applications, `ORDER BY a.id, lower(m.name), m.id` (D-015).
- `postgres/deploy_schema.sql` — `\ir` lines only: the two types after `udt_mailbox_email_result`; `ufn_mailbox_row` after
  `ufn_external_ref_count` (helper functions); the four procedures after `usp_mailbox_set_cursor`; `usp_app_module_list` after
  `usp_app_module_get_by_slug`. The existing drop loop already drops every `app.usp_*`, `app.ufn_*` and `app.udt_*` composite type,
  so the new objects are recreated on each run like the others.
- `postgres/tests/test_mailboxes.sql` — new test (BEGIN … ROLLBACK, own test application `ZZMBX` + modules, no seed needed):
  module list, create + get, validation, inactive module on create, duplicates, not found, list search / order / paging,
  D-016 (keep current inactive module; switching to another inactive module → CA400), D-017 (address / folder change clears
  poll status; is_active-only and module-only changes keep it), delete rules.

### Why
Settings > Email Configuration > Email Registration needs list / save / delete for `app.mailboxes` (H-FE-BE-001 → H-BE-DB-001),
and the "Target application" dropdown needs a module list (D-014, D-015 → H-BE-DB-002). Decisions: parent `DECISIONS.md`
D-012, D-013, D-015, D-016, D-017, D-018a/b/e/f/g. A new result type is used so `udt_mailbox_result` (poller) stays unchanged.
No table change: every column already exists in `tables/29_mailboxes.sql`. No seed mailbox (D-018g).

### Cross-repo impact
- backend: new functions and types above are the contract for `/api/mailboxes` and `/api/app-modules` (H-BE-DB-001, H-BE-DB-002 responses
  list signatures and messages). The backend `moduleSlug` pre-check must allow the row's current slug on update (D-016).
- No existing `usp_*` / `udt_*` signature changed; poller functions untouched.

### New env vars / dependencies / commands for the user
- None new. Run (user, H-DB-USR-002): local `deploy_schema.sql` twice, `tests/test_integrations.sql`, `tests/test_mailboxes.sql`;
  then `deploy_schema.sql` on Supabase (can be combined with H-DB-USR-001).

### Still to do / known issues
- Not executed against any database by the agent: only static checks (every `\ir` path exists, files re-read). The tests are
  the first real check.
- Address format check in the DB is a simple `x@y.z` regex; the backend does the full validation. Folder format is checked only by the backend (D-018e).
- Mailbox files still sit outside the module layout (D-018a; moving them to `common/mailbox/` is a later task).

## 2026-11-04 — Baseline: state before agents (Feature: baseline)
**Agent:** setup (from repo analysis) · **Status:** Done · **Handoffs:** H-BE-DB-001, H-DB-USR-001

### What exists (9 commits on main, 2026-10-23 → 2026-11-04)
- Foundation: schemas `app`, `app_auth`; users, apps, modules, master data, lookups, teams (`Initial Code Commit`)
- Integrations: SAP, OnBase, S3 storage columns on attachments (`SAP integration`, `Onbase Integration`, `S3 Integration`)
- Invoices: source email for PDF; GPP legacy Salesforce fields + CCPP table; SJO fields
- Per-app schema split: `gpp`, `sjo`, `rospbu` with generated invoice SQL from templates (`app soecific schema`)
- Mailbox inbox: `app.mailboxes`, `mailbox_emails`, `mailbox_email_attachments` + types and procedures (af60749)

### Why
Recorded as the starting point so later entries have context. Reasons per commit: needs confirmation from the user.

### Cross-repo impact
- backend: calls the `usp_*` functions listed in the backend report.

### Still to do / known issues
- Mailbox types/functions and 4 attachment columns not deployed to Supabase as of 2026-11-03 (H-DB-USR-001).
- No list/save/delete mailbox functions known for the settings screen (H-BE-DB-001).
- GPP legacy Salesforce fields have no write path. ROSPBU has no app-specific fields.
- `app.mailbox_emails.invoice_id` has no FK (by design after the split).
- README partly outdated; `postgres/functions/` empty; stray note in `tables/31_mailbox_email_attachments.sql`.
