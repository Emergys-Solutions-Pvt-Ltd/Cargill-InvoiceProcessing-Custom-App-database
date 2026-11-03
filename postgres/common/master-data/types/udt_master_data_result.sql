-- =====================================================================
-- app.udt_master_data_result - RESPONSE type: one Configuration (master data) item
-- Returned by: usp_master_data_save. parent_* are set for states (country) and cities (state);
-- color only for statuses.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_master_data_result AS (
    id              integer,
    code            varchar(30),
    name            varchar(150),
    description     varchar(500),
    parent_id       integer,
    parent_name     varchar(150),
    color           varchar(20),
    sort_order      integer,
    is_active       boolean,
    updated_at      timestamptz(0)
);
