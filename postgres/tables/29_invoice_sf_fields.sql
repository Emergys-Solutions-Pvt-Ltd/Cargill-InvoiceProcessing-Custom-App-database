-- =====================================================================
-- app.invoice_sf_fields - legacy Salesforce "GP Invoice" fields not otherwise modeled
-- One row per invoice (1:1), added once instead of 58 columns onto app.invoices so the
-- core table and its view/type (app.vw_invoice_summary / app.udt_invoice_result, which are
-- positionally coupled via ROW(...)::type casts - see postgres/README.md) are left alone.
-- Field source: the SF "GP Invoice" object field export reconciled against this schema
-- 2026-11-02 (../shared/handoffs/database.md). Columns are named/typed from the SF field,
-- not renamed to this app's conventions, so they stay traceable back to the SF field list.
-- Deliberately NOT carried over (SF-internal automation or pure derived formulas, nothing to
-- store): AB Number (formula dup of ab_number), Area (Deprecated), Concatenate CUIT Invoice
-- Number (= vendors.cuit || invoices.invoice_code), Description (Deprecated), Expense Type
-- (Deprecated), EmailNotificationCount, FirePendingEmailNotification, ScheduleTime.
-- "Last Modified By" is on app.invoices directly (updated_by, parallel to created_by), not here.
-- Depends on: app.invoices
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.invoice_sf_fields (
    invoice_id                      integer         NOT NULL CONSTRAINT pk_invoice_sf_fields PRIMARY KEY
                                                     CONSTRAINT fk_invoice_sf_fields_invoice REFERENCES app.invoices (id) ON DELETE CASCADE,

    -- Identifiers / references
    invoice_1a_2a_cancel            varchar(50)     NULL,       -- "1 and 2 Invoice number cancel"
    first_invoice_number_cancel     varchar(5)      NULL,
    second_invoice_number_cancel    varchar(8)      NULL,
    ab_number                       varchar(255)    NULL,
    accounting_register             numeric(18,0)   NULL,
    code_of_imputation              varchar(255)    NULL,
    code_of_imputation_str          varchar(255)    NULL,       -- near-duplicate of code_of_imputation in SF; kept as-is, not merged
    gp_code_of_imputation           text            NULL,       -- legacy SF lookup id ("GP Code of Imputation"); no local table to reference
    cost_center                     numeric(18,0)   NULL,
    jde_number                      varchar(20)     NULL,
    nro_de_o6                       varchar(255)    NULL,       -- "Nro de O6"
    po_number                       varchar(255)    NULL,
    x1_number                       varchar(255)    NULL,
    owner_legacy_id                 text            NULL,       -- SF "Owner" (Lookup User,Group - polymorphic); raw legacy id
    user_legacy_id                  text            NULL,       -- SF "User" lookup, distinct from Assigned User / Owner; raw legacy id

    -- Picklists (free text: no fixed value list confirmed yet)
    adjustment_approval              varchar(100)    NULL,       -- "Aprobacion ajuste"
    branch_plant                     varchar(100)    NULL,
    center                           varchar(100)    NULL,
    code_type                        varchar(100)    NULL,
    drei                             varchar(100)    NULL,       -- "D.R.E.I."
    adjustment_doc                   varchar(100)    NULL,       -- "Doc ajuste"
    installment_payment              varchar(100)    NULL,       -- "Inst Payment"
    invoice_type                     varchar(100)    NULL,
    order_type                       varchar(100)    NULL,
    pending_reason                   varchar(100)    NULL,
    reject_reason                    varchar(100)    NULL,
    sub_process                      varchar(100)    NULL,

    -- Long text / notes
    area                             text            NULL,       -- "Area" (the real field; "Area (Deprecated)" not carried over)
    cbs_observation                  text            NULL,
    computation_formula              text            NULL,
    expense_type                     text            NULL,       -- "Expense Type" (the real field; deprecated formula variant not carried over)
    admin_observation                varchar(255)    NULL,
    approval_observation             varchar(255)    NULL,
    attachment_name_before_change    varchar(255)    NULL,
    credit_note_comments             varchar(255)    NULL,
    distribution_type                varchar(255)    NULL,
    notes                            varchar(255)    NULL,
    observation                      varchar(255)    NULL,
    reject_observation               varchar(255)    NULL,
    client_email                     varchar(255)    NULL,

    -- Dates
    admin_approved_date              timestamptz(0)  NULL,
    approval_date                    timestamptz(0)  NULL,
    cae_expiration_date              date            NULL,
    processed_date                   timestamptz(0)  NULL,
    rejection_date                   timestamptz(0)  NULL,

    -- Numbers
    cae_number                       numeric(15,0)   NULL,
    exchange_rate                    numeric(16,2)   NULL,
    payment_term                     numeric(16,2)   NULL,

    -- Flags
    is_boortmal_invoice              boolean         NOT NULL DEFAULT false,
    bu_employee_approver_done        boolean         NOT NULL DEFAULT false,
    is_distribution                  boolean         NOT NULL DEFAULT false,
    is_downloaded_invoice            boolean         NOT NULL DEFAULT false,
    has_po                           boolean         NOT NULL DEFAULT false,
    is_high_priority                 boolean         NOT NULL DEFAULT false,
    is_invoice_paid                  boolean         NOT NULL DEFAULT false,
    need_approval                    boolean         NOT NULL DEFAULT false,
    po_attached                      boolean         NOT NULL DEFAULT false,
    vip_control_done                 boolean         NOT NULL DEFAULT false,

    updated_at                       timestamptz(0)  NOT NULL DEFAULT now()
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
-- 4 more SF fields missed in the first pass (confirmed genuinely missing by Backend-1's
-- independent check, 2026-11-02 - see handoffs/database.md): Cantidad and Description are
-- invoice-header-level SF fields, distinct from the per-line app.invoice_line_items columns of
-- the same name. CUIT (Lookup "ROS CUIT") is a different SF object from the vendor CUIT this app
-- already exposes via app.vendors.cuit - same "legacy id, no local FK target" shape as
-- owner_legacy_id/user_legacy_id above. Due Date Invoice is distinct from invoices.invoice_expiry_date.
ALTER TABLE app.invoice_sf_fields ADD COLUMN IF NOT EXISTS cantidad          numeric(18,0) NULL;
ALTER TABLE app.invoice_sf_fields ADD COLUMN IF NOT EXISTS description      text          NULL;
ALTER TABLE app.invoice_sf_fields ADD COLUMN IF NOT EXISTS ros_cuit_legacy_id text        NULL;
ALTER TABLE app.invoice_sf_fields ADD COLUMN IF NOT EXISTS due_date_invoice date          NULL;
-- Invoice-level "Producto" picklist - distinct from the per-row producto already in ccpps[]
ALTER TABLE app.invoice_sf_fields ADD COLUMN IF NOT EXISTS producto         varchar(100)  NULL;
