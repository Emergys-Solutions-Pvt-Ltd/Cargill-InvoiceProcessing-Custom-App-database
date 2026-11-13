-- =====================================================================
-- {{S}}.invoice_line_items - {{APP}} Invoice Overview line items (Código, Descripción, Cantidad, ...)
-- Depends on: {{S}}.{{T}}
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS {{S}}.invoice_line_items (
    id                  uuid DEFAULT gen_random_uuid() CONSTRAINT pk_{{S}}_line_items PRIMARY KEY,
    invoice_id          uuid         NOT NULL CONSTRAINT fk_{{S}}_line_items_invoice REFERENCES {{S}}.{{T}} (id) ON DELETE CASCADE,
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
    CONSTRAINT uq_{{S}}_line_items UNIQUE (invoice_id, line_no)
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
