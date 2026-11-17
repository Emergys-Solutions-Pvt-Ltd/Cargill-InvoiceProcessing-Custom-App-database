# Database repo rules (PostgreSQL / Supabase)

Also follow the workspace rules in `../CLAUDE.md`. Owner agent: database-agent (`DB`).

## What this repo is
A DACPAC-style database project for Supabase / PostgreSQL 17 (see `README.md`, `docs/DEPLOYMENT.md`).
Object files are **declarative**; `postgres/objects.sql` lists them in dependency order. `Build/*.sh` (run in the
`Docker/Dockerfile` tool image) builds `Artifacts/schema.sql`, validates it on a disposable PostgreSQL, compiles a
pgschema model and generates reviewed per-schema diffs; `.vela.yml` deploys DEV / UAT / PROD.
`postgres/deploy_schema.sql` is only the LOCAL / docker bootstrap (it drops and recreates programmability).

Schemas: `app` (shared), `app_auth` (never `auth` — Supabase reserves it), `gpp`, `sjo`, `rospbu`.

## Folder layout
- `postgres/<module>/{tables,types,functions,procedures,views,triggers}`, one object per file; `postgres/objects.sql` manifest;
  `postgres/predeploy/` (schemas, privileges), `postgres/postdeploy/` (idempotent reference data);
  `ManualMigrations/{Schema,Data}` (renames, backfills - run by hand); `Build/`, `config/`, `tests/deploy/`, `Docker/`.
  Modules: `auth/`, `common/{shared,apps,master-data,lookups,invoices,attachments,integrations}`, `gpp/`, `sjo/`, `rospbu/`.
- `common/invoices/templates/*.sql.tpl` → generated into `<app>/invoices/**`. **Edit templates only.**
- `tests/test_<area>.sql` — ASSERT blocks in a transaction that rolls back.
- `tools/generate-app-invoice-sql.cjs` — the generator.

## How to change things
| Change | How |
|---|---|
| Add/alter a column, constraint, index | Edit the `CREATE TABLE` / `CREATE INDEX` in the table file (declarative). Never append `ALTER TABLE`; the plan generates it. |
| New table | New `NN_<table>.sql` in the right module's `tables/`; add an `\ir` line to `postgres/objects.sql` after its dependencies; demo data in `seed.sql`, reference data in `postdeploy/`. |
| New/changed function, type, view, trigger | Edit/create the file (name = object name); new files go in `objects.sql` after dependencies. |
| Per-app invoice structure | Edit `.sql.tpl`, run `node postgres/tools/generate-app-invoice-sql.cjs`, then `… --check`. |
| Rename / one-time data move | New file in `ManualMigrations/Schema` or `/Data` (`YYYY-MM-DD_<name>.sql`). Never edit applied ones. |
| Check a change | `bash tests/deploy/run-local.sh` (Docker) or `Build/validate-schema.sh` against a disposable PostgreSQL. |

## Naming
- Tables `NN_<table>.sql`; tables snake_case plural, schema-qualified.
- PK `id uuid DEFAULT gen_random_uuid()`; FK `<entity>_id`; booleans `is_*` / `has_*`;
  timestamps `*_at timestamptz(0)`; actors `*_by`; `created_at` / `updated_at` default `now()`.
- Functions `usp_<entity>_<action>` (e.g. `usp_team_member_add`); helpers `ufn_*`.
- Parameters `p_*`; locals `v_*`.
- Types: input `udt_<entity>_input` (passed as `jsonb`, unpacked with `jsonb_populate_recordset`);
  output `udt_<entity>_result`; paged `udt_<entity>_list_result` with `total_items, total_pages, page, page_size` on every row.
- Views `vw_*`.
- Constraints/indexes `<prefix>_<table>_<detail>`: `pk_ fk_ ck_ uq_ ix_` (e.g. `fk_cities_state`).
  `uq_` vs `ux_` is undecided — see `../DECISIONS.md` "To confirm"; ask before choosing.

## Rules
- Errors: `RAISE EXCEPTION '<user-facing message>' USING ERRCODE = 'CA400' | 'CA404' | 'CA409'` only.
- Functions are not executable by PUBLIC. Compare search text and emails case-insensitively.
- Master data is deleted only when unreferenced (else CA409; deactivate instead).
- Changing a `usp_*` / `udt_*` signature breaks the backend immediately on deploy → handoff to BE + user approval first.
- Never drop/rename tables or columns without approval.

## Protected — do not edit / do not run
- Do not edit: `<app>/invoices/**` (generated), applied `ManualMigrations/**`.
- Sensitive data: `app_auth.users.password_hash`, `app.integrations.secret_ciphertext`.
- Do not run: `reset_schema.sql` (drops all 5 schemas), `seed.sql` (known demo passwords), `docker-init.sh`,
  `deploy_schema.sql` or `Build/deploy.sh apply` against Supabase. Every command against a real database needs the
  user's approval; disposable local containers (tests/deploy) are fine.

## Commands
- Generate: `node postgres/tools/generate-app-invoice-sql.cjs` · Check: `… --check`
- Deploy: the Vela pipeline (`docs/DEPLOYMENT.md`); by hand: `Build/deploy.sh plan|validate|apply|verify <env>` in the tool image
- Tests: `bash tests/deploy/run-local.sh [ids]` (Docker; scenario tests + SQL tests on disposable PostgreSQL)

## Known issues (don't "fix" without a task)
README is partly outdated (mailbox tables, `sqlserver/`, `../shared/handoffs/database.md`, location of
`usp_integration_invoices_without_attachment`); `postgres/functions/` holds only `ufn_mailbox_row.sql`; table numbering has gaps (10–13, 21–22, 27).
