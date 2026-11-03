-- =====================================================================
-- Cargill Custom Apps - demo "received by email" data for the Invoice Details page
-- (Email button of the PDF preview). One email per invoice that has an
-- email_reception_date; the invoice PDF and tax certificate are linked as the
-- email's attachments, the transport manifest stays a user upload.
-- Sender addresses use the reserved .example domain.
-- Re-runnable: invoices that already have a source email are left alone. Included by
-- seed.sql; can also be run on its own:
--   psql "<connection>" -f database/postgres/seed_source_emails.sql
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

-- One file per app (generated from common/invoices/templates/seed/seed_source_emails.sql.tpl)
\ir gpp/invoices/seed/seed_source_emails.sql
\ir sjo/invoices/seed/seed_source_emails.sql
\ir rospbu/invoices/seed/seed_source_emails.sql

COMMIT;
