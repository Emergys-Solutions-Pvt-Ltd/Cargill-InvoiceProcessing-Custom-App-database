-- GENERATED from common/invoices/templates/procedures/usp_sync_invoice_apply.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- rospbu.usp_sync_invoice_apply - one mapped source invoice into ROSPBU (called per row by
-- app.usp_sync_page_apply, which owns the job, counters, errors and the per-row savepoint)
-- Request:  p_job_id, p_profile_id, p_integration_id, p_source_system, p_module_id,
--           p_default_status, p_cancel_status, p_cancellable (statuses a source cancellation may change),
--           p_row (app.udt_external_invoice_input, validated by the caller)
-- Response: app.udt_sync_invoice_apply_result (outcome created | updated | unchanged | skipped,
--           invoice code, message, needs_review = cancelled after processing started)
-- Errors:   CA409 the invoice id is already used by another ROSPBU invoice (caller records 'rejected')
-- =====================================================================
CREATE OR REPLACE FUNCTION rospbu.usp_sync_invoice_apply(
    p_job_id            integer,
    p_profile_id        integer,
    p_integration_id    integer,
    p_source_system     text,
    p_module_id         integer,
    p_default_status    text,
    p_cancel_status     text,
    p_cancellable       text[],
    p_row               app.udt_external_invoice_input
)
RETURNS app.udt_sync_invoice_apply_result
LANGUAGE plpgsql
AS $$
DECLARE
    r               app.udt_external_invoice_input := p_row;
    v_ref           record;
    v_vendor_id     integer;
    v_invoice_id    integer;
    v_msg           text;
    v_review        boolean := false;
BEGIN
    SELECT ref.id, ref.invoice_id, ref.payload_hash, ref.source_state, i.status, i.invoice_code
    INTO v_ref
    FROM rospbu.invoice_external_refs ref
    JOIN rospbu.rospbu_invoices i ON i.id = ref.invoice_id
    WHERE ref.source_system = p_source_system AND ref.external_key = r.external_key
    FOR UPDATE OF ref, i;

    IF NOT FOUND THEN
        IF coalesce(r.cancelled, false) THEN
            RETURN ROW('skipped', r.invoice_code, 'Cancelled in the source before it was imported', false)::app.udt_sync_invoice_apply_result;
        END IF;
        IF EXISTS (SELECT 1 FROM rospbu.rospbu_invoices WHERE invoice_code = r.invoice_code) THEN
            RAISE EXCEPTION 'Invoice id % is already used by another invoice.', r.invoice_code USING ERRCODE = 'CA409';
        END IF;

        INSERT INTO app.vendors (legal_name, cuit) VALUES (r.vendor_name, r.cuit) ON CONFLICT (cuit) DO NOTHING;
        SELECT id INTO v_vendor_id FROM app.vendors WHERE cuit = r.cuit;

        INSERT INTO rospbu.rospbu_invoices
            (invoice_code, module_id, vendor_id, invoice_1a, invoice_2a, first_invoice_number,
             second_invoice_number, invoice_date, currency_code, amount, invoice_subtotal,
             invoice_subtotal_with_tax, credit_note, status, reception_date, created_by)
        VALUES
            (r.invoice_code, p_module_id, v_vendor_id, r.invoice_1a, r.invoice_2a, r.first_invoice_number,
             r.second_invoice_number, r.invoice_date, coalesce(r.currency_code, 'ARS'), r.amount,
             coalesce(r.invoice_subtotal, r.amount), r.invoice_subtotal_with_tax, coalesce(r.credit_note, false),
             p_default_status, r.reception_date, NULL)
        RETURNING id INTO v_invoice_id;

        INSERT INTO rospbu.invoice_external_refs
            (invoice_id, source_system, external_key, integration_id, profile_id, external_doc,
             source_changed_at, payload_hash, source_state, first_job_id, last_job_id)
        VALUES
            (v_invoice_id, p_source_system, r.external_key, p_integration_id, p_profile_id, r.external_doc,
             r.source_changed_at, r.payload_hash, 'active', p_job_id, p_job_id);

        RETURN ROW('created', r.invoice_code, NULL, false)::app.udt_sync_invoice_apply_result;
    END IF;

    IF v_ref.payload_hash = r.payload_hash THEN
        UPDATE rospbu.invoice_external_refs SET last_job_id = p_job_id, last_synced_at = now() WHERE id = v_ref.id;
        RETURN ROW('unchanged', v_ref.invoice_code, NULL, false)::app.udt_sync_invoice_apply_result;
    END IF;

    INSERT INTO app.vendors (legal_name, cuit) VALUES (r.vendor_name, r.cuit) ON CONFLICT (cuit) DO NOTHING;
    SELECT id INTO v_vendor_id FROM app.vendors WHERE cuit = r.cuit;

    -- Source-owned fields only: status, team, assignee, process, claim ... stay as they are
    UPDATE rospbu.rospbu_invoices SET
        vendor_id                 = v_vendor_id,
        invoice_1a                = r.invoice_1a,
        invoice_2a                = r.invoice_2a,
        first_invoice_number      = r.first_invoice_number,
        second_invoice_number     = r.second_invoice_number,
        invoice_date              = r.invoice_date,
        currency_code             = coalesce(r.currency_code, currency_code),
        amount                    = r.amount,
        invoice_subtotal          = coalesce(r.invoice_subtotal, r.amount),
        invoice_subtotal_with_tax = r.invoice_subtotal_with_tax,
        credit_note               = coalesce(r.credit_note, false),
        reception_date            = r.reception_date,
        updated_at                = now()
    WHERE id = v_ref.invoice_id;

    IF coalesce(r.cancelled, false) AND v_ref.source_state = 'active' THEN
        IF v_ref.status = ANY (p_cancellable) THEN
            UPDATE rospbu.rospbu_invoices SET status = p_cancel_status WHERE id = v_ref.invoice_id;
            v_msg := 'Cancelled in the source: status set to ' || p_cancel_status;
        ELSE
            v_msg := 'Cancelled in the source after processing started (status ' || v_ref.status
                     || '); status left unchanged';
            v_review := true;
        END IF;
    END IF;

    UPDATE rospbu.invoice_external_refs SET
        payload_hash      = r.payload_hash,
        source_changed_at = r.source_changed_at,
        external_doc      = r.external_doc,
        source_state      = CASE WHEN coalesce(r.cancelled, false) THEN 'cancelled' ELSE 'active' END,
        last_job_id       = p_job_id,
        last_synced_at    = now()
    WHERE id = v_ref.id;

    RETURN ROW('updated', v_ref.invoice_code, v_msg, v_review)::app.udt_sync_invoice_apply_result;
END;
$$;

-- =====================================================================
-- rospbu.usp_integration_invoices_without_attachment - sync worker: which of the given ROSPBU
-- invoices still have no attachment, so the source document (e.g. the OnBase PDF) must be attached.
-- Request:  p_invoice_codes (invoice ids of one processed page)
-- Response: SETOF app.udt_code_result - the codes without any attachment
-- =====================================================================
CREATE OR REPLACE FUNCTION rospbu.usp_integration_invoices_without_attachment(p_invoice_codes text[])
RETURNS SETOF app.udt_code_result
LANGUAGE sql
STABLE
AS $$
    SELECT ROW(i.invoice_code)::app.udt_code_result
    FROM rospbu.rospbu_invoices i
    WHERE i.invoice_code = ANY (coalesce(p_invoice_codes, ARRAY[]::text[]))
      AND NOT EXISTS (SELECT 1 FROM rospbu.invoice_attachments a WHERE a.invoice_id = i.id);
$$;
