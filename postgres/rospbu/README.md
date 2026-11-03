# ROSPBU Invoice Processing - database objects

Schema `rospbu` holds the ROSPBU invoices: `rospbu.rospbu_invoices` and its child tables, types, view and
functions in `invoices/` - generated from `../common/invoices/templates` (edit the templates and run
`node tools/generate-app-invoice-sql.cjs`, never the generated files). ROSPBU has no fields of its own yet:
its table has only the common core columns.

When ROSPBU gets its own fields, follow SJO:

- add the columns in `{{#rospbu}} ... {{/rospbu}}` sections of the templates (table, create batch, input type)
- `functions/ufn_invoice_rospbu_fields.sql` + `procedures/usp_invoice_rospbu_fields_save.sql` in schema `rospbu`
- add new hand-written files to `../deploy_schema.sql` in the matching section

and register the fields in the backend's `src/modules/rospbu/rospbu.extension.ts`.
