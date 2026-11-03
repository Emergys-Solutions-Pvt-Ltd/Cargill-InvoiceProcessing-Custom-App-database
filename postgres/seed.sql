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
INSERT INTO app.applications (code, name, description, db_schema) VALUES
    ('GP',     'GP',     'General Payments',          'gpp'),
    ('sjo',    'SJO',    'SJO Invoice Processing',    'sjo'),
    ('rospbu', 'ROSPBU', 'ROSPBU Invoice Processing', 'rospbu');

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
INSERT INTO app_auth.users (username, email, name, role, status, auth_provider, password_hash)
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

INSERT INTO app_auth.user_applications (user_id, application_id)
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
JOIN app_auth.users u        ON u.email = x.email
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
LEFT JOIN app_auth.users u ON u.email = x.email
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

-- ---------------- Invoices: one table set per app (generated from common/invoices/templates) ----------------
\ir gpp/invoices/seed/seed_invoices.sql
\ir sjo/invoices/seed/seed_invoices.sql
\ir rospbu/invoices/seed/seed_invoices.sql

COMMIT;

-- Configuration master data (countries, states, cities, BUs, team codes, processes)
\ir seed_master_data.sql

-- Emails the invoice PDFs were received through (Invoice Details > PDF preview > Email)
\ir seed_source_emails.sql

SELECT 'applications' AS tbl, count(*) AS row_count FROM app.applications
UNION ALL SELECT 'app_modules', count(*) FROM app.app_modules
UNION ALL SELECT 'users', count(*) FROM app_auth.users
UNION ALL SELECT 'gpp_invoices', count(*) FROM gpp.gpp_invoices
UNION ALL SELECT 'sjo_invoices', count(*) FROM sjo.sjo_invoices
UNION ALL SELECT 'rospbu_invoices', count(*) FROM rospbu.rospbu_invoices
UNION ALL SELECT 'invoice_attachments (all apps)', (SELECT count(*) FROM gpp.invoice_attachments) + (SELECT count(*) FROM sjo.invoice_attachments) + (SELECT count(*) FROM rospbu.invoice_attachments)
UNION ALL SELECT 'invoice_ccpps (gpp)', count(*) FROM gpp.invoice_ccpps
UNION ALL SELECT 'invoice_source_emails (all apps)', (SELECT count(*) FROM gpp.invoice_source_emails) + (SELECT count(*) FROM sjo.invoice_source_emails) + (SELECT count(*) FROM rospbu.invoice_source_emails)
UNION ALL SELECT 'countries / states / cities', (SELECT count(*) FROM app.countries) + (SELECT count(*) FROM app.states) + (SELECT count(*) FROM app.cities)
UNION ALL SELECT 'business_units', count(*) FROM app.business_units
UNION ALL SELECT 'statuses', count(*) FROM app.statuses
UNION ALL SELECT 'processes', count(*) FROM app.processes;
