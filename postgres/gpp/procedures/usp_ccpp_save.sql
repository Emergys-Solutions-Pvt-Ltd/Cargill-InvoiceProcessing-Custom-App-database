-- =====================================================================
-- gpp.usp_ccpp_save - GP Invoice Detail "CCPP" tab: add (p_id NULL) or update one CCPP row
-- Request:  p_invoice_code, p_user_id (acting user: sets created_by on insert, updated_by always),
--           p_product, p_status (required, match gpp.invoice_ccpps), everything else optional -
--           the legacy Salesforce "GP CCPP" fields, named/typed as in gpp.invoice_ccpps'
--           UPGRADES section (../shared/handoffs/database.md, 2026-11-02).
-- Response: gpp.udt_ccpp_result (the saved row)
-- Errors:   CA400 missing product/status, unknown acting user
--           CA404 invoice not found, or (on update) CCPP row not found / belongs to another invoice
-- =====================================================================
CREATE OR REPLACE FUNCTION gpp.usp_ccpp_save(
    p_invoice_code              text,
    p_user_id                   uuid,
    p_product                   varchar(100),
    p_status                    varchar(50),
    p_id                        uuid       DEFAULT NULL,
    p_legal_doc_issuer          varchar(200)  DEFAULT NULL,
    p_value                     numeric(18,2) DEFAULT NULL,
    p_km                        numeric(10,2) DEFAULT NULL,
    p_tons                      numeric(18,2) DEFAULT NULL,
    p_unit_rate                 numeric(18,2) DEFAULT NULL,
    p_km_fc                     numeric(10,2) DEFAULT NULL,
    p_tons_fc                   numeric(18,2) DEFAULT NULL,
    p_third_jurisdiction        varchar(255)  DEFAULT NULL,
    p_ab                        varchar(20)   DEFAULT NULL,
    p_aux                       varchar(20)   DEFAULT NULL,
    p_bp                        varchar(50)   DEFAULT NULL,
    p_closed_quantity           numeric(16,2) DEFAULT NULL,
    p_pending_quantity          numeric(16,2) DEFAULT NULL,
    p_total_quantity            numeric(16,2) DEFAULT NULL,
    p_cc                        varchar(50)   DEFAULT NULL,
    p_cia                       varchar(20)   DEFAULT NULL,
    p_withholding_code          varchar(255)  DEFAULT NULL,
    p_withholding_concept       varchar(255)  DEFAULT NULL,
    p_matching                  varchar(20)   DEFAULT NULL,
    p_account                   varchar(20)   DEFAULT NULL,
    p_cuit                      varchar(20)   DEFAULT NULL,
    p_line_description          text          DEFAULT NULL,
    p_receipt_detail            varchar(255)  DEFAULT NULL,
    p_status1                   varchar(50)   DEFAULT NULL,
    p_status2                   varchar(50)   DEFAULT NULL,
    p_receipt_date              varchar(50)   DEFAULT NULL,
    p_gcia                      varchar(100)  DEFAULT NULL,
    p_name                      varchar(100)  DEFAULT NULL,
    p_iibb_destination          varchar(100)  DEFAULT NULL,
    p_iibb_origin               varchar(100)  DEFAULT NULL,
    p_closed_amount             varchar(20)   DEFAULT NULL,
    p_line_amount                numeric(16,2) DEFAULT NULL,
    p_matched_amount            varchar(20)   DEFAULT NULL,
    p_pending_amount            numeric(16,2) DEFAULT NULL,
    p_order_total_amount        numeric(16,2) DEFAULT NULL,
    p_vat                       varchar(100)  DEFAULT NULL,
    p_line                      numeric(18,0) DEFAULT NULL,
    p_currency                  varchar(10)   DEFAULT NULL,
    p_municipality              varchar(100)  DEFAULT NULL,
    p_order_number              varchar(20)   DEFAULT NULL,
    p_receipt_number            varchar(20)   DEFAULT NULL,
    p_observation               text          DEFAULT NULL,
    p_origin_destination_drei   varchar(255)  DEFAULT NULL,
    p_owner_legacy_id           text          DEFAULT NULL,
    p_praclo                    varchar(20)   DEFAULT NULL,
    p_praptd                    varchar(20)   DEFAULT NULL,
    p_prdgl                     varchar(50)   DEFAULT NULL,
    p_province                  varchar(255)  DEFAULT NULL,
    p_pruorg                    varchar(20)   DEFAULT NULL,
    p_suss                      varchar(100)  DEFAULT NULL,
    p_tax_area                  varchar(255)  DEFAULT NULL,
    p_order_type                varchar(20)   DEFAULT NULL,
    p_receipt_type               varchar(20)   DEFAULT NULL,
    p_take_line                 varchar(100)  DEFAULT NULL,
    p_unique_ccpp                varchar(255)  DEFAULT NULL,
    p_user_legacy_id            varchar(50)   DEFAULT NULL,
    p_fiscal_zone                varchar(100)  DEFAULT NULL
)
RETURNS gpp.udt_ccpp_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_invoice_id    uuid;
    v_product       varchar(100) := nullif(btrim(p_product), '');
    v_status        varchar(50)  := nullif(btrim(p_status), '');
    v_id            uuid;
    v_result        gpp.udt_ccpp_result;
BEGIN
    SELECT i.id INTO v_invoice_id FROM gpp.gpp_invoices i WHERE i.invoice_code = p_invoice_code;
    IF v_invoice_id IS NULL THEN
        RAISE EXCEPTION 'Invoice not found.' USING ERRCODE = 'CA404';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM app_auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Acting user not found.' USING ERRCODE = 'CA400';
    END IF;
    IF v_product IS NULL THEN
        RAISE EXCEPTION 'Product is required.' USING ERRCODE = 'CA400';
    END IF;
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Status is required.' USING ERRCODE = 'CA400';
    END IF;

    BEGIN
        IF p_id IS NULL THEN
            INSERT INTO gpp.invoice_ccpps (
                invoice_id, product, legal_doc_issuer, status, value, km, tons, unit_rate, km_fc, tons_fc,
                third_jurisdiction, ab, aux, bp, closed_quantity, pending_quantity, total_quantity,
                cc, cia, withholding_code, withholding_concept, matching, created_by, updated_by,
                account, cuit, line_description, receipt_detail, status1, status2, receipt_date,
                gcia, name, iibb_destination, iibb_origin, closed_amount, line_amount,
                matched_amount, pending_amount, order_total_amount, vat, line, currency, municipality,
                order_number, receipt_number, observation, origin_destination_drei, owner_legacy_id,
                praclo, praptd, prdgl, province, pruorg, suss, tax_area, order_type, receipt_type,
                take_line, unique_ccpp, user_legacy_id, fiscal_zone
            ) VALUES (
                v_invoice_id, v_product, nullif(btrim(p_legal_doc_issuer), ''), v_status, p_value, p_km, p_tons, p_unit_rate, p_km_fc, p_tons_fc,
                p_third_jurisdiction, p_ab, p_aux, p_bp, p_closed_quantity, p_pending_quantity, p_total_quantity,
                p_cc, p_cia, p_withholding_code, p_withholding_concept, p_matching, p_user_id, p_user_id,
                p_account, p_cuit, p_line_description, p_receipt_detail, p_status1, p_status2, p_receipt_date,
                p_gcia, p_name, p_iibb_destination, p_iibb_origin, p_closed_amount, p_line_amount,
                p_matched_amount, p_pending_amount, p_order_total_amount, p_vat, p_line, p_currency, p_municipality,
                p_order_number, p_receipt_number, p_observation, p_origin_destination_drei, p_owner_legacy_id,
                p_praclo, p_praptd, p_prdgl, p_province, p_pruorg, p_suss, p_tax_area, p_order_type, p_receipt_type,
                p_take_line, p_unique_ccpp, p_user_legacy_id, p_fiscal_zone
            )
            RETURNING id INTO v_id;
        ELSE
            UPDATE gpp.invoice_ccpps SET
                product = v_product, legal_doc_issuer = nullif(btrim(p_legal_doc_issuer), ''), status = v_status,
                value = p_value, km = p_km, tons = p_tons, unit_rate = p_unit_rate, km_fc = p_km_fc, tons_fc = p_tons_fc,
                third_jurisdiction = p_third_jurisdiction, ab = p_ab, aux = p_aux, bp = p_bp,
                closed_quantity = p_closed_quantity, pending_quantity = p_pending_quantity, total_quantity = p_total_quantity,
                cc = p_cc, cia = p_cia, withholding_code = p_withholding_code, withholding_concept = p_withholding_concept,
                matching = p_matching, updated_by = p_user_id,
                account = p_account, cuit = p_cuit, line_description = p_line_description, receipt_detail = p_receipt_detail,
                status1 = p_status1, status2 = p_status2, receipt_date = p_receipt_date,
                gcia = p_gcia, name = p_name, iibb_destination = p_iibb_destination, iibb_origin = p_iibb_origin,
                closed_amount = p_closed_amount, line_amount = p_line_amount,
                matched_amount = p_matched_amount, pending_amount = p_pending_amount, order_total_amount = p_order_total_amount,
                vat = p_vat, line = p_line, currency = p_currency, municipality = p_municipality,
                order_number = p_order_number, receipt_number = p_receipt_number, observation = p_observation,
                origin_destination_drei = p_origin_destination_drei, owner_legacy_id = p_owner_legacy_id,
                praclo = p_praclo, praptd = p_praptd, prdgl = p_prdgl, province = p_province,
                pruorg = p_pruorg, suss = p_suss, tax_area = p_tax_area, order_type = p_order_type,
                receipt_type = p_receipt_type, take_line = p_take_line, unique_ccpp = p_unique_ccpp,
                user_legacy_id = p_user_legacy_id, fiscal_zone = p_fiscal_zone
            WHERE id = p_id AND invoice_id = v_invoice_id
            RETURNING id INTO v_id;
            IF v_id IS NULL THEN
                RAISE EXCEPTION 'CCPP row not found for this invoice.' USING ERRCODE = 'CA404';
            END IF;
        END IF;
    EXCEPTION
        WHEN string_data_right_truncation THEN
            RAISE EXCEPTION 'A value is too long for this field.' USING ERRCODE = 'CA400';
    END;

    SELECT c.id, c.invoice_id, c.product, c.legal_doc_issuer, c.status, c.value, c.km, c.tons, c.unit_rate, c.km_fc, c.tons_fc,
           c.third_jurisdiction, c.ab, c.aux, c.bp, c.closed_quantity, c.pending_quantity, c.total_quantity,
           c.cc, c.cia, c.withholding_code, c.withholding_concept, c.matching, c.created_by, ccb.name,
           c.account, c.cuit, c.line_description, c.receipt_detail, c.status1, c.status2, c.receipt_date,
           c.gcia, c.name, c.iibb_destination, c.iibb_origin, c.closed_amount, c.line_amount,
           c.matched_amount, c.pending_amount, c.order_total_amount, c.vat, c.updated_by, cub.name,
           c.line, c.currency, c.municipality, c.order_number, c.receipt_number, c.observation,
           c.origin_destination_drei, c.owner_legacy_id, c.praclo, c.praptd, c.prdgl, c.province,
           c.pruorg, c.suss, c.tax_area, c.order_type, c.receipt_type, c.take_line, c.unique_ccpp,
           c.user_legacy_id, c.fiscal_zone
    INTO v_result
    FROM gpp.invoice_ccpps c
    LEFT JOIN app_auth.users ccb ON ccb.id = c.created_by
    LEFT JOIN app_auth.users cub ON cub.id = c.updated_by
    WHERE c.id = v_id;

    RETURN v_result;
END;
$$;
