-- GENERATED from common/invoices/templates/tables/41_invoice_line_items.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- sjo.invoice_line_items - SJO Invoice Overview line items (Código, Descripción, Cantidad, ...)
-- Depends on: sjo.sjo_invoices
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS sjo.invoice_line_items (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_sjo_line_items PRIMARY KEY,
    invoice_id          uuid         NOT NULL CONSTRAINT fk_sjo_line_items_invoice REFERENCES sjo.sjo_invoices (id) ON DELETE CASCADE,
    line_no             integer         NOT NULL,
    code                varchar(50)     NULL,               -- codigo
    description         varchar(500)    NULL,               -- descripcion
    quantity            numeric(18,3)   NOT NULL,           -- cantidad
    unit_of_measure     varchar(30)     NULL,               -- uMedida
    unit_price          numeric(18,2)   NOT NULL,           -- precioUnit
    discount            numeric(18,2)   NOT NULL DEFAULT 0, -- bonif
    subtotal            numeric(18,2)   NOT NULL,
    vat_rate            numeric(5,2)    NOT NULL DEFAULT 21.00,  -- alicuotaIVA (%)
    subtotal_with_vat   numeric(18,2)   NOT NULL,
    CONSTRAINT uq_sjo_line_items UNIQUE (invoice_id, line_no)
);
