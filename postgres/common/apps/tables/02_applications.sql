-- =====================================================================
-- app.applications - top-level apps that drive permissions (GP, sjo, rospbu)
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.applications (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_applications PRIMARY KEY,
    code            varchar(50)     NOT NULL CONSTRAINT uq_applications_code UNIQUE,
    name            varchar(100)    NOT NULL,
    description     varchar(255)    NULL,
    is_active       boolean         NOT NULL DEFAULT true,
    created_at      timestamptz(0)  NOT NULL DEFAULT now(),
    db_schema       varchar(63)     NULL,       -- schema of the app's own invoice tables (<db_schema>.<db_schema>_invoices)
    CONSTRAINT ck_applications_db_schema CHECK (db_schema IS NULL OR db_schema IN ('gpp', 'sjo', 'rospbu'))
);
