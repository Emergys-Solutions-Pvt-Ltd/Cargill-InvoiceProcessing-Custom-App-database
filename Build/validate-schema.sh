#!/usr/bin/env bash
# =====================================================================================================
# validate-schema.sh - prove the built schema is correct on a clean, disposable PostgreSQL.
#
#   BUILD_DB_HOST=... BUILD_DB_USER=... BUILD_DB_PASSWORD=... Build/validate-schema.sh
#
# 1. SQLFluff (postgres dialect, .sqlfluff) on every manifest / pre / post-deployment file
# 2. generated per-app SQL is in sync with its templates (when node is available; CI runs it separately)
# 3. drops and recreates the build database on BUILD_DB_HOST, installs schema.sql + postdeploy.sql in
#    one transaction each (syntax, definitions, dependency order, trigger / index / schema references)
# 4. runs postdeploy.sql a second time (reference data must be idempotent) and the SQL tests (postgres/tests)
# 5. checks every manifest object exists and every index is valid
# 6. compiles the model: pgschema dump of each schema -> Artifacts/model/<schema>/ (canonical desired state)
# 7. round trip: pgschema plan of the model against the database it came from must be empty
# The build database stays: generate-plan.sh uses it as pgschema's plan database.
# Options: SKIP_LINT=true, SKIP_SQL_TESTS=true
# =====================================================================================================
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

bash "$BUILD_DIR/build-schema.sh"   # always rebuild: validation must never use stale artifacts
require_tools psql "$PGSCHEMA_BIN"
require_build_db
tool_versions
results=()
record() { results+=("$1=$2"); }

# ---- 1. lint --------------------------------------------------------------------------------------
if [[ "${SKIP_LINT:-false}" != "true" ]]; then
  step "SQLFluff"
  require_tools sqlfluff
  mapfile -t lint_files < <("$PY" -c '
import json, sys
m = json.load(open(sys.argv[1]))
for p in m["predeploy"] + [f["path"] for f in m["files"]] + m["postdeploy"]:
    print(p)' "$ARTIFACTS_DIR/object-manifest.json")
  set +e
  (cd "$ROOT_DIR" && sqlfluff lint --config "$ROOT_DIR/.sqlfluff" --format json --nofail "${lint_files[@]}") \
    > "$ARTIFACTS_DIR/lint-report.json" 2>>"$LOG_FILE"
  set -e
  lint_summary=$("$PY" - "$ARTIFACTS_DIR/lint-report.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
v = [(f["filepath"], x["start_line_no"] if "start_line_no" in x else x.get("line_no"), x["code"], x["description"])
     for f in d for x in f["violations"]]
for p, line, code, desc in v[:200]:
    print("LINT %s:%s %s %s" % (p, line, code, desc), file=sys.stderr)
print(len(v))
EOF
  )
  if [[ "$lint_summary" != "0" ]]; then
    record lint failed
    die "$EXIT_VALIDATION" "SQLFluff found $lint_summary violation(s) (Artifacts/lint-report.json)"
  fi
  record lint passed
  info "SQLFluff: ${#lint_files[@]} files, no violations"
else
  warn "SQLFluff skipped (SKIP_LINT=true)"; record lint skipped
fi

# ---- 2. generated SQL in sync ------------------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  node "$ROOT_DIR/$SOURCE_DIR/tools/generate-app-invoice-sql.cjs" --check \
    || die "$EXIT_VALIDATION" "generated per-app invoice SQL is out of date: run node postgres/tools/generate-app-invoice-sql.cjs"
  record generator_check passed
else
  warn "node not available: generator drift check skipped here (the pipeline runs it in its own step)"
  record generator_check skipped
fi

# ---- 3. clean install --------------------------------------------------------------------------------
step "install on a clean database ${BUILD_DB_NAME} @ ${BUILD_DB_HOST}"
wait_for psql_build_admin "build server"
psql_build_admin -c "DROP DATABASE IF EXISTS \"${BUILD_DB_NAME}\" WITH (FORCE)" >/dev/null
psql_build_admin -c "CREATE DATABASE \"${BUILD_DB_NAME}\"" >/dev/null
BUILD_VERSION=$(psql_build -Atc "SELECT current_setting('server_version')")
[[ "${BUILD_VERSION%%.*}" == "$POSTGRES_MAJOR" ]] || warn "build server is PostgreSQL $BUILD_VERSION, project targets $POSTGRES_MAJOR"
psql_build -1 -f "$ARTIFACTS_DIR/schema.sql" > >(redact >>"$LOG_FILE") 2>&1 \
  || die "$EXIT_VALIDATION" "schema.sql failed to install on a clean database (details in $LOG_FILE)"
psql_build -1 -f "$ARTIFACTS_DIR/postdeploy.sql" >>"$LOG_FILE" 2>&1 \
  || die "$EXIT_VALIDATION" "postdeploy.sql failed on a clean database"
psql_build -1 -f "$ARTIFACTS_DIR/postdeploy.sql" >>"$LOG_FILE" 2>&1 \
  || die "$EXIT_VALIDATION" "postdeploy.sql is not idempotent (second run failed)"
record clean_install passed
info "installed on PostgreSQL $BUILD_VERSION"

# ---- 4. SQL tests ------------------------------------------------------------------------------------
if [[ "${SKIP_SQL_TESTS:-false}" != "true" ]]; then
  if [[ -n "${SQL_TEST_SEED:-}" ]]; then
    psql_build -1 -f "$ROOT_DIR/$SQL_TEST_SEED" >>"$LOG_FILE" 2>&1 || die "$EXIT_VALIDATION" "test seed $SQL_TEST_SEED failed (details in $LOG_FILE)"
    info "test seed loaded into the build database: $SQL_TEST_SEED"
  fi
  for t in "$ROOT_DIR/$SQL_TEST_DIR"/test_*.sql; do
    [[ -f "$t" ]] || continue
    psql_build -f "$t" >>"$LOG_FILE" 2>&1 || die "$EXIT_VALIDATION" "SQL test failed: ${t#$ROOT_DIR/} (details in $LOG_FILE)"
    info "SQL test passed: ${t#$ROOT_DIR/}"
  done
  record sql_tests passed
else
  record sql_tests skipped
fi

# ---- 5. objects present, indexes valid -------------------------------------------------------------
"$PY" "$BUILD_DIR/lib/dbproject.py" expected-sql --manifest-json "$ARTIFACTS_DIR/object-manifest.json" > "$ARTIFACTS_DIR/.expected.sql"
missing=$(psql_build -At -f "$ARTIFACTS_DIR/.expected.sql")
[[ -z "$missing" ]] || die "$EXIT_VALIDATION" "objects missing after install: $(echo "$missing" | tr '\n' ' ')"
invalid=$(psql_build -Atc "SELECT string_agg(n.nspname||'.'||c.relname, ', ') FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
                           JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT i.indisvalid")
[[ -z "$invalid" ]] || die "$EXIT_VALIDATION" "invalid indexes: $invalid"
record catalog_check passed

# ---- 6. compile the model ----------------------------------------------------------------------------
step "compile model (pgschema dump)"
rm -rf "$ARTIFACTS_DIR/model"
for s in $MANAGED_SCHEMAS; do
  pgschema_build dump --schema "$s" --multi-file --file "$ARTIFACTS_DIR/model/$s/main.sql" > >(redact >>"$LOG_FILE") 2>&1 \
    || die "$EXIT_VALIDATION" "pgschema dump of schema $s failed"
done
record model_compiled passed

# ---- 7. round trip -----------------------------------------------------------------------------------
step "round trip (model vs. build database must be identical)"
for s in $MANAGED_SCHEMAS; do
  out=$(pgschema_build plan --no-color --schema "$s" --file "$ARTIFACTS_DIR/model/$s/main.sql" --output-human stdout 2>&1 | redact) \
    || { echo "$out" >>"$LOG_FILE"; die "$EXIT_VALIDATION" "pgschema cannot plan schema $s from its own model: $(echo "$out" | tail -2)"; }
  if ! grep -q "No changes detected" <<<"$out"; then
    echo "$out" >>"$LOG_FILE"
    die "$EXIT_VALIDATION" "schema $s does not round-trip through pgschema (an object type it cannot reproduce?): see $LOG_FILE"
  fi
  info "round trip ok: $s"
done
record round_trip passed

"$PY" - "$ARTIFACTS_DIR/validation-report.json" "$BUILD_VERSION" "${results[@]}" <<'EOF'
import json, sys, datetime
out, version, *pairs = sys.argv[1:]
json.dump({"status": "succeeded", "postgres_version": version,
           "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "checks": dict(p.split("=", 1) for p in pairs)}, open(out, "w"), indent=2)
EOF
info "validation succeeded"
