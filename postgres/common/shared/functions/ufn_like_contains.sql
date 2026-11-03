-- =====================================================================
-- app.ufn_like_contains - turns user search text into a literal "contains" ILIKE pattern.
-- Escapes \ % _ so they match themselves (backslash is PostgreSQL's default LIKE escape).
-- Returns NULL for NULL / blank input so callers can skip the filter.
-- =====================================================================
CREATE OR REPLACE FUNCTION app.ufn_like_contains(p_search text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_search IS NULL OR btrim(p_search) = '' THEN NULL
        ELSE '%' || replace(replace(replace(btrim(p_search), '\', '\\'), '%', '\%'), '_', '\_') || '%'
    END;
$$;
