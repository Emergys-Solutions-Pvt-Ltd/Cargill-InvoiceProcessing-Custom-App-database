-- =====================================================================
-- Post-deployment: the core invoice workflow statuses (system data, required by existing invoices).
-- Idempotent: inserts missing rows only; names / colours edited in Settings > Configuration are kept.
-- =====================================================================
INSERT INTO app.statuses (code, name, description, color, sort_order) VALUES
    ('Pending',   'Pending',   'Received, waiting for review',  'warning', 10),
    ('Approved',  'Approved',  'Reviewed and approved',         'success', 20),
    ('Processed', 'Processed', 'Posted for payment',            'info',    30),
    ('Rejected',  'Rejected',  'Rejected during review',        'danger',  40)
ON CONFLICT (code) DO NOTHING;
