#!/usr/bin/env bash
# =====================================================================================================
# Shared functions for the Build/*.sh scripts. Source it; do not run it.
#
# Connection variables (never printed):
#   target database      DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD [DB_SSLMODE] [DB_SCHEMA]
#   build / plan server  BUILD_DB_HOST BUILD_DB_PORT BUILD_DB_USER [BUILD_DB_PASSWORD] [BUILD_DB_SSLMODE] [BUILD_DB_NAME]
#     A disposable PostgreSQL server (Vela service / local container). The build database on it is
#     dropped and recreated by validate-schema.sh and used as pgschema's plan database.
# Other inputs: DEPLOY_ENV (dev|uat|prod|local), ARTIFACTS_DIR (default <repo>/Artifacts)
# Exit codes: 0 ok, 1 error, 2 usage/configuration, 3 approval required, 4 connection failure, 5 validation failed
# =====================================================================================================
set -Eeuo pipefail
set +x   # never trace: commands may carry credentials in their environment

readonly EXIT_ERROR=1 EXIT_USAGE=2 EXIT_APPROVAL=3 EXIT_CONNECTION=4 EXIT_VALIDATION=5

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/Artifacts}"
LOG_DIR="$ARTIFACTS_DIR/logs"
PY="${PYTHON:-python3}"
PGSCHEMA_BIN="${PGSCHEMA_BIN:-pgschema}"
SCRIPT_NAME="$(basename "${0:-common.sh}" .sh)"

# shellcheck source=../config/project.conf
source "$ROOT_DIR/config/project.conf"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"

_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()  { printf '[%s] [%s] [%s] %s\n' "$(_ts)" "$SCRIPT_NAME" "$1" "$2" | redact | tee -a "$LOG_FILE" >&2; }
info() { log INFO "$*"; }
warn() { log WARN "$*"; }
err()  { log ERROR "$*"; }
die()  { local code="$1"; shift; err "$*"; exit "$code"; }
step() { log INFO "==== $* ===="; }

# Removes secret values from any text (reads them from the environment, not from argv)
redact() {
  "$PY" -c '
import os, sys
secrets = [os.environ.get(k) for k in ("DB_PASSWORD", "BUILD_DB_PASSWORD", "PGPASSWORD", "PGSCHEMA_PLAN_PASSWORD")]
secrets = sorted({s for s in secrets if s and len(s) >= 4}, key=len, reverse=True)
for line in sys.stdin:
    for s in secrets:
        line = line.replace(s, "********")
    sys.stdout.write(line)
    sys.stdout.flush()
'
}

on_error() {
  local code=$? line=${BASH_LINENO[0]:-?}
  err "failed with exit code $code at line $line (see $LOG_FILE)"
  exit "$code"
}
trap on_error ERR

require_env() {
  local missing=()
  for v in "$@"; do [[ -n "${!v:-}" ]] || missing+=("$v"); done
  ((${#missing[@]} == 0)) || die "$EXIT_USAGE" "missing required environment variable(s): ${missing[*]}"
}

require_tools() {
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || die "$EXIT_USAGE" "required tool not found: $t"; done
}

# Loads config/environments/<env>.env (policy only, no secrets)
load_environment() {
  DEPLOY_ENV="${DEPLOY_ENV:-${1:-}}"
  [[ "$DEPLOY_ENV" =~ ^(dev|uat|prod|local)$ ]] || die "$EXIT_USAGE" "DEPLOY_ENV must be dev, uat, prod or local (got '${DEPLOY_ENV}')"
  local f="$ROOT_DIR/config/environments/$DEPLOY_ENV.env"
  [[ -f "$f" ]] || die "$EXIT_USAGE" "missing $f"
  local k v
  while IFS='=' read -r k v; do
    [[ -z "$k" || "$k" == \#* ]] && continue
    # environment variables set by the pipeline win over the file defaults
    [[ -n "${!k:-}" ]] || export "$k=$v"
  done < <(grep -vE '^\s*(#|$)' "$f")
  export DEPLOY_ENV
}

schemas() { echo "${DB_SCHEMA:-$MANAGED_SCHEMAS}" | tr ',' ' '; }

# ---- connections: credentials are passed through the environment of the single command only ----
_target_env() {
  env PGHOST="$DB_HOST" PGPORT="${DB_PORT:-5432}" PGDATABASE="$DB_NAME" PGUSER="$DB_USER" \
      PGPASSWORD="$DB_PASSWORD" PGSSLMODE="${DB_SSLMODE:-require}" PGAPPNAME="dbproject-${SCRIPT_NAME}" \
      PGCONNECT_TIMEOUT="${DB_CONNECT_TIMEOUT:-15}" "$@"
}
_build_env() {
  local db="${1}"; shift
  env PGHOST="$BUILD_DB_HOST" PGPORT="${BUILD_DB_PORT:-5432}" PGDATABASE="$db" PGUSER="$BUILD_DB_USER" \
      PGPASSWORD="$BUILD_DB_PASSWORD" PGSSLMODE="${BUILD_DB_SSLMODE:-disable}" PGAPPNAME="dbproject-${SCRIPT_NAME}" \
      PGCONNECT_TIMEOUT=15 "$@"
}
psql_target() { _target_env psql -X -q -v ON_ERROR_STOP=1 "$@"; }
psql_build()  { _build_env "${BUILD_DB_NAME:-$BUILD_DB_NAME_DEFAULT}" psql -X -q -v ON_ERROR_STOP=1 "$@"; }
psql_build_admin() { _build_env postgres psql -X -q -v ON_ERROR_STOP=1 "$@"; }

require_target() { require_env DB_HOST DB_NAME DB_USER DB_PASSWORD; }
require_build_db() {
  require_env BUILD_DB_HOST BUILD_DB_USER   # BUILD_DB_PASSWORD may be empty (trust auth on a disposable service)
  BUILD_DB_PASSWORD="${BUILD_DB_PASSWORD:-}"
  BUILD_DB_NAME="${BUILD_DB_NAME:-$BUILD_DB_NAME_DEFAULT}"
  # The build database is dropped and recreated: never let it point at a deployment target
  if [[ -n "${DB_HOST:-}" && "$BUILD_DB_HOST" == "$DB_HOST" && "${BUILD_DB_PORT:-5432}" == "${DB_PORT:-5432}" \
        && "$BUILD_DB_NAME" == "${DB_NAME:-}" ]]; then
    die "$EXIT_USAGE" "the build database must not be the deployment target"
  fi
  [[ "$BUILD_DB_NAME" =~ ^[a-z_][a-z0-9_]*$ ]] || die "$EXIT_USAGE" "invalid BUILD_DB_NAME"
}

wait_for() {  # wait_for <psql function> <label>
  local fn="$1" label="$2" i
  for i in $(seq 1 "${DB_WAIT_SECONDS:-30}"); do
    if "$fn" -Atc 'SELECT 1' >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  die "$EXIT_CONNECTION" "cannot connect to the $label database"
}

check_target_connection() {
  require_target
  local out
  if ! out=$(psql_target -Atc "SELECT current_database() || '|' || current_user || '|' || current_setting('server_version')" 2>&1); then
    err "$(printf '%s' "$out" | redact | tail -1)"
    die "$EXIT_CONNECTION" "cannot connect to target database '${DB_NAME}' on ${DB_HOST}:${DB_PORT:-5432}"
  fi
  IFS='|' read -r TARGET_DB TARGET_USER TARGET_VERSION <<<"$out"
  [[ "$TARGET_DB" == "$DB_NAME" ]] || die "$EXIT_CONNECTION" "connected to '$TARGET_DB', expected '$DB_NAME'"
  export TARGET_VERSION
  info "target: database=$TARGET_DB user=$TARGET_USER postgres=$TARGET_VERSION env=${DEPLOY_ENV:-?}"
  local major="${TARGET_VERSION%%.*}"
  if [[ "$major" != "$POSTGRES_MAJOR" ]]; then
    warn "target runs PostgreSQL $major; the project is built and tested on $POSTGRES_MAJOR"
  fi
}

# ---- pgschema (one schema per call); connection through env vars, never flags with secrets ----
pgschema_target() {
  _target_env env PGSCHEMA_PLAN_HOST="$BUILD_DB_HOST" PGSCHEMA_PLAN_PORT="${BUILD_DB_PORT:-5432}" \
      PGSCHEMA_PLAN_DB="${BUILD_DB_NAME:-$BUILD_DB_NAME_DEFAULT}" PGSCHEMA_PLAN_USER="$BUILD_DB_USER" \
      PGSCHEMA_PLAN_PASSWORD="$BUILD_DB_PASSWORD" PGSCHEMA_PLAN_SSLMODE="${BUILD_DB_SSLMODE:-disable}" \
      "$PGSCHEMA_BIN" "$@"
}
pgschema_build() {  # the build database as both target and plan database (validation round trip)
  _build_env "${BUILD_DB_NAME:-$BUILD_DB_NAME_DEFAULT}" env PGSCHEMA_PLAN_HOST="$BUILD_DB_HOST" \
      PGSCHEMA_PLAN_PORT="${BUILD_DB_PORT:-5432}" PGSCHEMA_PLAN_DB="${BUILD_DB_NAME:-$BUILD_DB_NAME_DEFAULT}" \
      PGSCHEMA_PLAN_USER="$BUILD_DB_USER" PGSCHEMA_PLAN_PASSWORD="$BUILD_DB_PASSWORD" \
      PGSCHEMA_PLAN_SSLMODE="${BUILD_DB_SSLMODE:-disable}" "$PGSCHEMA_BIN" "$@"
}

pgschema_version() { "$PGSCHEMA_BIN" --version 2>/dev/null | head -1 | tr -d 'v[:space:]'; }

tool_versions() {
  local pgs sqlf psqlv
  pgs="$(pgschema_version || true)"
  sqlf="$(sqlfluff --version 2>/dev/null | awk '{print $NF}' || true)"
  psqlv="$(psql --version 2>/dev/null | awk '{print $NF}' || true)"
  "$PY" - "$pgs" "$sqlf" "$psqlv" "$ARTIFACTS_DIR/tool-versions.json" <<'EOF'
import json, platform, sys
pgs, sqlf, psqlv, out = sys.argv[1:5]
json.dump({"pgschema": pgs or None, "sqlfluff": sqlf or None, "psql": psqlv or None,
           "python": platform.python_version()}, open(out, "w"), indent=2)
EOF
  [[ -z "$pgs" || "$pgs" == "$PGSCHEMA_VERSION" ]] || warn "pgschema $pgs found, project tested with $PGSCHEMA_VERSION"
  [[ -z "$sqlf" || "$sqlf" == "$SQLFLUFF_VERSION" ]] || warn "sqlfluff $sqlf found, project tested with $SQLFLUFF_VERSION"
}

# ---- source traceability (Vela variables first, then git) ----
git_info() {
  REPO_NAME="${VELA_REPO_FULL_NAME:-$(git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/.]+)(\.git)?$#\1#' || true)}"
  GIT_BRANCH="${VELA_BUILD_BRANCH:-$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)}"
  GIT_COMMIT="${VELA_BUILD_COMMIT:-$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)}"
  export REPO_NAME GIT_BRANCH GIT_COMMIT
}
