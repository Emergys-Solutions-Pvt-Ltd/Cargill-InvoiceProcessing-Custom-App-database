-- =====================================================================
-- app.statuses - Configuration > Statuses: the invoice workflow statuses.
-- Each app invoice table (gpp.gpp_invoices, sjo.sjo_invoices, rospbu.rospbu_invoices) references
-- statuses.code with ON UPDATE CASCADE, so renaming a
-- code updates existing invoices and a status in use cannot be deleted.
-- The four core statuses are system data: postdeploy/20_statuses.sql (not seed.sql).
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.statuses (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_statuses PRIMARY KEY,
    code        varchar(20)     NOT NULL CONSTRAINT uq_statuses_code UNIQUE,  -- value stored in invoices.status
    name        varchar(150)    NOT NULL,                       -- label shown in the UI
    description varchar(500)    NULL,
    color       varchar(20)     NULL,                           -- pill style: warning | info | success | danger | neutral
    sort_order  integer         NOT NULL DEFAULT 0,
    is_active   boolean         NOT NULL DEFAULT true,
    created_at  timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at  timestamptz(0)  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_statuses_name ON app.statuses (lower(name));
