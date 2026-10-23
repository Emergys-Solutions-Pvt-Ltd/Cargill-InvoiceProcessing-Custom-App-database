-- =====================================================================
-- app.usp_application_list - active applications (dashboard tiles / menu)
-- Request:  p_codes restricts the list when p_filter_by_codes = true
--           (non-admin users pass their assigned app codes)
-- Response: SETOF app.udt_application_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_application_list(
    p_codes             text[]  DEFAULT '{}',
    p_filter_by_codes   boolean DEFAULT false
)
RETURNS SETOF app.udt_application_result
LANGUAGE sql
STABLE
AS $$
    SELECT a.code, a.name, a.description
    FROM app.applications a
    WHERE a.is_active
      AND (NOT p_filter_by_codes OR a.code = ANY (p_codes))
    ORDER BY a.id;
$$;
