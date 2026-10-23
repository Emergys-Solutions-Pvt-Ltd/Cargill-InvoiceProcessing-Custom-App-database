-- =====================================================================
-- Cargill Custom Apps - demo master data for Settings > Configuration
-- (countries, states, cities, business units, team codes, processes).
-- Re-runnable: rows that already exist (same code / name) are left alone, so it can be
-- applied to an existing database. Included by seed.sql; can also be run on its own:
--   psql "<connection>" -f database/postgres/seed_master_data.sql
-- The core statuses are system data created by tables/18_statuses.sql.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

INSERT INTO app.countries (code, name, sort_order)
SELECT v.code, v.name, v.ord
FROM (VALUES
    ('ARG', 'Argentina', 10), ('BRA', 'Brazil', 20), ('URU', 'Uruguay', 30),
    ('PAR', 'Paraguay', 40), ('CHL', 'Chile', 50), ('USA', 'United States', 60)
) AS v (code, name, ord)
WHERE NOT EXISTS (SELECT 1 FROM app.countries c WHERE lower(c.code) = lower(v.code) OR lower(c.name) = lower(v.name));

INSERT INTO app.states (country_id, code, name, sort_order)
SELECT c.id, v.code, v.name, v.ord
FROM (VALUES
    ('ARG', 'SF',  'Santa Fe',            10),
    ('ARG', 'BA',  'Buenos Aires',        20),
    ('ARG', 'CB',  'Córdoba',             30),
    ('BRA', 'SP',  'São Paulo',           10),
    ('BRA', 'PR',  'Paraná',              20),
    ('URU', 'CO',  'Colonia',             10),
    ('PAR', 'CE',  'Central',             10),
    ('CHL', 'VS',  'Valparaíso',          10),
    ('USA', 'MN',  'Minnesota',           10)
) AS v (country, code, name, ord)
JOIN app.countries c ON c.code = v.country
WHERE NOT EXISTS (SELECT 1 FROM app.states s WHERE s.country_id = c.id AND lower(s.name) = lower(v.name));

INSERT INTO app.cities (state_id, name, sort_order)
SELECT s.id, v.name, v.ord
FROM (VALUES
    ('ARG', 'Santa Fe',     'Rosario',            10),
    ('ARG', 'Santa Fe',     'San Lorenzo',        20),
    ('ARG', 'Santa Fe',     'Puerto General San Martín', 30),
    ('ARG', 'Buenos Aires', 'Bahía Blanca',       10),
    ('ARG', 'Buenos Aires', 'Necochea',           20),
    ('ARG', 'Córdoba',      'Córdoba',            10),
    ('BRA', 'São Paulo',    'Santos',             10),
    ('BRA', 'Paraná',       'Paranaguá',          10),
    ('URU', 'Colonia',      'Nueva Palmira',      10),
    ('PAR', 'Central',      'Villeta',            10),
    ('CHL', 'Valparaíso',   'Valparaíso',         10),
    ('USA', 'Minnesota',    'Minneapolis',        10)
) AS v (country, state, name, ord)
JOIN app.countries c ON c.code = v.country
JOIN app.states s    ON s.country_id = c.id AND s.name = v.state
WHERE NOT EXISTS (SELECT 1 FROM app.cities x WHERE x.state_id = s.id AND lower(x.name) = lower(v.name));

INSERT INTO app.business_units (code, name, description, sort_order)
SELECT v.code, v.name, v.description, v.ord
FROM (VALUES
    ('GP',     'General Payments',             'Global payment processing operations',      10),
    ('SJO',    'San José Operations',          'SJO invoice and index processing',          20),
    ('ROSPBU', 'Rosario Port Business Unit',   'Rosario port freight and invoice reporting', 30),
    ('GOSC',   'Grain & Oilseeds Supply Chain','Origination, freight and storage',          40)
) AS v (code, name, description, ord)
WHERE NOT EXISTS (SELECT 1 FROM app.business_units b WHERE lower(b.code) = lower(v.code) OR lower(b.name) = lower(v.name));

-- Teams (queues) already exist from seed.sql / earlier data: give them codes and descriptions
UPDATE app.teams t
SET code = v.code, description = v.description, sort_order = v.ord, updated_at = now()
FROM (VALUES
    ('Reception Team',  'RCPT', 'Receives and registers incoming invoices', 10),
    ('Support Team',    'SUPP', 'Resolves invoice exceptions and vendor queries', 20),
    ('Finance Team',    'FIN',  'Approves invoices and releases payments', 30),
    ('Operations Team', 'OPS',  'Validates freight and operational data', 40)
) AS v (name, code, description, ord)
WHERE t.name = v.name AND t.code IS NULL;

INSERT INTO app.teams (code, name, description, sort_order)
SELECT v.code, v.name, v.description, v.ord
FROM (VALUES
    ('RCPT', 'Reception Team',  'Receives and registers incoming invoices',        10),
    ('SUPP', 'Support Team',    'Resolves invoice exceptions and vendor queries',  20),
    ('FIN',  'Finance Team',    'Approves invoices and releases payments',         30),
    ('OPS',  'Operations Team', 'Validates freight and operational data',          40)
) AS v (code, name, description, ord)
WHERE NOT EXISTS (SELECT 1 FROM app.teams t WHERE lower(t.name) = lower(v.name));

INSERT INTO app.processes (code, name, description, sort_order)
SELECT v.code, v.name, v.description, v.ord
FROM (VALUES
    ('FREIGHT-INV', 'Freight Invoice Processing', 'Freight invoices from carriers (CTG / CCPP)', 10),
    ('INDEX-PROC',  'Index Processing',           'Index and catalog validation for SJO',        20),
    ('INV-REPORT',  'Invoice Reporting',          'ROSPBU invoice reports',                      30),
    ('PAYMENT',     'Payment Processing',         'Payment release and settlement',              40)
) AS v (code, name, description, ord)
WHERE NOT EXISTS (SELECT 1 FROM app.processes p WHERE lower(p.code) = lower(v.code) OR lower(p.name) = lower(v.name));

-- First queue in the workflow (invoices arrive here from the scanning robot)
INSERT INTO app.teams (code, name, description, sort_order)
SELECT 'BOT', 'BOT Scanning', 'Invoices captured by the scanning robot, waiting for reception', 5
WHERE NOT EXISTS (SELECT 1 FROM app.teams WHERE lower(name) = 'bot scanning');

INSERT INTO app.processes (code, name, description, sort_order)
SELECT 'JDE', 'JDE Process', 'Invoice posted through JD Edwards', 5
WHERE NOT EXISTS (SELECT 1 FROM app.processes WHERE lower(code) = 'jde' OR lower(name) = 'jde process');

-- Workflow fields for demo invoices that do not have them yet (Invoice Details page)
WITH queues AS (
    SELECT id, (row_number() OVER (ORDER BY sort_order, id) - 1)::int AS idx, count(*) OVER ()::int AS n
    FROM app.teams WHERE is_active
),
places AS (
    SELECT id, (row_number() OVER (ORDER BY id) - 1)::int AS idx, count(*) OVER ()::int AS n FROM app.cities
),
targets AS (
    SELECT i.id, (row_number() OVER (PARTITION BY i.module_id ORDER BY i.id) - 1)::int AS k, m.slug
    FROM app.invoices i JOIN app.app_modules m ON m.id = i.module_id
    WHERE i.team_id IS NULL
)
UPDATE app.invoices i
SET team_id             = q.id,
    process_id          = (SELECT p.id FROM app.processes p WHERE p.code = CASE
                               WHEN t.slug IN ('GP', 'gpp', 'gp-tool') THEN 'JDE'
                               WHEN t.slug = 'freight-processing' THEN 'FREIGHT-INV'
                               WHEN t.slug LIKE 'sjo-index%' THEN 'INDEX-PROC'
                               WHEN t.slug LIKE 'sjo%' THEN 'PAYMENT'
                               ELSE 'INV-REPORT' END),
    origin_city_id      = (SELECT c.id FROM places c WHERE c.idx = t.k % c.n),
    destination_city_id = (SELECT c.id FROM places c WHERE c.idx = (t.k + 3) % c.n),
    filenet_id          = coalesce(i.filenet_id, '{' || upper(substr(md5(i.invoice_code), 1, 8)) || '-' || upper(substr(md5(i.invoice_code), 9, 4)) || '}')
FROM targets t
JOIN queues q ON q.idx = t.k % q.n
WHERE i.id = t.id;

COMMIT;
