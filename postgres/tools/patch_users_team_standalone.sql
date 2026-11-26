-- =====================================================================
-- One-off patch: Settings > Users team assignment (2026-11-25) - STANDALONE version
-- Generated from tools/patch_users_team.sql with all includes inlined, so it can be pasted into
-- any SQL editor (Supabase SQL Editor, Azure Data Studio, pgAdmin, DBeaver) and run as one script.
-- Safe to re-run; runs in one transaction; no data is dropped. Adds app_auth.users.team_id
-- (NULL for existing users), FK fk_users_team -> app.teams, and recreates the user view,
-- result types and usp_user_get_by_id / _list / _create / _update.
-- =====================================================================
SET client_min_messages = warning;

BEGIN;

-- Tables (idempotent: only the guarded UPGRADES sections do anything on an existing DB)

-- >>> ../auth/tables/01_users.sql
-- =====================================================================
-- app_auth.users - platform users (Login, Settings / User Access Management)
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app_auth.users (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_users PRIMARY KEY,
    username        varchar(150)    NOT NULL,                       -- short login alias, e.g. "admin"
    email           varchar(255)    NOT NULL,
    name            varchar(200)    NOT NULL,
    role            varchar(20)     NOT NULL DEFAULT 'User',
    status          varchar(20)     NOT NULL DEFAULT 'Active',
    auth_provider   varchar(20)     NOT NULL DEFAULT 'LOCAL',
    password_hash   varchar(255)    NULL,                           -- NULL for Azure AD users
    last_login_at   timestamptz(0)  NULL,
    created_at      timestamptz(0)  NOT NULL DEFAULT now(),
    updated_at      timestamptz(0)  NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_role   CHECK (role IN ('Admin', 'User')),
    CONSTRAINT ck_users_status CHECK (status IN ('Active', 'Suspended')),
    CONSTRAINT ck_users_auth   CHECK (auth_provider IN ('LOCAL', 'AD'))
);

-- Case-insensitive uniqueness (emails / usernames are compared with lower())
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email    ON app_auth.users (lower(email));
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username ON app_auth.users (lower(username));

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
-- Example:
-- ALTER TABLE app_auth.users ADD COLUMN IF NOT EXISTS phone varchar(30) NULL;
-- A user belongs to at most one team (app.teams, Settings > Configuration > Teams).
-- The FK fk_users_team is added in common/master-data/tables/05_teams.sql (app.teams is created after this file).
ALTER TABLE app_auth.users ADD COLUMN IF NOT EXISTS team_id uuid NULL;
CREATE INDEX IF NOT EXISTS ix_users_team ON app_auth.users (team_id);

-- >>> ../common/master-data/tables/05_teams.sql
-- =====================================================================
-- app.teams - team names used on the Admin Configuration screen
-- Idempotent: creates the table when missing; the UPGRADES section brings
-- existing databases up to date. Run through deploy_schema.sql.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.teams (
    id      uuid DEFAULT gen_random_uuid() CONSTRAINT pk_teams PRIMARY KEY,
    name    varchar(100)    NOT NULL CONSTRAINT uq_teams_name UNIQUE
);

-- ---- UPGRADES (append guarded changes; never edit the CREATE above for existing DBs) ----
-- Teams (queues) became master data managed under Settings > Configuration
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS code        varchar(30)    NULL;
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS description varchar(500)   NULL;
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS sort_order  integer        NOT NULL DEFAULT 0;
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS is_active   boolean        NOT NULL DEFAULT true;
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS created_at  timestamptz(0) NOT NULL DEFAULT now();
ALTER TABLE app.teams ADD COLUMN IF NOT EXISTS updated_at  timestamptz(0) NOT NULL DEFAULT now();
-- Guarded: once widened, views (vw_invoice_summary) depend on the column and block ALTER TYPE
DO $$
BEGIN
    IF (SELECT character_maximum_length FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'teams' AND column_name = 'name') < 150 THEN
        ALTER TABLE app.teams ALTER COLUMN name TYPE varchar(150);
    END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS uq_teams_code ON app.teams (lower(code)) WHERE code IS NOT NULL;
-- Settings > Users: a user's single team (app_auth.users.team_id, added in auth/tables/01_users.sql).
-- Teams are only deactivated, never deleted; SET NULL is a safety net.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_team' AND conrelid = 'app_auth.users'::regclass) THEN
        ALTER TABLE app_auth.users
            ADD CONSTRAINT fk_users_team FOREIGN KEY (team_id) REFERENCES app.teams (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Drop the objects whose shape changed. CASCADE also drops usp_user_get_by_id / _list / _create /
-- _update (they return these types); all of them are recreated below.
DROP VIEW IF EXISTS app_auth.vw_user_summary CASCADE;
DROP TYPE IF EXISTS app_auth.udt_user_list_result CASCADE;
DROP TYPE IF EXISTS app_auth.udt_user_result CASCADE;
-- Old signatures, in case they survived (e.g. a different return type)
DROP FUNCTION IF EXISTS app_auth.usp_user_create(text, text, text, text, text, text, text[]);
DROP FUNCTION IF EXISTS app_auth.usp_user_update(uuid, text, text, text, text[], text);

-- >>> ../auth/types/udt_user_result.sql
-- =====================================================================
-- app_auth.udt_user_result - RESPONSE type: user row (Settings / UAM, auth context)
-- Returned by: usp_user_get_by_id, usp_user_create, usp_user_update
-- Never contains the password hash (see udt_user_login_result).
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app_auth.udt_user_result AS (
    id               uuid,
    username         varchar(150),
    name             varchar(200),
    email            varchar(255),
    role             varchar(20),
    status           varchar(20),
    auth_provider    varchar(20),
    assigned_apps    text,                 -- comma separated application codes, e.g. "GP,sjo"
    team_id          uuid,                 -- app.teams.id (NULL = no team)
    team_name        varchar(150)
);

-- >>> ../auth/types/udt_user_list_result.sql
-- =====================================================================
-- app_auth.udt_user_list_result - RESPONSE type: one page of users plus paging metadata
-- Returned by: usp_user_list. Paging columns repeat on every row; no rows = no matches.
-- (Re)created by deploy_schema.sql, which drops all usp_/udt_ objects first.
-- =====================================================================
CREATE TYPE app_auth.udt_user_list_result AS (
    id               uuid,
    username         varchar(150),
    name             varchar(200),
    email            varchar(255),
    role             varchar(20),
    status           varchar(20),
    auth_provider    varchar(20),
    assigned_apps    text,                 -- comma separated application codes, e.g. "GP,sjo"
    team_id          uuid,                 -- app.teams.id (NULL = no team)
    team_name        varchar(150),
    total_items      integer,
    total_pages      integer,
    page             integer,
    page_size        integer
);

-- >>> ../auth/views/vw_user_summary.sql
-- =====================================================================
-- app_auth.vw_user_summary - users with their assigned application codes aggregated
-- into a comma separated list, plus the user's team (app.teams). The first nine columns
-- match app_auth.udt_user_login_result.
-- Used by: usp_user_* functions (password_hash is only selected for login)
-- =====================================================================
CREATE OR REPLACE VIEW app_auth.vw_user_summary AS
SELECT
    u.id,
    u.username,
    u.name,
    u.email,
    u.role,
    u.status,
    u.auth_provider,
    (SELECT string_agg(a.code, ',' ORDER BY a.id)
       FROM app_auth.user_applications ua
       JOIN app.applications a ON a.id = ua.application_id
      WHERE ua.user_id = u.id) AS assigned_apps,
    u.password_hash,
    u.team_id,
    t.name AS team_name
FROM app_auth.users u
LEFT JOIN app.teams t ON t.id = u.team_id;

-- >>> ../auth/procedures/usp_user_get_by_id.sql
-- =====================================================================
-- app_auth.usp_user_get_by_id - one user (auth middleware reload, Settings detail)
-- Request:  p_user_id; p_active_only = true returns nothing for suspended users
-- Response: SETOF app_auth.udt_user_result (no rows when not found)
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_get_by_id(
    p_user_id       uuid,
    p_active_only   boolean DEFAULT false
)
RETURNS SETOF app_auth.udt_user_result
LANGUAGE sql
STABLE
AS $$
    SELECT id, username, name, email, role, status, auth_provider, assigned_apps, team_id, team_name
    FROM app_auth.vw_user_summary
    WHERE id = p_user_id
      AND (NOT p_active_only OR status = 'Active');
$$;

-- >>> ../auth/procedures/usp_user_list.sql
-- =====================================================================
-- app_auth.usp_user_list - Settings / User Access Management grid (newest first)
-- Request:  p_search (name or email contains, case-insensitive), p_app_code ('ALL' or a code),
--           p_role ('ALL', 'Admin', 'User'), p_page (1-based, clamped), p_page_size (1-100)
-- Response: SETOF app_auth.udt_user_list_result (paging columns on every row)
-- Errors:   CA400 invalid page size
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_list(
    p_search        text    DEFAULT NULL,
    p_app_code      text    DEFAULT 'ALL',
    p_role          text    DEFAULT 'ALL',
    p_page          integer DEFAULT 1,
    p_page_size     integer DEFAULT 5
)
RETURNS SETOF app_auth.udt_user_list_result
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_pattern text := app.ufn_like_contains(p_search);
BEGIN
    IF p_page_size IS NULL OR p_page_size NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'PageSize must be between 1 and 100.' USING ERRCODE = 'CA400';
    END IF;

    RETURN QUERY
    WITH matches AS (
        SELECT v.*,
               row_number() OVER (ORDER BY v.id DESC) AS rn,
               count(*) OVER ()::integer              AS total
        FROM app_auth.vw_user_summary v
        WHERE (v_pattern IS NULL OR v.name ILIKE v_pattern OR v.email ILIKE v_pattern)
          AND (coalesce(p_role, 'ALL') = 'ALL' OR v.role = p_role)
          AND (coalesce(p_app_code, 'ALL') = 'ALL' OR EXISTS (
                SELECT 1 FROM app_auth.user_applications ua
                JOIN app.applications a ON a.id = ua.application_id
                WHERE ua.user_id = v.id AND a.code = p_app_code))
    ),
    paging AS (
        SELECT pages, least(greatest(coalesce(p_page, 1), 1), pages) AS page
        FROM (SELECT greatest(1, ceil(max(total)::numeric / p_page_size))::integer AS pages FROM matches) t
    )
    SELECT m.id, m.username, m.name, m.email, m.role, m.status, m.auth_provider, m.assigned_apps,
           m.team_id, m.team_name,
           m.total, p.pages, p.page, p_page_size
    FROM matches m CROSS JOIN paging p
    WHERE m.rn BETWEEN (p.page - 1) * p_page_size + 1 AND p.page * p_page_size
    ORDER BY m.rn;
END;
$$;

-- >>> ../auth/procedures/usp_user_create.sql
-- =====================================================================
-- app_auth.usp_user_create - "Add New User" (Settings / UAM)
-- Request:  user fields + p_app_codes (application codes to grant) + p_team_id (optional,
--           an active app.teams id - Settings > Configuration > Teams; one team per user).
--           p_password_hash is a bcrypt hash for LOCAL users, NULL for AD users.
-- Response: app_auth.udt_user_result (the created user)
-- Errors:   CA400 invalid role / provider / unknown application code / unknown or inactive team,
--           or LOCAL without password
--           CA409 email or username already exists
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_create(
    p_username      text,
    p_name          text,
    p_email         text,
    p_role          text    DEFAULT 'User',
    p_auth_provider text    DEFAULT 'AD',
    p_password_hash text    DEFAULT NULL,
    p_app_codes     text[]  DEFAULT '{}',
    p_team_id       uuid    DEFAULT NULL
)
RETURNS app_auth.udt_user_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_unknown   text;
    v_id        uuid;
    v_result    app_auth.udt_user_result;
BEGIN
    IF p_role NOT IN ('Admin', 'User') THEN
        RAISE EXCEPTION 'Role must be Admin or User.' USING ERRCODE = 'CA400';
    END IF;
    IF p_auth_provider NOT IN ('LOCAL', 'AD') THEN
        RAISE EXCEPTION 'AuthProvider must be LOCAL or AD.' USING ERRCODE = 'CA400';
    END IF;
    IF p_auth_provider = 'LOCAL' AND p_password_hash IS NULL THEN
        RAISE EXCEPTION 'A password is required for LOCAL users.' USING ERRCODE = 'CA400';
    END IF;

    SELECT string_agg(c, ', ') INTO v_unknown
    FROM unnest(coalesce(p_app_codes, '{}')) AS c
    WHERE NOT EXISTS (SELECT 1 FROM app.applications a WHERE a.code = c AND a.is_active);
    IF v_unknown IS NOT NULL THEN
        RAISE EXCEPTION 'Unknown application(s): %', v_unknown USING ERRCODE = 'CA400';
    END IF;

    IF p_team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app.teams WHERE id = p_team_id AND is_active) THEN
        RAISE EXCEPTION 'Unknown or inactive team.' USING ERRCODE = 'CA400';
    END IF;

    IF EXISTS (SELECT 1 FROM app_auth.users WHERE lower(email) = lower(p_email) OR lower(username) = lower(p_username)) THEN
        RAISE EXCEPTION 'A user with email or username ''%'' already exists', p_email USING ERRCODE = 'CA409';
    END IF;

    INSERT INTO app_auth.users (username, name, email, role, auth_provider, password_hash, team_id)
    VALUES (p_username, p_name, p_email, p_role, p_auth_provider, p_password_hash, p_team_id)
    RETURNING id INTO v_id;

    INSERT INTO app_auth.user_applications (user_id, application_id)
    SELECT v_id, a.id FROM app.applications a WHERE a.code = ANY (p_app_codes);

    SELECT id, username, name, email, role, status, auth_provider, assigned_apps, team_id, team_name
    INTO v_result
    FROM app_auth.vw_user_summary WHERE id = v_id;
    RETURN v_result;
END;
$$;

-- >>> ../auth/procedures/usp_user_update.sql
-- =====================================================================
-- app_auth.usp_user_update - edit a user / Suspend-Activate toggle (Settings / UAM)
-- Request:  p_user_id; NULL p_name / p_email / p_role / p_status keep the current value.
--           A username that equals the old email follows an email change.
--           p_app_codes replaces the assigned apps when it is NOT NULL.
--           p_team_id moves the user to that team (one team per user); p_clear_team = true
--           removes the team. Both NULL/false keep the current team. A new team must be active.
-- Response: app_auth.udt_user_result (the updated user)
-- Errors:   CA400 invalid role / status / unknown application code / unknown or inactive team
--           CA404 user not found
--           CA409 email already used by another user
-- =====================================================================
CREATE OR REPLACE FUNCTION app_auth.usp_user_update(
    p_user_id   uuid,
    p_name      text    DEFAULT NULL,
    p_role      text    DEFAULT NULL,
    p_status    text    DEFAULT NULL,
    p_app_codes text[]  DEFAULT NULL,
    p_email     text    DEFAULT NULL,
    p_team_id   uuid    DEFAULT NULL,
    p_clear_team boolean DEFAULT false
)
RETURNS app_auth.udt_user_result
LANGUAGE plpgsql
AS $$
DECLARE
    v_unknown   text;
    v_result    app_auth.udt_user_result;
BEGIN
    IF p_role IS NOT NULL AND p_role NOT IN ('Admin', 'User') THEN
        RAISE EXCEPTION 'Role must be Admin or User.' USING ERRCODE = 'CA400';
    END IF;
    IF p_status IS NOT NULL AND p_status NOT IN ('Active', 'Suspended') THEN
        RAISE EXCEPTION 'Status must be Active or Suspended.' USING ERRCODE = 'CA400';
    END IF;

    IF p_app_codes IS NOT NULL THEN
        SELECT string_agg(c, ', ') INTO v_unknown
        FROM unnest(p_app_codes) AS c
        WHERE NOT EXISTS (SELECT 1 FROM app.applications a WHERE a.code = c AND a.is_active);
        IF v_unknown IS NOT NULL THEN
            RAISE EXCEPTION 'Unknown application(s): %', v_unknown USING ERRCODE = 'CA400';
        END IF;
    END IF;

    -- Keeping an already assigned team that was deactivated since is allowed
    IF p_team_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM app.teams WHERE id = p_team_id AND is_active)
       AND NOT EXISTS (SELECT 1 FROM app_auth.users WHERE id = p_user_id AND team_id = p_team_id) THEN
        RAISE EXCEPTION 'Unknown or inactive team.' USING ERRCODE = 'CA400';
    END IF;

    IF p_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM app_auth.users
        WHERE id <> p_user_id AND (lower(email) = lower(p_email) OR lower(username) = lower(p_email))
    ) THEN
        RAISE EXCEPTION 'A user with email or username ''%'' already exists', p_email USING ERRCODE = 'CA409';
    END IF;

    UPDATE app_auth.users
       SET name       = coalesce(p_name, name),
           username   = CASE WHEN p_email IS NOT NULL AND lower(username) = lower(email) THEN p_email ELSE username END,
           email      = coalesce(p_email, email),
           role       = coalesce(p_role, role),
           status     = coalesce(p_status, status),
           team_id    = CASE WHEN coalesce(p_clear_team, false) THEN NULL ELSE coalesce(p_team_id, team_id) END,
           updated_at = now()
     WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found.' USING ERRCODE = 'CA404';
    END IF;

    IF p_app_codes IS NOT NULL THEN
        DELETE FROM app_auth.user_applications WHERE user_id = p_user_id;
        INSERT INTO app_auth.user_applications (user_id, application_id)
        SELECT p_user_id, a.id FROM app.applications a WHERE a.code = ANY (p_app_codes);
    END IF;

    SELECT id, username, name, email, role, status, auth_provider, assigned_apps, team_id, team_name
    INTO v_result
    FROM app_auth.vw_user_summary WHERE id = p_user_id;
    RETURN v_result;
END;
$$;

-- Same rule as deploy_schema.sql: functions are not executable by PUBLIC
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_get_by_id(uuid, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_list(text, text, text, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_create(text, text, text, text, text, text, text[], uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION app_auth.usp_user_update(uuid, text, text, text, text[], text, uuid, boolean) FROM PUBLIC;

COMMIT;
