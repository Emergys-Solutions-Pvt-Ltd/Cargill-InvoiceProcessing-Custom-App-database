-- =====================================================================
-- app.usp_integration_audit_add - append an audit entry (who did what on an integration)
-- Request:  p_integration_id (NULL allowed, e.g. after delete), p_actor_user_id, p_action,
--           p_details (changed field names / outcome - never secret values)
-- Response: app.udt_row_count_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_audit_add(
    p_integration_id    uuid,
    p_actor_user_id     uuid,
    p_action            text,
    p_details           jsonb
)
RETURNS app.udt_row_count_result
LANGUAGE sql
AS $$
    WITH ins AS (
        INSERT INTO app.integration_audit_log (integration_id, actor_user_id, action, details)
        VALUES (p_integration_id, p_actor_user_id, left(p_action, 30), p_details)
        RETURNING 1
    )
    SELECT ROW(count(*)::integer)::app.udt_row_count_result FROM ins;
$$;
