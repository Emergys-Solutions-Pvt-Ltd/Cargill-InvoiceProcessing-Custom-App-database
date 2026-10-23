-- =====================================================================
-- app.usp_invoice_send_to_previous_team - Invoice Details "Send to previous team"
-- Moves the invoice back one step in the team (queue) sequence: the active team ordered
-- just before the current one by (sort_order, id) - see Settings > Configuration > Teams.
-- The assigned user is cleared, since the invoice now belongs to another queue.
-- Request:  p_invoice_code
-- Response: app.udt_master_data_option_result - the team the invoice is now in
-- Errors:   CA404 invoice not found
--           CA409 invoice has no team yet, or is already with the first team
-- =====================================================================
CREATE OR REPLACE FUNCTION app.usp_invoice_send_to_previous_team(p_invoice_code text)
RETURNS app.udt_master_data_option_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    integer;
    v_current       app.teams;
    v_previous      app.teams;
BEGIN
    SELECT i.id INTO v_invoice_id FROM app.invoices i WHERE i.invoice_code = p_invoice_code FOR UPDATE;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;

    SELECT t.* INTO v_current FROM app.teams t JOIN app.invoices i ON i.team_id = t.id WHERE i.id = v_invoice_id;
    IF v_current.id IS NULL THEN
        RAISE EXCEPTION 'This invoice is not assigned to a team yet.' USING ERRCODE = 'CA409';
    END IF;

    SELECT t.* INTO v_previous
    FROM app.teams t
    WHERE t.is_active AND (t.sort_order, t.id) < (v_current.sort_order, v_current.id)
    ORDER BY t.sort_order DESC, t.id DESC
    LIMIT 1;
    IF v_previous.id IS NULL THEN
        RAISE EXCEPTION 'The invoice is already with the first team (%).', v_current.name USING ERRCODE = 'CA409';
    END IF;

    UPDATE app.invoices
       SET team_id = v_previous.id, assigned_user_id = NULL, updated_at = now()
     WHERE id = v_invoice_id;

    RETURN ROW(v_previous.id, v_previous.code, v_previous.name, NULL, NULL)::app.udt_master_data_option_result;
END;
$$;
