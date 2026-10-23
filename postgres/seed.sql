-- =====================================================================
-- Cargill Custom Apps - seed / demo data (mirrors the frontend mock data)
-- Expects empty tables: run after reset_schema.sql (or a fresh deploy_schema.sql).
-- Demo LOCAL users all use the password:  password
-- (bcrypt hash below; generate new ones with `npm run hash-password` in backend/)
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- ---------------- Applications & route modules ----------------
INSERT INTO app.applications (code, name, description) VALUES
    ('GP',     'GP',     'General Payments'),
    ('sjo',    'SJO',    'SJO Invoice Processing'),
    ('rospbu', 'ROSPBU', 'ROSPBU Invoice Processing');

CREATE TEMP TABLE seed_modules (slug text, app_code text, name text, prefix text, pdf_file text, pdf_title text) ON COMMIT DROP;
INSERT INTO seed_modules VALUES
    ('GP',                     'GP',     'General Payments',       'GP',                     'gp-tool-invoice.pdf',                'GP - General Payments Invoice'),
    ('gpp',                    'GP',     'GPP',                    'GPP',                    'gp-tool-invoice.pdf',                'GPP - Global Payment Processing Invoice'),
    ('gp-tool',                'GP',     'GP Tool',                'GP-TOOL',                'gp-tool-invoice.pdf',                'GP Tool Grain Pricing & Freight Invoice'),
    ('freight-processing',     'GP',     'Freight Processing',     'FREIGHT-PROCESSING',     'freight-processing-invoice.pdf',     'Freight Processing Invoice'),
    ('sjo',                    'sjo',    'SJO Invoice Processing', 'SJO',                    'sjo-invoice-processing-invoice.pdf', 'SJO Invoice Processing Document'),
    ('sjo-invoice-processing', 'sjo',    'SJO Invoice Processing', 'SJO-INVOICE-PROCESSING', 'sjo-invoice-processing-invoice.pdf', 'SJO Invoice Processing Document'),
    ('sjo-index-processing',   'sjo',    'SJO Index Processing',   'SJO-INDEX-PROCESSING',   'sjo-index-processing-invoice.pdf',   'SJO Index Processing Voucher'),
    ('rospbu',                 'rospbu', 'ROSPBU Invoice Processing', 'ROSPBU',                 'rospbu-invoice-report-invoice.pdf',  'ROSPBU Invoice Report'),
    ('rospbu-invoice-report',  'rospbu', 'ROSPBU Invoice Report',  'ROSPBU-INVOICE-REPORT',  'rospbu-invoice-report-invoice.pdf',  'ROSPBU Invoice Report');

INSERT INTO app.app_modules (application_id, slug, name, invoice_prefix)
SELECT a.id, m.slug, m.name, m.prefix
FROM seed_modules m JOIN app.applications a ON a.code = m.app_code
ORDER BY a.id, m.slug = m.app_code DESC, m.slug;

INSERT INTO app.app_settings (module_id, enable_notifications, max_invoices_limit)
SELECT id, true, 100 FROM app.app_modules;

-- ---------------- Users ----------------
INSERT INTO app.users (username, email, name, role, status, auth_provider, password_hash)
SELECT u.username, u.email, u.name, u.role, u.status, u.provider,
       CASE WHEN u.provider = 'LOCAL' THEN '$2b$12$A3yomF4wcaww9xkpI2SaAeg1/aZuIfJp1FXSrK4KINCYvOOS/GAiO' END
FROM (VALUES
    -- Demo logins shown on the Login screen
    ('admin',      'admin@cargill.com',           'System Administrator',        'Admin', 'Active',    'LOCAL'),
    ('GP',         'GP.user@cargill.com',         'Enzo Denaro (GP)',            'User',  'Active',    'LOCAL'),
    ('sjo',        'sjo.user@cargill.com',        'Leandra Vazquez (SJO)',       'User',  'Active',    'LOCAL'),
    ('rospbu',     'rospbu.user@cargill.com',     'Orlando Salazar (ROSPBU)',    'User',  'Active',    'LOCAL'),
    ('GP.sjo',     'GP.sjo.user@cargill.com',     'Giuliana Baccala (GP + SJO)', 'User',  'Active',    'LOCAL'),
    ('sjo.rospbu', 'sjo.rospbu.user@cargill.com', 'Mateo Rossi (SJO + ROSPBU)',  'User',  'Active',    'LOCAL'),
    ('user',       'user@cargill.com',            'Standard Multi-App User',     'User',  'Active',    'LOCAL'),
    -- Directory users listed on the Settings / User Access Management screen
    ('leandra_vazquez@cargill.com',  'leandra_vazquez@cargill.com',  'Leandra Vazquez',  'User', 'Active',    'AD'),
    ('enzo_denaro@cargill.com',      'enzo_denaro@cargill.com',      'Enzo Denaro',      'User', 'Active',    'AD'),
    ('orlando_salazar@cargill.com',  'orlando_salazar@cargill.com',  'Orlando Salazar',  'User', 'Active',    'AD'),
    ('david_bonifacio@cargill.com',  'david_bonifacio@cargill.com',  'David Bonifacio',  'User', 'Suspended', 'AD'),
    ('giuliana_baccala@cargill.com', 'giuliana_baccala@cargill.com', 'Giuliana Baccala', 'User', 'Active',    'AD'),
    ('pedro_beltramino@cargill.com', 'pedro_beltramino@cargill.com', 'Pedro Beltramino', 'User', 'Active',    'AD'),
    ('maira_corvalan@cargill.com',   'maira_corvalan@cargill.com',   'Maira Corvalan',   'User', 'Active',    'AD'),
    ('nerina_mejias@cargill.com',    'nerina_mejias@cargill.com',    'Nerina Mejias',    'User', 'Active',    'AD')
) AS u (username, email, name, role, status, provider);

INSERT INTO app.user_applications (user_id, application_id)
SELECT u.id, a.id
FROM (VALUES
    ('admin@cargill.com', 'GP'), ('admin@cargill.com', 'sjo'), ('admin@cargill.com', 'rospbu'),
    ('GP.user@cargill.com', 'GP'),
    ('sjo.user@cargill.com', 'sjo'),
    ('rospbu.user@cargill.com', 'rospbu'),
    ('GP.sjo.user@cargill.com', 'GP'), ('GP.sjo.user@cargill.com', 'sjo'),
    ('sjo.rospbu.user@cargill.com', 'sjo'), ('sjo.rospbu.user@cargill.com', 'rospbu'),
    ('user@cargill.com', 'GP'), ('user@cargill.com', 'sjo'), ('user@cargill.com', 'rospbu'),
    ('leandra_vazquez@cargill.com', 'sjo'),
    ('enzo_denaro@cargill.com', 'GP'),
    ('orlando_salazar@cargill.com', 'rospbu'),
    ('david_bonifacio@cargill.com', 'GP'),
    ('giuliana_baccala@cargill.com', 'GP'), ('giuliana_baccala@cargill.com', 'sjo'),
    ('pedro_beltramino@cargill.com', 'rospbu'),
    ('maira_corvalan@cargill.com', 'GP'),
    ('nerina_mejias@cargill.com', 'sjo')
) AS x (email, app_code)
JOIN app.users u        ON u.email = x.email
JOIN app.applications a ON a.code = x.app_code;

-- ---------------- Teams & per-module team members ----------------
INSERT INTO app.teams (name) VALUES ('Reception Team'), ('Support Team'), ('Finance Team'), ('Operations Team');

INSERT INTO app.app_team_members (module_id, team_id, user_id, name, email, alias)
SELECT m.id, t.id, u.id, x.name, x.email, x.alias
FROM app.app_modules m
CROSS JOIN (VALUES
    (1, 'Leandra Vazquez',  'leandra_vazquez@cargill.com',  'lvazquez',    'Reception Team'),
    (2, 'Enzo Denaro',      'enzo_denaro@cargill.com',      'edenaro',     'Support Team'),
    (3, 'Orlando Salazar',  'orlando_salazar@cargill.com',  'osalazar',    'Finance Team'),
    (4, 'David Bonifacio',  'david_bonifacio@cargill.com',  'dbonifacio',  'Operations Team'),
    (5, 'Giuliana Baccala', 'giuliana_baccala@cargill.com', 'gbaccala',    'Reception Team'),
    (6, 'Pedro Beltramino', 'pedro_beltramino@cargill.com', 'pbeltramino', 'Support Team')
) AS x (ord, name, email, alias, team)
JOIN app.teams t      ON t.name = x.team
LEFT JOIN app.users u ON u.email = x.email
ORDER BY m.id, x.ord;

-- ---------------- Vendors & stations ----------------
INSERT INTO app.vendors (legal_name, cuit) VALUES
    ('Molinos Agro S.A.',        '30-50001234-9'),
    ('Vicentin S.A.I.C.',        '30-61234567-2'),
    ('Terminal Quequén S.A.',    '30-71122334-5'),
    ('Cargill Logistics S.R.L.', '30-50009876-1'),
    ('Aceitera General Deheza',  '30-50003456-8');

INSERT INTO app.country_stations (country_code, station_name) VALUES
    ('ARG', 'Rosario Port'), ('ARG', 'Bahía Blanca'), ('BRA', 'Santos Terminal'),
    ('URU', 'Nueva Palmira'), ('PAR', 'Villeta Dock');

-- ---------------- Invoices: 18 per module (same pattern as the UI mock) ----------------
WITH n AS (SELECT generate_series(0, 17) AS i),
v AS (SELECT id, (row_number() OVER (ORDER BY id) - 1)::int AS idx FROM app.vendors),
s AS (SELECT id, (row_number() OVER (ORDER BY id) - 1)::int AS idx FROM app.country_stations),
st AS (SELECT * FROM (VALUES (0, 'Processed'), (1, 'Pending'), (2, 'Approved'), (3, 'Rejected')) AS t (idx, status))
INSERT INTO app.invoices
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
    (SELECT id FROM app.users WHERE username = 'admin')
FROM app.app_modules m
CROSS JOIN n
JOIN v  ON v.idx  = n.i % 5
JOIN s  ON s.idx  = n.i % 5
JOIN st ON st.idx = n.i % 4
ORDER BY m.id, n.i;

-- Attachments: main invoice PDF + tax certificate + transport manifest (files in backend/storage/attachments)
INSERT INTO app.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, sm.pdf_file, sm.pdf_title, 'Invoice Document', 'application/pdf', 250880, sm.pdf_file, true
FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id JOIN seed_modules sm ON sm.slug = m.slug
ORDER BY i.id;

INSERT INTO app.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, 'AFIP_CUIT_Voucher_' || upper(m.slug) || '.pdf', 'Tax & CUIT Registration Certificate',
       'Tax Document', 'application/pdf', 131072, 'sjo-index-processing-invoice.pdf', false
FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id
ORDER BY i.id;

INSERT INTO app.invoice_attachments (invoice_id, file_name, title, category, mime_type, size_bytes, storage_path, is_primary)
SELECT i.id, 'Receiving_Transport_Manifest_' || upper(m.slug) || '.pdf', 'Receiving & Transport Slip Manifest',
       'Manifest', 'application/pdf', 319488, 'cbs-go-invoice.pdf', false
FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id
ORDER BY i.id;

-- One freight line item per invoice, totals consistent with the invoice header
INSERT INTO app.invoice_line_items
    (invoice_id, line_no, code, description, quantity, unit_of_measure, unit_price, discount, subtotal, vat_rate, subtotal_with_vat)
SELECT i.id, 1, 'CTG ' || (10233259959 + i.id), 'Flete de Maíz ' || sm.pdf_title || ' - 390 Km',
       30.21, 'toneladas', round(i.amount / 30.21, 2), 0, i.amount, 21.00, i.invoice_subtotal_with_tax
FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id JOIN seed_modules sm ON sm.slug = m.slug;

-- CCPPs tab
INSERT INTO app.invoice_ccpps (invoice_id, product, legal_doc_issuer, status, value, km, tons, unit_rate, km_fc, tons_fc)
SELECT i.id, c.product, c.issuer, c.status, c.value, c.km, c.tons, c.rate, c.km_fc, c.tons_fc
FROM app.invoices i
CROSS JOIN (VALUES
    (1, 'MAIZ DURO',    'PTO SAN MARTIN CEREAL', 'S-Sin Factura', 36.23, 10, 36.16, 9637,  2,   36.23),
    (2, 'MAIZ DURO',    'EULA MARCOS JUAN',      'S-Sin Factura', 36.80, 0,  36.80, 0,     750, 36.80),
    (3, 'SOJA PELLETS', 'VICENTIN S.A.I.C.',     'S-Sin Factura', 42.50, 15, 42.00, 10450, 15,  42.50)
) AS c (ord, product, issuer, status, value, km, tons, rate, km_fc, tons_fc)
ORDER BY i.id, c.ord;

COMMIT;

-- Configuration master data (countries, states, cities, BUs, team codes, processes)
\ir seed_master_data.sql

SELECT 'applications' AS tbl, count(*) AS row_count FROM app.applications
UNION ALL SELECT 'app_modules', count(*) FROM app.app_modules
UNION ALL SELECT 'users', count(*) FROM app.users
UNION ALL SELECT 'invoices', count(*) FROM app.invoices
UNION ALL SELECT 'invoice_attachments', count(*) FROM app.invoice_attachments
UNION ALL SELECT 'invoice_ccpps', count(*) FROM app.invoice_ccpps
UNION ALL SELECT 'countries / states / cities', (SELECT count(*) FROM app.countries) + (SELECT count(*) FROM app.states) + (SELECT count(*) FROM app.cities)
UNION ALL SELECT 'business_units', count(*) FROM app.business_units
UNION ALL SELECT 'statuses', count(*) FROM app.statuses
UNION ALL SELECT 'processes', count(*) FROM app.processes;
