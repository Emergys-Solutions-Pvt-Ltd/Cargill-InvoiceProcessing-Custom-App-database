#!/usr/bin/env bash
# =====================================================================================================
# deploy.sh - plan / validate / apply / verify a database deployment.
#
#   Build/deploy.sh <mode> [env]        mode: plan | validate | apply | verify | predeploy
#
# Inputs (environment):
#   DEPLOY_ENV                 dev | uat | prod | local   (policy: config/environments/<env>.env)
#   DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD [DB_SSLMODE] [DB_SCHEMA]      target (secrets)
#   BUILD_DB_HOST BUILD_DB_PORT BUILD_DB_USER BUILD_DB_PASSWORD                disposable build/plan server
#   APPROVED_PLAN_DIGEST       digest of the reviewed plan (required where REQUIRE_PLAN_APPROVAL=true)
#   ALLOW_DESTRUCTIVE=true     required when the plan drops tables / columns / routines / ...
#
#   plan      generate-plan.sh (read-only on the target)
#   validate  plan artifacts intact, made for this environment and pgschema version, approval policy met
#   apply     validate, then: pre-deployment -> bootstrap (schema.sql) or `pgschema apply --plan` per schema
#             in MANAGED_SCHEMAS order -> post-deployment -> verify. The plan files applied are the ones the
#             digest was computed from; pgschema refuses a plan whose target fingerprint changed.
#   verify    verify.sh
#   predeploy only the idempotent pre-deployment script (create new schemas)
# Always writes Artifacts/deployment-report.{json,md}.
# =====================================================================================================
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODE="${1:-}"; ENV_ARG="${2:-}"
[[ "$MODE" =~ ^(plan|validate|apply|verify|predeploy)$ ]] || die "$EXIT_USAGE" "usage: Build/deploy.sh plan|validate|apply|verify|predeploy [env]"
load_environment "$ENV_ARG"
git_info
STATUS=failed
RUN_START="$(_ts)"
ERRORS_FILE="$LOG_DIR/deploy-errors.log"; : > "$ERRORS_FILE"
ALLOW_DESTRUCTIVE="${ALLOW_DESTRUCTIVE:-${DEPLOYMENT_PARAMETER_ALLOW_DESTRUCTIVE:-${ALLOW_DESTRUCTIVE_DEFAULT:-false}}}"
APPROVED_PLAN_DIGEST="${APPROVED_PLAN_DIGEST:-${DEPLOYMENT_PARAMETER_APPROVED_PLAN_DIGEST:-}}"

finish() {
  local rc=$?
  trap - EXIT ERR
  [[ $rc -eq 0 ]] && STATUS="${STATUS/failed/succeeded}"
  # errors of this run only (logs keep earlier runs): ISO timestamps compare as strings
  [[ $rc -ne 0 ]] && cat "$LOG_DIR"/*.log 2>/dev/null | awk -v s="[$RUN_START]" '$1 >= s && /\[ERROR\]/'     | grep -v 'failed with exit code' | sed 's/^.*\[ERROR\] //' | sort -u > "$ERRORS_FILE" || true
  "$PY" "$BUILD_DIR/lib/dbproject.py" report --artifacts "$ARTIFACTS_DIR" --environment "$DEPLOY_ENV" --mode "$MODE" \
    --status "$( [[ $rc -eq 0 ]] && echo "$STATUS" || echo failed)" --repo "${REPO_NAME:-}" --branch "${GIT_BRANCH:-}" \
    --commit "${GIT_COMMIT:-}" --server-version "${TARGET_VERSION:-}" --errors-file "$ERRORS_FILE" || true
  info "report: Artifacts/deployment-report.md (status: $( [[ $rc -eq 0 ]] && echo "$STATUS" || echo failed), exit $rc)"
  exit $rc
}
trap finish EXIT

check_plan() {
  [[ -f "$ARTIFACTS_DIR/deployment-plan.json" ]] || die "$EXIT_USAGE" "no deployment plan: run 'Build/deploy.sh plan' first"
  local args=(check --artifacts "$ARTIFACTS_DIR" --environment "$DEPLOY_ENV" --pgschema-version "$(pgschema_version)")
  [[ -n "$APPROVED_PLAN_DIGEST" ]] && args+=(--approved-digest "$APPROVED_PLAN_DIGEST")
  [[ "${REQUIRE_PLAN_APPROVAL:-false}" == "true" ]] && args+=(--require-approval)
  [[ "$ALLOW_DESTRUCTIVE" == "true" ]] && args+=(--allow-destructive)
  local rc=0   # "|| rc=" keeps the ERR trap quiet: a rejected plan is an expected outcome
  "$PY" "$BUILD_DIR/lib/dbproject.py" "${args[@]}" 2> >(tee -a "$LOG_FILE" >&2) || rc=$?
  [[ $rc -eq 0 ]] || { err "plan rejected by the deployment policy (exit $rc)"; exit "$rc"; }
}

plan_field() { "$PY" -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$ARTIFACTS_DIR/deployment-plan.json" "$1"; }

run_sql_file() {  # run_sql_file <file> <label>   (one transaction)
  local f="$1" label="$2"
  info "running $label"
  psql_target -1 -f "$f" > >(redact >>"$LOG_DIR/apply.log") 2>&1 || die "$EXIT_ERROR" "$label failed (Artifacts/logs/apply.log)"
}

apply_plan() {
  check_target_connection
  check_plan
  require_tools "$PGSCHEMA_BIN"
  local mode; mode=$(plan_field mode)
  : > "$LOG_DIR/apply.log"
  if [[ "$mode" == bootstrap ]]; then
    local n; n=$(psql_target -Atc "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                                   WHERE n.nspname IN ('$(echo "$MANAGED_SCHEMAS" | sed "s/ /','/g")')")
    [[ "$n" == "0" ]] || die "$EXIT_VALIDATION" "bootstrap plan, but the target is no longer empty ($n relations): plan again"
    step "bootstrap: installing schema.sql in one transaction"
    run_sql_file "$ARTIFACTS_DIR/schema.sql" "schema.sql (bootstrap)"
  else
    run_sql_file "$ARTIFACTS_DIR/predeploy.sql" "pre-deployment"
    local s status
    while IFS='|' read -r s status; do
      if [[ "$status" != changes ]]; then info "schema $s: no changes"; continue; fi
      step "apply schema $s (plans/$s.json)"
      if ! pgschema_target apply --no-color --schema "$s" --plan "$ARTIFACTS_DIR/plans/$s.json" --auto-approve \
             --lock-timeout "${LOCK_TIMEOUT:-30s}" --application-name "dbproject-deploy" \
             > >(redact | tee -a "$LOG_DIR/apply.log" | sed 's/^/    /' >&2) 2>&1; then
        die "$EXIT_ERROR" "pgschema apply failed for schema $s. Schemas before it in '$MANAGED_SCHEMAS' are already applied; failed transactional groups were rolled back (see Artifacts/logs/apply.log)"
      fi
    done < <("$PY" -c 'import json,sys
for s in json.load(open(sys.argv[1]))["schemas"]: print("%s|%s" % (s["schema"], s["status"]))' "$ARTIFACTS_DIR/deployment-plan.json")
  fi
  run_sql_file "$ARTIFACTS_DIR/postdeploy.sql" "post-deployment (reference data)"
  STATUS=succeeded
}

case "$MODE" in
  plan)
    bash "$BUILD_DIR/generate-plan.sh"
    STATUS=planned ;;
  validate)
    check_target_connection
    check_plan
    STATUS=validated ;;
  apply)
    apply_plan
    step "post-deployment verification"
    bash "$BUILD_DIR/verify.sh" || die "$EXIT_VALIDATION" "post-deployment verification failed (Artifacts/verify-report.json)"
    STATUS=succeeded ;;
  verify)
    bash "$BUILD_DIR/verify.sh"
    STATUS=verified ;;
  predeploy)
    check_target_connection
    [[ -f "$ARTIFACTS_DIR/predeploy.sql" ]] || bash "$BUILD_DIR/build-schema.sh"
    run_sql_file "$ARTIFACTS_DIR/predeploy.sql" "pre-deployment"
    STATUS=succeeded ;;
esac
