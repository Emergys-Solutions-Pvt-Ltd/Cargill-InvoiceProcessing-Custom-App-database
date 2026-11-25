-- =====================================================================
-- Post-deployment: app.applications.db_schema - the schema of each app's own invoice tables.
-- Idempotent backfill (only rows still NULL). The application rows themselves come from seed.sql.
-- =====================================================================
UPDATE app.applications
SET db_schema = CASE lower(code) WHEN 'gp' THEN 'gpp' WHEN 'sjo' THEN 'sjo' WHEN 'rospbu' THEN 'rospbu' END
WHERE db_schema IS NULL
  AND lower(code) IN ('gp', 'sjo', 'rospbu');
