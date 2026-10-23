# Database – Cargill Custom Apps

| Folder | Status | Used by |
|---|---|---|
| [`postgres/`](postgres/README.md) | **Active**: PostgreSQL / Supabase (schema `app`) | `backend/` |
| [`sqlserver/`](sqlserver/README.md) | Reference only: the original SQL Server version | nothing (kept for SQL Server deployments) |

Both versions use the same design: one script per table, request/response types, shared views,
stored procedures (PostgreSQL: functions named `usp_*`), seed data, and an idempotent deploy script.
