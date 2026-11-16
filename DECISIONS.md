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

### D-DB-002 — existing — Table changes only through UPGRADES sections
- Decided by: inferred from README (confirm)
- Decision: no migration tool; table changes are guarded, idempotent statements appended to `-- ---- UPGRADES ----`.
  `deploy_schema.sql` must run twice cleanly.

### D-DB-001 — existing — Schema `app_auth`, never `auth`
- Decided by: inferred from README (confirm)
- Why: Supabase reserves `auth`.
