#!/usr/bin/env bash
# =====================================================================================================
# verify.sh - post-deployment verification of a target database.
#
#   DEPLOY_ENV=... DB_HOST=... DB_NAME=... DB_USER=... DB_PASSWORD=... Build/verify.sh
#
# Checks: connectivity and server version; every object of object-manifest.json exists (tables, views,
# types, functions/procedures, triggers enabled, indexes valid); no invalid index in a managed schema;
# every function definition can be read back; reference data present; and - when the model and the build
# database are available - no drift: pgschema plan of the model against the target is empty.
# Writes Artifacts/verify-report.json. Exit 5 when a check fails.
# =====================================================================================================
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

load_environment "${1:-}"
require_tools psql
check_target_connection
[[ -f "$ARTIFACTS_DIR/object-manifest.json" ]] || bash "$BUILD_DIR/build-schema.sh"
mapfile -t SCHEMAS < <(schemas | tr ' ' '\n' | grep -v '^$')
schema_list="'$(IFS=,; echo "${SCHEMAS[*]}" | sed "s/,/','/g")'"
failures=()

step "verify ${DB_NAME} (${SCHEMAS[*]})"
"$PY" "$BUILD_DIR/lib/dbproject.py" expected-sql --manifest-json "$ARTIFACTS_DIR/object-manifest.json" > "$ARTIFACTS_DIR/.expected.sql"
missing=$(psql_target -At -f "$ARTIFACTS_DIR/.expected.sql" | grep -E " ($(IFS='|'; echo "${SCHEMAS[*]}"))\." || true)
[[ -z "$missing" ]] || failures+=("missing objects: $(echo "$missing" | tr '\n' ',' | sed 's/,$//')")

invalid=$(psql_target -Atc "SELECT coalesce(string_agg(n.nspname||'.'||c.relname, ', '), '') FROM pg_index i
                            JOIN pg_class c ON c.oid = i.indexrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                            WHERE n.nspname IN ($schema_list) AND (NOT i.indisvalid OR NOT i.indisready)")
[[ -z "$invalid" ]] || failures+=("invalid indexes: $invalid")

disabled=$(psql_target -Atc "SELECT coalesce(string_agg(n.nspname||'.'||c.relname||'.'||t.tgname, ', '), '') FROM pg_trigger t
                             JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace
                             WHERE NOT t.tgisinternal AND t.tgenabled = 'D' AND n.nspname IN ($schema_list)")
[[ -z "$disabled" ]] || failures+=("disabled triggers: $disabled")

# Every routine definition must be readable (catches broken / half-dropped routines)
routines=$(psql_target -Atc "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                             WHERE n.nspname IN ($schema_list) AND p.prokind IN ('f','p')
                               AND length(pg_get_functiondef(p.oid)) > 0") \
  || failures+=("a function or procedure definition cannot be read")
counts=$(psql_target -Atc "SELECT json_build_object(
          'tables',   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ($schema_list) AND c.relkind IN ('r','p')),
          'views',    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ($schema_list) AND c.relkind IN ('v','m')),
          'indexes',  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ($schema_list) AND c.relkind = 'i'),
          'triggers', (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ($schema_list) AND NOT t.tgisinternal),
          'routines', ${routines:-0})")

if [[ " ${SCHEMAS[*]} " == *" app "* ]]; then
  statuses=$(psql_target -Atc "SELECT count(*) FROM app.statuses WHERE code IN ('Pending','Approved','Processed','Rejected')" 2>/dev/null || echo 0)
  [[ "$statuses" == "4" ]] || failures+=("reference data: core statuses missing ($statuses/4)")
fi

# Drift: the target must now be identical to the model
drift_json="{}"
if [[ -d "$ARTIFACTS_DIR/model" && -n "${BUILD_DB_HOST:-}" && "${SKIP_DRIFT_CHECK:-false}" != "true" ]]; then
  require_build_db
  drift=()
  for s in "${SCHEMAS[@]}"; do
    if ! out=$(pgschema_target plan --no-color --schema "$s" --file "$ARTIFACTS_DIR/model/$s/main.sql" --output-human stdout 2>&1); then
      printf '%s\n' "$out" | redact >>"$LOG_FILE"; failures+=("drift check failed to run for $s"); continue
    fi
    if grep -q "No changes detected" <<<"$out"; then drift+=("\"$s\":false"); else
      drift+=("\"$s\":true"); printf '%s\n' "$out" | redact >>"$LOG_FILE"; failures+=("schema $s differs from the model after deployment (drift)")
    fi
  done
  drift_json="{$(IFS=,; echo "${drift[*]}")}"
else
  warn "drift check skipped (needs Artifacts/model and BUILD_DB_* )"
fi

status=succeeded; ((${#failures[@]} == 0)) || status=failed
"$PY" - "$ARTIFACTS_DIR/verify-report.json" "$status" "$TARGET_VERSION" "$counts" "$drift_json" "${failures[@]}" <<'EOF'
import json, sys
out, status, version, counts, drift, *failures = sys.argv[1:]
missing = [x.strip() for f in failures if f.startswith("missing objects: ") for x in f[17:].split(",") if x.strip()]
json.dump({"status": status, "postgres_version": version, "connectivity": "ok", "object_counts": json.loads(counts),
           "drift": json.loads(drift), "missing_objects": missing, "failures": failures}, open(out, "w"), indent=2)
EOF
if [[ "$status" != succeeded ]]; then
  for f in "${failures[@]}"; do err "$f"; done
  exit "$EXIT_VALIDATION"
fi
info "verification succeeded: $counts"
