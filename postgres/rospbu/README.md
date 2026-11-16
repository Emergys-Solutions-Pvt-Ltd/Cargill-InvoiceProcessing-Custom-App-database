# ROSPBU Invoice Processing - database objects

Schema `rospbu` holds the ROSPBU invoices: `rospbu.rospbu_invoices` and its child tables, types, view and
functions in `invoices/` - generated from `../common/invoices/templates` (edit the templates and run
`node tools/generate-app-invoice-sql.cjs`, never the generated files).

## ROSPBU fields ("ROSPBU Invoice Edit" / Create Invoice page)

`rospbu_invoices` has the common core columns plus the ROSPBU fields, in `{{#rospbu}} ... {{/rospbu}}`
sections of the templates (table + UPGRADES, `udt_invoice_input`, `usp_invoice_create_batch`,
`udt_invoice_detail_result`, `usp_invoice_get_by_code`):

| Page label | Column |
|---|---|
| País / BU / ERP | `country_id` (app.countries), `business_unit_id` (app.business_units), `erp_system_id` (sjo.erp_systems) |
| Retención | `retencion` (default 'No aplica') |
| Código Imputación, Nro AR, Cantidad, Producto, NP | `codigo_imputacion`, `nro_ar`, `cantidad`, `producto`, `np` |
| Nº de remito, FILIAL, Número de Documento, General Comment | `nro_remito`, `filial`, `numero_documento`, `general_comment` |
| Centro Emisor, Fecha de Vencimiento, Nº de OC, Instrumento de Pago, Timbrado | `centro_emisor`, `due_date`, `po_number`, `instrumento_pago`, `timbrado` |
| BP Number, Número de Liquidación, Branch Plant, G_TIPO_OPER | `bp_number`, `numero_liquidacion`, `branch_plant`, `tipo_operacion` |
| Total de la FC, Fecha de Fc, Moneda de la Fc, Adicional Info | common columns `amount`, `invoice_date`, `currency_code`, `additional_info` |

All are optional. `usp_invoice_create_batch` takes País / BU / ERP as the code or name of an active
Configuration item (`rospbu_country`, `rospbu_business_unit`, `rospbu_erp`) and rejects unknown ones (CA400).
`functions/ufn_invoice_rospbu_fields.sql` returns them as the `rospbu_fields` JSON of `usp_invoice_get_by_code`.

Backend: `src/modules/rospbu` (create schema, detail fields). Frontend: `pages/app/RospbuInvoiceCreate.jsx`
(route `/app/rospbu/invoices/new`); the values are shown read-only in Invoice Details.
