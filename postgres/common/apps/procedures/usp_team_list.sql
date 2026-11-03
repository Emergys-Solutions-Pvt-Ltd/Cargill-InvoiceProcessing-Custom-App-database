-- =====================================================================
-- app.usp_team_list - active team (queue) names for the Team Assignment filter / Add Member
-- Teams are maintained under Settings > Configuration > Teams.
-- Request:  none
-- Response: SETOF app.udt_lookup_value_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_team_list()
RETURNS SETOF app.udt_lookup_value_result
LANGUAGE sql
STABLE
AS $$
    SELECT name::varchar(160), (row_number() OVER (ORDER BY sort_order, id))::integer
    FROM app.teams
    WHERE is_active
    ORDER BY sort_order, id;
$$;
