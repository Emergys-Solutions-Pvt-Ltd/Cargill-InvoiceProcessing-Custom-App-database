-- =====================================================================
-- app.udt_external_invoice_input - REQUEST type: one mapped + validated source invoice to upsert
-- Used by: usp_sync_page_apply(p_rows jsonb). Built by the backend Field Mapper (canonical invoice).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_external_invoice_input AS (
    row_no                      integer,
    external_key                text,
    external_doc                jsonb,
    invoice_code                text,
    vendor_name                 text,
    cuit                        text,
    invoice_1a                  text,
    invoice_2a                  text,
    first_invoice_number        text,
    second_invoice_number       text,
    invoice_date                date,
    reception_date              date,
    currency_code               text,
    amount                      numeric(18,2),
    invoice_subtotal            numeric(18,2),
    invoice_subtotal_with_tax   numeric(18,2),
    credit_note                 boolean,
    source_changed_at           timestamptz,
    payload_hash                text,
    cancelled                   boolean
);
