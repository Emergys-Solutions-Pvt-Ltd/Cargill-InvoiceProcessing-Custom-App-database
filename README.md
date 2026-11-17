# LATAM Invoice Workflow - PostgreSQL database project

Source-controlled PostgreSQL schema (Supabase, PostgreSQL 17) deployed the "DACPAC way": the repository holds
one file per object, a build compiles them into a desired-state model, and every deployment is a reviewed,
generated diff between that model and the target - never a hand-written migration of the schema.
All tooling is open source: PostgreSQL, pgschema (Apache-2.0), SQLFluff (MIT), Bash, Python, Docker, Vela.

```
database/
  postgres/                 the database project (authored SQL)
    objects.sql             ordered manifest of the object files (the "project file")
    predeploy/              schemas, default privileges - things pgschema does not manage
    postdeploy/             idempotent reference data (statuses, master-data registry, ...)
    auth/ common/ gpp/ sjo/ rospbu/ tables/ types/ procedures/ functions/   one object per file, by module
    common/invoices/templates/   per-app invoice SQL templates -> generated into <app>/invoices/**
    tests/                  SQL tests (ASSERT blocks, rolled back)
    deploy_schema.sql       LOCAL / docker bootstrap only (not used for DEV / UAT / PROD)
    seed*.sql               demo data (local / tests only)
  Build/                    build-schema, validate-schema, generate-plan, deploy, verify, common, lib/dbproject.py
  ManualMigrations/         one-time schema / data changes the diff cannot express (renames, backfills)
  Docker/Dockerfile         tool image: bash, psql 17, pgschema 1.14.1, SQLFluff 4.4.0
  config/                   project.conf (schemas, versions) + environments/{dev,uat,prod,local}.env (policy, no secrets)
  tests/deploy/             deployment scenario tests (disposable PostgreSQL)
  docs/                     ASSESSMENT.md (phase-1 report), DEPLOYMENT.md (runbook)
  .vela.yml  .sqlfluff  .gitattributes  .gitignore
  Artifacts/                build / plan / deployment outputs (git-ignored, published by the pipeline)
```

## How it works

| Step | Script | Output |
|---|---|---|
| Build | `Build/build-schema.sh` | `schema.sql` (complete desired state), `predeploy.sql`, `postdeploy.sql`, `object-manifest.json`, `build-report.json` |
| Validate | `Build/validate-schema.sh` | SQLFluff, clean install on a disposable PostgreSQL, SQL tests, catalog checks, **model** (`model/<schema>/`, from `pgschema dump`), round-trip check, `validation-report.json` |
| Plan | `Build/generate-plan.sh` (`deploy.sh plan`) | per schema `plans/<schema>.{json,sql,txt}`; `deployment-plan.json` (bundle + digest), `deployment.sql` (preview), `deployment-summary.json`, `destructive-changes.json` |
| Validate plan | `Build/deploy.sh validate` | plan files intact, made for this environment and pgschema version, approval policy met |
| Apply | `Build/deploy.sh apply` | pre-deployment -> `pgschema apply --plan` per schema (or `schema.sql` on an empty database) -> post-deployment -> verify |
| Verify | `Build/verify.sh` (`deploy.sh verify`) | objects present, indexes valid, triggers enabled, routines readable, reference data, **no drift**; `verify-report.json` |
| Report | (every `deploy.sh` run) | `deployment-report.json`, `deployment-report.md` |

Why a compiled model: pgschema compares **one schema per run** and applies the desired SQL into a temporary
schema of a "plan database". Objects here reference other schemas (`app_auth.users`, `app.statuses`,
`sjo.erp_systems`), so the build installs the whole project on a disposable database first; that database is
pgschema's plan database and its per-schema dump is the canonical desired state. `validate-schema.sh` proves
the model round-trips (plan of the model against its own database = no changes) before any target is touched.

**The plan you review is the plan that runs.** `deployment-plan.json` carries a SHA-256 digest of every SQL
step, every target fingerprint and the build artifacts (no timestamps, so planning an unchanged source
against an unchanged target always gives the same digest). UAT and PROD apply only when the reviewed digest is
passed in (`APPROVED_PLAN_DIGEST`); `pgschema apply` additionally refuses a plan whose target changed
after planning (fingerprint).

## Developer workflow

1. Edit or add the object file (table, view, type, function, procedure, trigger) - **declaratively**:
   change the `CREATE TABLE` itself, never append `ALTER TABLE`. New file -> add an `\ir` line to
   `postgres/objects.sql` after everything it references. Per-app invoice objects: edit
   `postgres/common/invoices/templates/*.sql.tpl`, run `node postgres/tools/generate-app-invoice-sql.cjs`.
2. Reference data -> `postgres/postdeploy/` (idempotent `INSERT ... ON CONFLICT`). One-time data or
   rename work -> `ManualMigrations/` (see its README).
3. Check locally (Docker):

   ```bash
   docker build -f Docker/Dockerfile -t latam-invoice-db-tools:dev .
   ```

   ```bash
   bash tests/deploy/run-local.sh 01 15
   ```

   or build + validate only, against any disposable PostgreSQL (`BUILD_DB_*`):

   ```bash
   docker run --rm --network <net> -v "$PWD:/workspace" -e BUILD_DB_HOST=<pg> -e BUILD_DB_USER=postgres latam-invoice-db-tools:dev bash Build/validate-schema.sh
   ```
4. Open a pull request (`feature/*` -> `dev`): the pipeline builds and validates. Merge -> DEV deploys.

## Environments and promotion

| Branch | Environment | What happens |
|---|---|---|
| any PR | - | build + validate (no credentials) |
| `dev` | DEV | push: plan + apply automatically (drops still need `allow_destructive=true`) |
| `uat` | UAT | push: plan only (digest in the log / artifacts). Deployment `target=uat` with `approved_plan_digest`: plan + apply |
| `main` | PROD | push: plan only. Deployment `target=prod` with `approved_plan_digest`: plan + apply |

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for the runbook, secrets, approvals, troubleshooting and rollback.

## Change safety

| Change | Handling |
|---|---|
| Create table / view / function / procedure / trigger / type | automatic |
| Add column | automatic (`ADD COLUMN`; `NOT NULL` without default fails on populated tables -> add a default or backfill first) |
| Modify column type, `SET NOT NULL` | applied, flagged **review** in `destructive-changes.json` |
| Create / replace index | `CREATE INDEX CONCURRENTLY` outside a transaction (online), counted as non-transactional |
| Modify view | drop + recreate in one transaction (flagged review) |
| Modify function / procedure | `CREATE OR REPLACE` |
| Drop table / column / function / view / trigger / index / type | **blocked** unless `ALLOW_DESTRUCTIVE=true` |
| Rename column / table | the diff sees drop + add (blocked): do it as a manual migration (`ALTER ... RENAME`), then the plan is empty |
| Data backfill | manual migration (`ManualMigrations/Data`) |
| Breaking changes | expand -> migrate -> contract over several releases (add new column, dual-write, backfill, switch readers, drop old) |

Not supported by pgschema (handled elsewhere or manually): `CREATE SCHEMA` / `EXTENSION` (pre-deployment),
roles, ownership, global default privileges, renames. A new cross-schema reference cycle between two
*new* objects cannot be created by per-schema plans (empty databases are bootstrapped from `schema.sql`).

## Licences
pgschema Apache-2.0 · SQLFluff MIT · PostgreSQL / psql PostgreSQL Licence · Python PSF · Vela Apache-2.0. No commercial licence is needed.
