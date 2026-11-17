# Phase 1 - Repository assessment (2026-11-16)

Scope: the `database` repository (GitHub `Emergys-Solutions-Pvt-Ltd/Cargill-InvoiceProcessing-Custom-App-database`)
and how the sibling `backend` / `frontend` repositories consume it. Nothing was changed before this report was written.

## 1. What exists

| Area | Finding |
|---|---|
| Git | Separate repos for `database`, `backend`, `frontend`. Only branch `main` exists (no `dev` / `uat`). |
| Layout | `postgres/<module>/{tables,types,functions,procedures,views}` - one object per file. Modules: `auth`, `common/*`, `gpp`, `sjo`, `rospbu`, plus root-level `tables/`, `types/response/`, `procedures/mailbox/`, `functions/` (mailbox objects). |
| Schemas | `app`, `app_auth`, `gpp`, `sjo`, `rospbu` (Supabase reserves `auth`). |
| Objects (clean PG 17 install) | 41 tables, 133 indexes, 4 views, 110 functions (`usp_*` / `ufn_*`, no procedures), 53 composite types, 0 triggers, 0 sequences (uuid keys), extension `plpgsql` only. |
| Entry point | `postgres/deploy_schema.sql`: one transaction, `\ir` of ~230 files in hand-maintained dependency order. Drops and recreates every `usp_`/`ufn_`/`vw_`/`udt_` object on each run. |
| Table changes | "Guarded UPGRADES" sections appended to each table file (`ADD COLUMN IF NOT EXISTS`, `DO $$ ... $$`). 40+ table files have them; the CREATE blocks are **not** the final shape (a build without UPGRADES fails). |
| Generated SQL | `tools/generate-app-invoice-sql.cjs` (Node) renders `common/invoices/templates/*.sql.tpl` into `gpp|sjo|rospbu/invoices/**`; `--check` detects drift. |
| One-time migration | `common/shared/migrations/ids_to_uuid.sql` (integer -> uuid keys), included in every deploy, no-op once converted. |
| Data in schema scripts | Some table files insert reference rows (e.g. `sjo/tables/30_erp_systems.sql` registers itself in `app.master_data_entities`). |
| Seeds / reset | `seed.sql`, `seed_master_data.sql`, `seed_source_emails.sql` (demo data, demo passwords), `reset_schema.sql` (drops all schemas). |
| Tests | `postgres/tests/test_*.sql` - ASSERT blocks inside a rolled-back transaction. |
| Docker | `database/docker-init.sh` (runs `deploy_schema.sql` + `seed.sql` in the postgres image init hook); `backend/docker-compose.yml` mounts `../database/postgres`. No database tooling image. |
| CI/CD | **None.** No `.vela.yml`, no `.github/` workflows, no build or deployment scripts in any of the three repos. |
| Secrets | No credentials in the SQL. The backend reads DB credentials from a git-ignored `.env`. Manual deploys are run by a person with `psql` against Supabase. |

## 2. Tooling verified on this machine

| Tool | Version / licence | Notes |
|---|---|---|
| PostgreSQL | target Supabase PG 17; local test image `postgres:17.6-alpine` (PostgreSQL licence) | Clean install of the current schema succeeds. |
| pgschema | v1.14.1, Apache-2.0, no paid edition | Image `pgplex/pgschema:1.14.1` (`sha256:94732697...`), static binary `/usr/local/bin/pgschema`. **No Windows build**: runs in Docker. Supports PG 14-18. |
| SQLFluff | 4.4.0 (2026-10-02), MIT | Postgres dialect. |
| Docker | Docker Desktop 29.4.3 (Linux engine) | Used for the disposable databases and the tool image. |
| Vela | CLI not installed; docs are v0.26, server releases v0.28.x | Installed server version unknown - see section 5. |

Behaviour of pgschema confirmed by experiment (not only from the docs):

- `dump --multi-file` produces one file per object plus a `main.sql` with `\i` includes in dependency order. Names of the target schema are **unqualified**, other schemas stay qualified.
- `plan` diffs **one schema per run** and applies the desired SQL into a temporary schema of a "plan database". Cross-schema references (`app_auth.users`, `app.statuses`, `sjo.erp_systems`) must exist there, so the plan database must hold the complete desired schema.
- Dump -> plan against the same database returns "No changes detected" for all 5 schemas (the model round-trips every existing object).
- Plan JSON: `{version, pgschema_version, created_at, source_fingerprint, groups[].steps[] {sql, type, operation, path}}`. `operation` is `create | alter | drop | recreate`, so destructive steps are identifiable. There is no built-in "hazard" flag.
- `apply --plan` re-checks the target's fingerprint and refuses if the schema changed after planning; it requires the same pgschema version.
- pgschema does **not** manage `CREATE SCHEMA`, `CREATE EXTENSION`, roles, ownership, or global default privileges, and treats a column rename as drop + add.

## 3. Gaps and risks

| # | Finding | Severity | Action |
|---|---|---|---|
| R1 | No CI/CD at all; deployments are manual `psql` runs against Supabase. | High | Vela pipeline + scripted, reviewed deployments (phases 4-5). |
| R2 | `deploy_schema.sql` drops and recreates all functions, views and types (CASCADE) on every run - a short outage window and a wide blast radius on PROD. | High | Replace by pgschema diffs that only touch changed objects. Keep `deploy_schema.sql` for local bootstrap only. |
| R3 | Imperative UPGRADES sections: the CREATE blocks drift from the real shape; reviewers cannot see the final table definition. | Medium | Fold UPGRADES into the CREATE blocks (declarative), verified by a pgschema diff = 0 against the legacy build. |
| R4 | Reference data inserted from schema files. | Medium | Move into idempotent post-deployment scripts. |
| R5 | One-time `ids_to_uuid.sql` runs on every deploy. | Low | Move to `ManualMigrations/Schema/` (already applied on the existing database). |
| R6 | No destructive-change control: a removed column in a file is silently ignored (UPGRADES never drop), while an accidental `DROP ... CASCADE` would run unreviewed. | High | Plan classification + explicit approval bound to the plan digest. |
| R7 | Dependency order is hand-maintained in one long file; files missing from it are silently not deployed. | Medium | Explicit manifest + build check for unlisted / duplicate / missing files. |
| R8 | No SQL linting. | Low | SQLFluff (postgres dialect) in the build. |
| R9 | Cross-schema FK cycle `app.* -> app_auth.users` and `app_auth.user_applications -> app.applications`. Per-schema diff tools cannot create both from nothing. | Medium | Empty targets are bootstrapped from the consolidated `schema.sql`; later deploys plan per schema in a fixed order. |
| R10 | Generator needs Node; the drift check is not enforced anywhere. | Low | CI step with a Node image runs `--check`. |
| R11 | Only `main` exists; the requested `dev` / `uat` promotion branches and Vela environments do not. | Info | Pipeline supports them; branches and Vela secrets must be created by a repo admin. |
| R12 | Documentation drift (README mentions `sqlserver/`, CLAUDE.md describes UPGRADES workflow). | Low | Update docs (phase 7). |

No duplicate object definitions, no unlisted object files and no hard-coded credentials were found.

## 4. Target design (adapted to this repository)

The `database` repo is the "PostgreSQL.Database" project. Existing module folders stay the authored source;
new tooling is added beside them instead of duplicating SQL into a second tree.

```
database/
  postgres/                  authored source (unchanged module layout)
    predeploy/               schemas, extensions, default privileges (pgschema cannot manage these)
    postdeploy/              idempotent reference data
    objects.sql              ordered manifest of object files (also used by deploy_schema.sql)
    ...module folders...
  ManualMigrations/{Schema,Data}/
  Build/                     build-schema.sh, validate-schema.sh, generate-plan.sh, deploy.sh, verify.sh, common.sh, lib/
  Docker/Dockerfile          tool image: bash, psql 17, pgschema 1.14.1, SQLFluff, python
  config/                    schemas.conf, environments/{dev,uat,prod}.env (no secrets)
  tests/deploy/              scenario tests (disposable PostgreSQL)
  Artifacts/                 build outputs (git-ignored)
  .vela.yml  .sqlfluff  .gitignore
```

Build = "compile": assemble `schema.sql` from the manifest, install it on a disposable PostgreSQL 17, run the SQL tests,
then `pgschema dump` each schema into `Artifacts/model/<schema>/` - the canonical, declarative desired state
(the DACPAC equivalent). Plans diff each target schema against that model, using the disposable build database as
pgschema's plan database so cross-schema references resolve.
