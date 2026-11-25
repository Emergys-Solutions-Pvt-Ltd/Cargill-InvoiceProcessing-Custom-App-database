-- =====================================================================
-- app.udt_invoice_audit_result - RESPONSE type: one Audit History event (<app>.usp_invoice_audit_list)
-- changes: [{ field, oldValue, newValue }] for updates, NULL for created / deleted.
-- actor_name NULL = system (sync, mailbox) or a deleted user.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_invoice_audit_result AS (
    id              uuid,
    action          varchar(20),
    changes         jsonb,
    actor_user_id   uuid,
    actor_name      varchar(200),
    created_at      timestamptz(0)
);
