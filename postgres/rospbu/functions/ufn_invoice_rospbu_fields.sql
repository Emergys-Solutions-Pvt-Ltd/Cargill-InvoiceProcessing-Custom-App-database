-- =====================================================================
-- rospbu.ufn_invoice_rospbu_fields - one ROSPBU invoice's "ROSPBU Invoice Edit" fields as JSON
-- (Pais / BU / ERP resolved to { id, code, name }, NULL when not set).
-- Total de la FC, Fecha de Fc, Moneda de la Fc and Adicional Info are common invoice columns
-- (amount, invoice_date, currency_code, additional_info) and are repeated here for the form.
-- Used by: rospbu.usp_invoice_get_by_code
-- =====================================================================
CREATE OR REPLACE FUNCTION rospbu.ufn_invoice_rospbu_fields(p_invoice_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
    SELECT jsonb_build_object(
               'country',            CASE WHEN c.id IS NOT NULL THEN jsonb_build_object('id', c.id, 'code', c.code, 'name', c.name) END,
               'business_unit',      CASE WHEN bu.id IS NOT NULL THEN jsonb_build_object('id', bu.id, 'code', bu.code, 'name', bu.name) END,
               'erp_system',         CASE WHEN e.id IS NOT NULL THEN jsonb_build_object('id', e.id, 'code', e.code, 'name', e.name) END,
               'retencion',          f.retencion,
               'codigo_imputacion',  f.codigo_imputacion,
               'nro_ar',             f.nro_ar,
               'cantidad',           f.cantidad,
               'producto',           f.producto,
               'np',                 f.np,
               'nro_remito',         f.nro_remito,
               'filial',             f.filial,
               'additional_info',    f.additional_info,
               'numero_documento',   f.numero_documento,
               'general_comment',    f.general_comment,
               'total_fc',           f.amount,
               'invoice_date',       f.invoice_date,
               'centro_emisor',      f.centro_emisor,
               'due_date',           f.due_date,
               'currency_code',      f.currency_code,
               'po_number',          f.po_number,
               'instrumento_pago',   f.instrumento_pago,
               'timbrado',           f.timbrado,
               'bp_number',          f.bp_number,
               'numero_liquidacion', f.numero_liquidacion,
               'branch_plant',       f.branch_plant,
               'tipo_operacion',     f.tipo_operacion
           )
    FROM rospbu.rospbu_invoices f
    LEFT JOIN app.countries c       ON c.id = f.country_id
    LEFT JOIN app.business_units bu ON bu.id = f.business_unit_id
    LEFT JOIN sjo.erp_systems e     ON e.id = f.erp_system_id
    WHERE f.id = p_invoice_id;
$$;
