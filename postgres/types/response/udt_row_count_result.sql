-- =====================================================================
-- app.udt_row_count_result - RESPONSE type: outcome of a write that returns no entity
-- Returned by: usp_team_member_remove, usp_invoice_update_status, usp_user_touch_last_login
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_row_count_result AS (
    rows_affected    integer
);
