# Decisions — Cargill-InvoiceProcessing-Custom-App-database

Decisions that affect only this repo. Cross-repo decisions: `../DECISIONS.md`.
Newest on top. Never delete; mark replaced ones `Superseded by D-DB-xxx`.

## Template
```markdown
### D-DB-000 — YYYY-MM-DD — Short title
- Decided by: user | inferred from code (confirm)
- Decision:
- Why:
- Rejected alternatives:
```

---

### D-DB-003 — existing — Per-app invoice SQL is generated
- Decided by: inferred from code (confirm)
- Decision: `<app>/invoices/**` is generated from `common/invoices/templates/*.sql.tpl`; never edited by hand.

### D-DB-004 — 2026-11-16 — Declarative database project deployed with pgschema plans
- Decided by: user (request: DACPAC-style PostgreSQL project with pgschema, SQLFluff, Vela, DEV/UAT/PROD)
- Decision: object files describe the final state; `postgres/objects.sql` is the ordered manifest; the build
  compiles a pgschema model on a disposable PostgreSQL and every environment is deployed from a per-schema
  pgschema plan whose digest must be approved for UAT / PROD; drops need `allow_destructive`.
  Reference data lives in `postgres/postdeploy/`, renames / backfills in `ManualMigrations/`.
- Why: reviewed, minimal, reproducible changes instead of dropping and recreating every function on each run.
- Rejected alternatives: Atlas / Liquibase / Flyway (versioned migrations or commercial features for diffs);
  keeping UPGRADES sections (imperative, CREATE blocks drift from reality).

### D-DB-002 — existing — Table changes only through UPGRADES sections (Superseded by D-DB-004)
- Decided by: inferred from README (confirm)
- Decision: no migration tool; table changes are guarded, idempotent statements appended to `-- ---- UPGRADES ----`.
  `deploy_schema.sql` must run twice cleanly.

### D-DB-001 — existing — Schema `app_auth`, never `auth`
- Decided by: inferred from README (confirm)
- Why: Supabase reserves `auth`.
