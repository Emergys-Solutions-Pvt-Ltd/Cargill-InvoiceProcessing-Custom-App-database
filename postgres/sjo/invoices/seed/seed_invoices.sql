-- GENERATED from common/invoices/templates/seed/seed_invoices.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- Demo SJO invoices: 18 per SJO module (same pattern as the UI mock), with 3 attachments,
-- one line item each. Included by seed.sql inside its transaction
-- (uses its temp table seed_modules; expects the vendors / stations / users seeded before).
-- =====================================================================
WITH n AS (SELECT generate_series(0, 17) AS i),
v AS (SELECT id, (row_number() OVER (ORDER BY id) - 1)::int AS idx FROM app.vendors),
s AS (SELECT id, (row_number() OVER (ORDER BY id) - 1)::int AS idx FROM app.country_stations),
st AS (SELECT * FROM (VALUES (0, 'Processed'), (1, 'Pending'), (2, 'Approved'), (3, 'Rejected')) AS t (idx, status))
INSERT INTO sjo.sjo_invoices
    (invoice_code, module_id, vendor_id, station_id, invoice_1a, invoice_2a,
     first_invoice_number, second_invoice_number, invoice_date, expiry_days, invoice_expiry_date,
     support_team, pre_settlement_number, credit_note,
     amount, invoice_subtotal, invoice_subtotal_with_tax, status, reception_date, email_reception_date, created_by)
SELECT
    'INV-' || m.invoice_prefix || '-' || (1000 + (n.i + 1) * 15),
    m.id, v.id, s.id,
    '0001-00045' || (1000 + (n.i + 1) * 15),
    '0001-00045' || (1000 + (n.i + 1) * 15 + 1),
    '1', (31 + n.i)::text,
    DATE '2026-07-02', 15, TIMESTAMPTZ '2026-07-17 18:07:00+00',
    false, to_char(4131981 + n.i, 'FM9,999,999'), (n.i % 7 = 6),
    4500 + n.i * 1250, 4500 + n.i * 1250, round((4500 + n.i * 1250) * 1.21, 2),
    st.status,
    make_date(2026, 7, 10 + n.i % 20),
    make_timestamptz(2026, 7, 9 + n.i % 20, 9, 30, 0, 'UTC'),
    (SELECT id FROM app_auth.users WHERE username = 'admin')
FROM app.app_modules m
JOIN app.applications a ON a.id = m.application_id AND a.db_schema = 'sjo'
CROSS JOIN n
JOIN v  ON v.idx  = n.i % 5
JOIN s  ON s.idx  = n.i % 5
JOIN st ON st.idx = n.i % 4
ORDER BY m.id, n.i;

-- Attachments: main invoice PDF + tax certificate + transport manifest (files in backend/storage/attachments)
INSERT INTO sjo.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, sm.pdf_file, sm.pdf_title, 'Invoice Document', 'application/pdf', 250880, sm.pdf_file, true
FROM sjo.sjo_invoices i JOIN app.app_modules m ON m.id = i.module_id JOIN seed_modules sm ON sm.slug = m.slug
ORDER BY i.id;

INSERT INTO sjo.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, 'AFIP_CUIT_Voucher_' || upper(m.slug) || '.pdf', 'Tax & CUIT Registration Certificate',
       'Tax Document', 'application/pdf', 131072, 'sjo-index-processing-invoice.pdf', false
FROM sjo.sjo_invoices i JOIN app.app_modules m ON m.id = i.module_id
ORDER BY i.id;

INSERT INTO sjo.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, 'Receiving_Transport_Manifest_' || upper(m.slug) || '.pdf', 'Receiving & Transport Slip Manifest',
       'Manifest', 'application/pdf', 319488, 'cbs-go-invoice.pdf', false
FROM sjo.sjo_invoices i JOIN app.app_modules m ON m.id = i.module_id
ORDER BY i.id;

-- One freight line item per invoice, totals consistent with the invoice header
INSERT INTO sjo.invoice_line_items
    (invoice_id, line_no, code, description, quantity, unit_of_measure, unit_price, discount, subtotal, vat_rate, subtotal_with_vat)
SELECT i.id, 1, 'CTG ' || (10233259959 + i.id), 'Flete de Maíz ' || sm.pdf_title || ' - 390 Km',
       30.21, 'toneladas', round(i.amount / 30.21, 2), 0, i.amount, 21.00, i.invoice_subtotal_with_tax
FROM sjo.sjo_invoices i JOIN app.app_modules m ON m.id = i.module_id JOIN seed_modules sm ON sm.slug = m.slug;

