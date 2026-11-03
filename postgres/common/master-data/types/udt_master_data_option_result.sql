-- =====================================================================
-- app.udt_master_data_option_result - RESPONSE type: an active item for a dropdown
-- Returned by: usp_master_data_options (e.g. the country picker when editing a state)
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_master_data_option_result AS (
    id          integer,
    code        varchar(30),
    name        varchar(150),
    parent_id   integer,
    color       varchar(20)
);
