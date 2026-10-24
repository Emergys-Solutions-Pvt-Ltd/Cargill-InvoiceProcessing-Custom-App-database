-- =====================================================================
-- app.udt_integration_secret_result - RESPONSE type: encrypted credentials of an integration
-- Returned by: usp_integration_get_secret - backend only (decrypted in memory by the SecretStore).
-- String columns are text so ROW(...)::type casts never fail on varchar lengths.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app.udt_integration_secret_result AS (
    integration_id      integer,
    secret_ciphertext   text
);
