-- =====================================================================
-- app.udt_master_data_list_result - RESPONSE type: one page of master data items + paging
-- Returned by: usp_master_data_list. Paging columns repeat on every row; no rows = no matches.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_master_data_list_result AS (
    id              integer,
    code            varchar(30),
    name            varchar(150),
    description     varchar(500),
    parent_id       integer,
    parent_name     varchar(150),
    color           varchar(20),
    sort_order      integer,
    is_active       boolean,
    updated_at      timestamptz(0),
    total_items     integer,
    total_pages     integer,
    page            integer,
    page_size       integer
);
