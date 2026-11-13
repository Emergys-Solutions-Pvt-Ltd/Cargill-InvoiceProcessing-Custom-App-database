-- =====================================================================
-- app.applications - top-level apps that drive permissions (GP, sjo, rospbu)
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.applications (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_applications PRIMARY KEY,
    code            varchar(50)     NOT NULL CONSTRAINT uq_applications_code UNIQUE,
    name            varchar(100)    NOT NULL,
    description     varchar(255)    NULL,
    is_active       boolean         NOT NULL DEFAULT true,
    created_at      timestamptz(0)  NOT NULL DEFAULT now()
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
-- Schema of the app's own invoice tables (<db_schema>.<db_schema>_invoices and child tables)
ALTER TABLE app.applications ADD COLUMN IF NOT EXISTS db_schema varchar(63) NULL;
UPDATE app.applications
SET db_schema = CASE lower(code) WHEN 'gp' THEN 'gpp' WHEN 'sjo' THEN 'sjo' WHEN 'rospbu' THEN 'rospbu' END
WHERE db_schema IS NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_applications_db_schema') THEN
        ALTER TABLE app.applications ADD CONSTRAINT ck_applications_db_schema
            CHECK (db_schema IS NULL OR db_schema IN ('gpp', 'sjo', 'rospbu'));
    END IF;
END $$;
