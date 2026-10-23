-- =====================================================================
-- app.invoices - workflow / Super User fields shown on the Invoice Details page
-- (process, origin / destination, current team = stage, assigned user, claim, FileNet id).
-- Kept in its own script because it references master data tables (14-19) that are
-- created after 10_invoices.sql.
-- Idempotent: every change is guarded. Run through deploy_schema.sql.
-- =====================================================================
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS process_id          integer       NULL;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS origin_city_id      integer       NULL;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS destination_city_id integer       NULL;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS team_id             integer       NULL;   -- current team / queue (the "Stage")
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS assigned_user_id    integer       NULL;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS claim_number        numeric(18,2) NOT NULL DEFAULT 0;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS additional_info     varchar(1000) NULL;
ALTER TABLE app.invoices ADD COLUMN IF NOT EXISTS filenet_id          varchar(60)   NULL;   -- document id in IBM FileNet

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_process') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT fk_invoices_process FOREIGN KEY (process_id) REFERENCES app.processes (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_origin_city') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT fk_invoices_origin_city FOREIGN KEY (origin_city_id) REFERENCES app.cities (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_destination_city') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT fk_invoices_destination_city FOREIGN KEY (destination_city_id) REFERENCES app.cities (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_team') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT fk_invoices_team FOREIGN KEY (team_id) REFERENCES app.teams (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_invoices_assigned_user') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT fk_invoices_assigned_user FOREIGN KEY (assigned_user_id) REFERENCES app.users (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_invoices_claim_number') THEN
        ALTER TABLE app.invoices ADD CONSTRAINT ck_invoices_claim_number CHECK (claim_number >= 0);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_invoices_team          ON app.invoices (team_id);
CREATE INDEX IF NOT EXISTS ix_invoices_assigned_user ON app.invoices (assigned_user_id);

-- ---- UPGRADES (append guarded changes) ----
