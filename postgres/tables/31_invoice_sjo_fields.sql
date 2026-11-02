-- =====================================================================
-- app.invoice_sjo_fields - SJO Invoice Processing fields (Add / Create / Details page)
-- One row per SJO invoice (1:1), written on create and by Invoice Details "Save".
-- Kept out of app.invoices so the positionally coupled vw_invoice_summary /
-- udt_invoice_result stay unchanged (see postgres/README.md).
-- Invoice ID = app.invoices.invoice_code; Assign To = app.invoices.assigned_user_id.
-- Required on the SJO form: country, BU, ERP, ID Fiscal.
-- Depends on: app.invoices, app.countries, app.business_units, app.erp_systems, app.users
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.invoice_sjo_fields (
    invoice_id          integer         NOT NULL CONSTRAINT pk_invoice_sjo_fields PRIMARY KEY
                                                 CONSTRAINT fk_invoice_sjo_fields_invoice REFERENCES app.invoices (id) ON DELETE CASCADE,
    country_id          integer         NOT NULL CONSTRAINT fk_invoice_sjo_fields_country REFERENCES app.countries (id),
    business_unit_id    integer         NOT NULL CONSTRAINT fk_invoice_sjo_fields_bu      REFERENCES app.business_units (id),
    erp_system_id       integer         NOT NULL CONSTRAINT fk_invoice_sjo_fields_erp     REFERENCES app.erp_systems (id),
    id_fiscal           varchar(30)     NOT NULL,       -- vendor tax id, e.g. 135266470
    ab_number           varchar(30)     NULL,           -- JDE Address Book number, e.g. 39102783
    ab_name             varchar(255)    NULL,           -- Address Book name, e.g. CITIBANK NA
    flow_turn_down      boolean         NOT NULL DEFAULT false,
    critical_vendor     boolean         NOT NULL DEFAULT false,
    urgent_invoice      boolean         NOT NULL DEFAULT false,
    updated_by          integer         NULL     CONSTRAINT fk_invoice_sjo_fields_updated_by REFERENCES app.users (id),
    created_at          timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at          timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_invoice_sjo_fields_id_fiscal CHECK (btrim(id_fiscal) <> '')
);

CREATE INDEX IF NOT EXISTS ix_invoice_sjo_fields_id_fiscal ON app.invoice_sjo_fields (id_fiscal);
CREATE INDEX IF NOT EXISTS ix_invoice_sjo_fields_country   ON app.invoice_sjo_fields (country_id);
CREATE INDEX IF NOT EXISTS ix_invoice_sjo_fields_bu        ON app.invoice_sjo_fields (business_unit_id);
CREATE INDEX IF NOT EXISTS ix_invoice_sjo_fields_erp       ON app.invoice_sjo_fields (erp_system_id);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
