# Example deployment artifacts

Produced by `Build/validate-schema.sh` + `Build/deploy.sh plan dev` + `Build/deploy.sh apply dev` against a local
PostgreSQL 17 target that held the current schema, after four source changes:

| Change | Plan step | Classification |
|---|---|---|
| `sjo.erp_systems` gets column `region` | `ALTER TABLE erp_systems ADD COLUMN region` | safe |
| index `app.ix_statuses_sort` added to `18_statuses.sql` | `CREATE INDEX CONCURRENTLY` + `-- pgschema:wait` | safe, non-transactional |
| body of `app.usp_application_list` changed | `CREATE OR REPLACE FUNCTION` | safe |
| `app.usp_mailbox_list_for_application` removed | `DROP FUNCTION` | **breaking - approval required** |

`apply` stopped with exit code 3 because the plan drops a function and `ALLOW_DESTRUCTIVE` was not set; the
report records the failure. Commit SHA and target are placeholders (local run).

| File | What it is |
|---|---|
| `deployment-plan.json` | bundle: digest, mode, target, source, per-schema plan files with sha256 / fingerprint |
| `plans/<schema>.json` | the pgschema plan applied as-is by `pgschema apply --plan` |
| `plans/<schema>.sql`, `.txt` | the same comparison as SQL and as a human summary |
| `deployment.sql` | full preview: pre-deployment, every schema's steps, post-deployment |
| `deployment-summary.json`, `destructive-changes.json` | counts / classification used by the approval policy |
| `deployment-report.{json,md}` | the run's report |
| `build-report.json`, `validation-report.json`, `tool-versions.json` | build and validation results |
