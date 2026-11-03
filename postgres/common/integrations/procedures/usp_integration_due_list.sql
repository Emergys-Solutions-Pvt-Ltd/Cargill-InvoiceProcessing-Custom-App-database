-- =====================================================================
-- app.usp_integration_due_list - scheduler: active integrations whose automatic run is due
-- Request:  p_limit (max rows)
-- Response: SETOF app.udt_integration_result, oldest due first. Integrations with automatic
--           sync enabled but no next_run_at yet are included so the scheduler can plan them.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_integration_due_list(p_limit integer DEFAULT 20)
RETURNS SETOF app.udt_integration_result
LANGUAGE sql
STABLE
AS $$
    SELECT r.*
    FROM app.integrations i
    CROSS JOIN LATERAL app.ufn_integration_row(i.id) r
    WHERE i.is_active AND i.auto_sync_enabled AND (i.next_run_at IS NULL OR i.next_run_at <= now())
    ORDER BY i.next_run_at NULLS FIRST, i.id
    LIMIT greatest(coalesce(p_limit, 20), 1);
$$;
