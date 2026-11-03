-- GENERATED from common/invoices/templates/seed/seed_source_emails.sql.tpl by tools/generate-app-invoice-sql.cjs - do not edit.
-- =====================================================================
-- Demo "received by email" data for ROSPBU invoices (Invoice Details > PDF preview > Email):
-- one email per invoice that has an email_reception_date; the invoice PDF and tax certificate are
-- linked as the email's attachments, the transport manifest stays a user upload.
-- Sender addresses use the reserved .example domain. Re-runnable: invoices that already have a
-- source email are left alone. Included by seed_source_emails.sql.
-- =====================================================================
WITH src AS (
    SELECT
        i.id,
        i.invoice_code,
        i.invoice_1a,
        i.amount,
        i.email_reception_date,
        m.slug,
        vd.legal_name,
        vd.cuit,
        -- 'Terminal Quequén S.A.' -> 'terminalquequen'
        lower(regexp_replace(
            regexp_replace(translate(vd.legal_name, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN'), '\s+(S\.A\.I\.C\.|S\.A\.|S\.R\.L\.)$', ''),
            '[^A-Za-z0-9]+', '', 'g')) AS domain_name
    FROM rospbu.rospbu_invoices i
    JOIN app.app_modules m ON m.id = i.module_id
    JOIN app.vendors vd    ON vd.id = i.vendor_id
    WHERE i.email_reception_date IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM rospbu.invoice_source_emails e WHERE e.invoice_id = i.id)
)
INSERT INTO rospbu.invoice_source_emails
    (invoice_id, message_id, from_name, from_address, to_addresses, cc_addresses, subject, body_text, received_at)
SELECT
    s.id,
    '<' || lower(s.invoice_code) || '.' || extract(epoch FROM s.email_reception_date)::bigint || '@mail.' || s.domain_name || '.example>',
    'Facturación - ' || s.legal_name,
    'facturacion@' || s.domain_name || '.example',
    'ap.' || lower(s.slug) || '.invoices@cargill.com',
    'cobranzas@' || s.domain_name || '.example',
    'Factura ' || s.invoice_1a || ' - ' || s.legal_name,
    concat_ws(chr(10),
        'Estimados,',
        '',
        'Adjuntamos la factura electrónica ' || s.invoice_1a || ' correspondiente a los servicios de flete prestados,',
        'junto con la constancia de inscripción en AFIP.',
        '',
        'Razón social: ' || s.legal_name,
        'CUIT: ' || s.cuit,
        'Importe: ARS ' || to_char(s.amount, 'FM999G999G990D00'),
        '',
        'Ante cualquier consulta, quedamos a disposición.',
        '',
        'Saludos cordiales,',
        'Departamento de Facturación',
        s.legal_name),
    s.email_reception_date
FROM src s
ORDER BY s.id;

-- The invoice PDF and the tax certificate arrived with the email
UPDATE rospbu.invoice_attachments att
SET source_email_id = e.id
FROM rospbu.invoice_source_emails e
WHERE e.invoice_id = att.invoice_id
  AND att.source_email_id IS NULL
  AND att.category IN ('Invoice Document', 'Tax Document');
