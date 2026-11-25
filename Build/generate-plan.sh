#!/usr/bin/env bash
# =====================================================================================================
# generate-plan.sh - compare a target database with the compiled model and write the deployment plan.
#
#   DEPLOY_ENV=dev DB_HOST=... DB_PORT=5432 DB_NAME=... DB_USER=... DB_PASSWORD=... [DB_SCHEMA=app,gpp] \
#   BUILD_DB_HOST=... BUILD_DB_USER=... BUILD_DB_PASSWORD=... Build/generate-plan.sh
#
# Needs Artifacts/model (validate-schema.sh) and the build database (pgschema's plan database: it holds
# every schema, so cross-schema references resolve). Read-only on the target.
#
# Modes
#   bootstrap    no managed schema on the target holds any object: deployment = schema.sql (one transaction)
#   incremental  pgschema plan per schema (config MANAGED_SCHEMAS order): one comparison produces both
#                plans/<schema>.json (applied as-is by deploy.sh) and plans/<schema>.sql (preview)
# Outputs: deployment-plan.json (bundle + digest), deployment.sql (preview), deployment-summary.json,
#          destructive-changes.json, plans/<schema>.{json,sql,txt}, plan-digest.txt
# The digest covers the exact SQL steps, the target fingerprints and the build artifacts, but no
# timestamps: re-planning an unchanged source against an unchanged target gives the same digest.
# =====================================================================================================
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_environment "${1:-}"
require_tools psql "$PGSCHEMA_BIN"
require_build_db
check_target_connection
git_info
tool_versions
[[ -d "$ARTIFACTS_DIR/model" ]] || die "$EXIT_USAGE" "Artifacts/model is missing: run Build/validate-schema.sh first"
wait_for psql_build "build (plan)"

mapfile -t SCHEMAS < <(schemas | tr ' ' '\n' | grep -v '^$')
for s in "${SCHEMAS[@]}"; do
  [[ " $MANAGED_SCHEMAS " == *" $s "* ]] || die "$EXIT_USAGE" "DB_SCHEMA contains '$s', which is not a managed schema ($MANAGED_SCHEMAS)"
done
schema_list="'$(IFS=,; echo "${SCHEMAS[*]}" | sed "s/,/','/g")'"
all_list="'$(echo "$MANAGED_SCHEMAS" | sed "s/ /','/g")'"

# ---- mode -------------------------------------------------------------------------------------------
populated=$(psql_target -Atc "
  SELECT count(*) FROM pg_namespace n
  WHERE n.nspname IN ($all_list)
    AND (EXISTS (SELECT 1 FROM pg_class c WHERE c.relnamespace = n.oid)
      OR EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = n.oid)
      OR EXISTS (SELECT 1 FROM pg_type t WHERE t.typnamespace = n.oid AND t.typtype IN ('c','e','d') AND t.typrelid = 0))")
missing=$(psql_target -Atc "SELECT string_agg(s, ' ') FROM unnest(ARRAY[$schema_list]) s
                            WHERE NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = s)")
MODE=incremental
[[ "$populated" == "0" ]] && MODE=bootstrap
if [[ "$MODE" == incremental && -n "$missing" ]]; then
  die "$EXIT_VALIDATION" "schema(s) $missing do not exist on the target. New schemas are created by the pre-deployment " \
      "script: add them to postgres/predeploy/00_schemas.sql and run 'Build/deploy.sh predeploy' once, then plan again."
fi
step "plan: env=$DEPLOY_ENV mode=$MODE schemas=${SCHEMAS[*]}"

rm -rf "$ARTIFACTS_DIR/plans"; mkdir -p "$ARTIFACTS_DIR/plans"
rm -f "$ARTIFACTS_DIR"/{deployment-plan,deployment-summary,destructive-changes}.json "$ARTIFACTS_DIR"/deployment.sql

if [[ "$MODE" == incremental ]]; then
  for s in "${SCHEMAS[@]}"; do
    info "comparing schema $s"
    if ! out=$(pgschema_target plan --no-color --schema "$s" --file "$ARTIFACTS_DIR/model/$s/main.sql" \
                 --output-json "$ARTIFACTS_DIR/plans/$s.json" --output-sql "$ARTIFACTS_DIR/plans/$s.sql" \
                 --output-human "$ARTIFACTS_DIR/plans/$s.txt" 2>&1); then
      printf '%s\n' "$out" | redact >>"$LOG_FILE"
      die "$EXIT_ERROR" "schema comparison failed for $s: $(printf '%s' "$out" | redact | tail -3)"
    fi
    [[ -s "$ARTIFACTS_DIR/plans/$s.json" ]] || die "$EXIT_ERROR" "pgschema wrote no plan for $s"
    redact < "$ARTIFACTS_DIR/plans/$s.txt" | sed 's/^/    /' >&2
  done
fi

DIGEST=$("$PY" "$BUILD_DIR/lib/dbproject.py" bundle --artifacts "$ARTIFACTS_DIR" --schemas "${SCHEMAS[*]}" \
          --environment "$DEPLOY_ENV" --mode "$MODE" --target-db "$DB_NAME" --target-host "$DB_HOST" \
          --server-version "$TARGET_VERSION" --repo "${REPO_NAME:-}" --branch "${GIT_BRANCH:-}" \
          --commit "${GIT_COMMIT:-}" 2> >(tee -a "$LOG_FILE" >&2))
echo "$DIGEST" > "$ARTIFACTS_DIR/plan-digest.txt"
"$PY" - "$ARTIFACTS_DIR/deployment-summary.json" <<'EOF' >&2
import json, sys
s = json.load(open(sys.argv[1]))
print("  plan digest      : %s" % s["digest"])
print("  mode / changes   : %s / %s" % (s["mode"], s["has_changes"]))
print("  operations       : %s" % ", ".join("%s=%s" % kv for kv in s["operations"].items() if kv[1]))
print("  destructive      : %s (approval required: %s)" % (s["destructive_changes"], s["approval_required"]))
print("  non-transactional: %s" % s["non_transactional_steps"])
EOF
info "plan written: deployment-plan.json, deployment.sql, deployment-summary.json, destructive-changes.json"
