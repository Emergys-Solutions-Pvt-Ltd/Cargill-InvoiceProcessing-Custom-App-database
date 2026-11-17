# Manual migrations

Changes the declarative diff cannot express safely. They are **not** run by the pipeline: a DBA (or the
release owner) runs them once per environment, in the order of the file names, before or after the
deployment as stated in the file header, and records it in the release notes.

| Folder | Use for |
|---|---|
| `Schema/` | renames (`ALTER TABLE ... RENAME COLUMN / TO`), type conversions that need data handling, one-time structural moves |
| `Data/`   | backfills and data fixes (expand-and-contract step 3), large updates done in batches |

Rules
- File name `YYYY-MM-DD_<short_description>.sql`; header states the environment(s), *before* / *after* deployment, and how to verify.
- Idempotent where possible (`IF EXISTS` guards), one transaction unless it must be batched.
- After a rename, update the object file the same way: the next plan must be empty for that object.
- Never edit a file that has been run anywhere; add a new one.

Typical rename (no data loss):
1. `ManualMigrations/Schema/2026-12-01_rename_erp_description.sql`: `ALTER TABLE sjo.erp_systems RENAME COLUMN description TO details;`
2. Change `postgres/sjo/tables/30_erp_systems.sql` and every function using the column.
3. Run the manual migration, then deploy: the plan shows only the function changes.

| File | Status |
|---|---|
| `Schema/2026-11-12_ids_to_uuid.sql` | integer keys -> uuid. Applied to the existing (Supabase DEV) database on 2026-11-12; no-op on converted or empty databases. Kept for databases restored from older backups. |
