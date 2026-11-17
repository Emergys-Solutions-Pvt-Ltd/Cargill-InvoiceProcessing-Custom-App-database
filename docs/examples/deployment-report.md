# Database deployment report

| Item | Value |
|---|---|
| Status | **failed** |
| Mode | apply |
| Environment | dev |
| Repository | Emergys-Solutions-Pvt-Ltd/Cargill-InvoiceProcessing-Custom-App-database |
| Branch | dev |
| Commit | 0000000000000000000000000000000000000000 |
| PostgreSQL | 17.6 |
| Timestamp | 2026-11-16T18:44:47Z |
| Plan digest | `e6c777fc4bccc29dad9195495e193980b3921cf75dd54c48957773b97cae7383` |
| Plan mode | incremental |
| Tools | pgschema 1.14.1, psql 17.12, python 3.12.13, sqlfluff 4.4.0 |

## Created (2)

- `app.statuses.ix_statuses_sort`
- `sjo.erp_systems.region`

## Modified (1)

- `app.usp_application_list`

## Deleted (1)

- `app.usp_mailbox_list_for_application`

## Destructive / review items (1)

- **breaking** `app.usp_mailbox_list_for_application` drop - drops function: callers relying on it break (approval required)

## Verification

Not run.

## Errors

- plan rejected by the deployment policy (exit 3)
- the plan contains destructive steps (see destructive-changes.json); re-run with ALLOW_DESTRUCTIVE=true after review
