# Deployment runbook

## 1. One-time setup (repository admin)

| Item | Action |
|---|---|
| Branches | create `dev` and `uat` from `main`; protect `dev`, `uat`, `main` (PR + passing Vela build required) |
| Vela repo | enable events `push`, `pull_request`, `deployment`; fork PR policy "Always Require Approval" |
| Tool image | build `Docker/Dockerfile`, push to the registry Vela can pull from, replace every `TOOLS_IMAGE` in `.vela.yml` with the pushed reference (tag **and** digest) |
| Secrets | repo secrets (engine native) `dev_db_host dev_db_port dev_db_name dev_db_user dev_db_password` and the same for `uat_` and `prod_`. Allowed events: **push, deployment only** (never pull_request). Restrict to the tool image. |
| DB users | one deployment role per environment that owns the managed schemas (DDL rights on `app`, `app_auth`, `gpp`, `sjo`, `rospbu`). Not the application's runtime user. |
| Who approves | creating a Vela deployment = approving it. Limit GitHub write access on this repo to the release owners. |

```bash
vela add secret --engine native --type repo --org Emergys-Solutions-Pvt-Ltd --repo Cargill-InvoiceProcessing-Custom-App-database --name prod_db_password --value @prod_db_password.txt --event push --event deployment
```

Supabase: use the direct connection (or the session-mode pooler), port 5432, `sslmode=require`. Avoid the
transaction-mode pooler for deployments: schema changes rely on session state (search_path, lock timeouts,
multi-statement transactions). Not yet tried against Supabase from Vela - verify on DEV first.

## 2. Normal release

1. **PR to `dev`** - Vela builds and validates. Reviewers read the diff of the SQL files.
2. **Merge to `dev`** - Vela plans and applies DEV automatically. If the plan contains drops the apply step stops
   (exit 3); review `destructive-changes.json` and re-run as a deployment:
   ```bash
   vela add deployment --org Emergys-Solutions-Pvt-Ltd --repo Cargill-InvoiceProcessing-Custom-App-database --target dev --ref dev --parameter allow_destructive=true
   ```
3. **PR `dev` -> `uat`, merge** - the `uat-plan` step prints `plan digest : <sha256>` and publishes
   `deployment.sql`, `deployment-summary.json`, `destructive-changes.json`. Review them.
4. **Approve UAT** by creating the deployment with that digest:
   ```bash
   vela add deployment --org Emergys-Solutions-Pvt-Ltd --repo Cargill-InvoiceProcessing-Custom-App-database --target uat --ref uat --parameter approved_plan_digest=<sha256>
   ```
   The deployment build plans again; if anything changed (new commit, target drift) the digest differs and
   nothing is applied (exit 3) - review the new plan. Otherwise it applies exactly the reviewed steps.
5. **PR `uat` -> `main`, merge, review the PROD plan, create the `prod` deployment** the same way (`--ref main`).

Every build artifact and report carries repository, branch, commit SHA, environment and plan digest.

## 3. Running by hand (break-glass / local)

All scripts run in the tool image. Credentials come from the environment, never from arguments.

```bash
docker run --rm -it -v "$PWD:/workspace" --env-file /secure/prod.env -e BUILD_DB_HOST=<disposable-pg> -e BUILD_DB_USER=postgres latam-invoice-db-tools:1.0.0 bash -c "Build/validate-schema.sh && Build/deploy.sh plan prod"
```

`/secure/prod.env` holds `DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD` and is never committed.
Then `Build/deploy.sh apply prod` with `APPROVED_PLAN_DIGEST=<digest>` (and `ALLOW_DESTRUCTIVE=true` if reviewed).

## 4. Exit codes

| Code | Meaning | Typical fix |
|---|---|---|
| 0 | success | - |
| 1 | error (pgschema / psql failure, apply failed) | read `Artifacts/logs/apply.log`; failed transactional groups are rolled back |
| 2 | usage / configuration (missing variable, unknown environment) | set the variable |
| 3 | approval required / plan rejected (no or wrong digest, destructive steps) | review, pass `approved_plan_digest` / `allow_destructive` |
| 4 | cannot connect to the target | network, credentials, sslmode |
| 5 | validation failed (build, lint, clean install, verification, drift) | see the named report |

## 5. Troubleshooting

| Symptom | Cause / action |
|---|---|
| `... is not listed in postgres/objects.sql` | add the `\ir` line |
| `references X defined later in objects.sql` | move the line after its dependency |
| `does not round-trip through pgschema` | an object kind pgschema cannot reproduce; see `Artifacts/logs/validate-schema.log` |
| `schema fingerprint mismatch` on apply | the target changed after planning: plan again, review again |
| `schema(s) X do not exist on the target` | new schema: add it to `predeploy/00_schemas.sql`, run `Build/deploy.sh predeploy <env>`, plan again |
| verify reports drift | someone changed the target by hand; the next plan shows how to bring it back (drops need approval) |
| `CREATE INDEX CONCURRENTLY` interrupted | an invalid index remains; re-run the deployment: pgschema adopts or rebuilds it |

## 6. Rollback

Schema deployments are not automatically reversible and no "down" script is generated.

- **Failed apply**: each transactional group is rolled back; earlier schemas (in `MANAGED_SCHEMAS` order) and
  non-transactional steps (concurrent indexes) stay applied. Fix forward, or revert the commit and redeploy.
- **Bad but successful release**: revert the commit in Git and deploy again - the diff brings the schema
  back for code objects (functions, views, types, indexes). Dropped columns / tables are **not** restored by a
  revert: restore data from the Supabase backup / PITR.
- **Before PROD releases with destructive steps**: take a backup (`pg_dump`, Supabase PITR checkpoint), and
  prefer expand-and-contract so every single release is backward compatible with the previous application version.
