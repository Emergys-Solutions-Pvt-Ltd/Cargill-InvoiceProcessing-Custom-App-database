-- =====================================================================
-- app.mailboxes - Microsoft 365 mailboxes read by the background mailbox poller
-- One row per mailbox folder (e.g. cargill.poc@emergys.com / inbox). Emails found
-- there are stored in app.mailbox_emails and shown on the module's Inbox page.
-- delta_link is the Microsoft Graph delta cursor: NULL = next poll does a full sync
-- of the folder; otherwise only changes since the previous poll are read.
-- Depends on: app.app_modules
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.mailboxes (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_mailboxes PRIMARY KEY,
    address         varchar(255)    NOT NULL,                       -- mailbox SMTP address
    folder          varchar(255)    NOT NULL DEFAULT 'inbox',       -- Graph well-known name or folder id
    module_id       uuid         NOT NULL CONSTRAINT fk_mailboxes_module REFERENCES app.app_modules (id),
    is_active       boolean         NOT NULL DEFAULT true,          -- false = poller skips it, history kept
    delta_link      text            NULL,                           -- Graph @odata.deltaLink / nextLink
    last_polled_at  timestamptz(0)  NULL,                           -- last successful poll
    last_error      varchar(1000)   NULL,                           -- last failure, cleared on success
    created_at      timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at      timestamptz(0)  NOT NULL DEFAULT now()
);

-- The same mailbox folder must not be read twice (would import every email twice)
CREATE UNIQUE INDEX IF NOT EXISTS uq_mailboxes_address_folder ON app.mailboxes (lower(address), lower(folder));
-- Poller: active mailboxes
CREATE INDEX IF NOT EXISTS ix_mailboxes_active ON app.mailboxes (id) WHERE is_active;
