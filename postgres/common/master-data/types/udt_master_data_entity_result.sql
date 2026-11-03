-- =====================================================================
-- app.udt_master_data_entity_result - RESPONSE type: a Configuration entity definition
-- Returned by: usp_master_data_entities (drives the Configuration tabs and forms)
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_master_data_entity_result AS (
    entity          varchar(40),
    label           varchar(60),
    parent_entity   varchar(40),
    code_required   boolean,
    has_color       boolean,
    sort_order      integer
);
