-- =====================================================================
-- app.usp_master_data_entities - the Configuration entities (tabs) in display order
-- Request:  none
-- Response: SETOF app.udt_master_data_entity_result
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_master_data_entities()
RETURNS SETOF app.udt_master_data_entity_result
LANGUAGE sql
STABLE
AS $$
    SELECT entity, label, parent_entity, code_required, has_color, sort_order
    FROM app.master_data_entities
    ORDER BY sort_order;
$$;
