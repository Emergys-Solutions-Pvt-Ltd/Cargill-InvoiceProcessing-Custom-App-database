#!/usr/bin/env bash
# =====================================================================================================
# Deployment scenario tests - run inside the tool image against a disposable PostgreSQL server.
#
#   TEST_PG_HOST=postgres bash tests/deploy/scenarios.sh [scenario-id ...]
#
# The server must accept user "postgres" without a password (trust auth: a throw-away container).
# The repository (current directory) is copied to /tmp/dbtest/proj for every scenario and mutated there;
# the repository itself is never modified. Results: Artifacts/test-results/{results.json,summary.md,*.log}
# =====================================================================================================
set -Euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PGH="${TEST_PG_HOST:-postgres}"
WORK=/tmp/dbtest
P="$WORK/proj"
OUT="$SRC/Artifacts/test-results"
mkdir -p "$OUT" "$WORK"
export BUILD_DB_HOST="$PGH" BUILD_DB_USER=postgres BUILD_DB_PASSWORD="" BUILD_DB_SSLMODE=disable
export DB_HOST="$PGH" DB_PORT=5432 DB_USER=postgres DB_PASSWORD="trust-auth-not-used" DB_SSLMODE=disable
export DEPLOY_ENV=local ARTIFACTS_DIR="$P/Artifacts" SKIP_LINT=true SKIP_SQL_TESTS=true DB_WAIT_SECONDS=60
unset DB_SCHEMA
RESULTS=()
LOG=/dev/null

# ---------------------------------------------------------------------------------------- helpers
say()   { printf '%s\n' "$*" | tee -a "$LOG" >&2; }
fail()  { say "  ASSERTION FAILED: $*"; echo "$*" >> "$WORK/failures"; return 1; }
admin() { psql -X -q -At -h "$PGH" -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"; }
sql()   { local db="$1"; shift; psql -X -q -At -h "$PGH" -U postgres -d "$db" -v ON_ERROR_STOP=1 "$@"; }
dropdb_() { admin -c "DROP DATABASE IF EXISTS \"$1\" WITH (FORCE)" >/dev/null; }
newdb() { dropdb_ "$1"; admin -c "CREATE DATABASE \"$1\"" >/dev/null; }
clone() { dropdb_ "$1"; admin -c "CREATE DATABASE \"$1\" TEMPLATE base_target" >/dev/null; }

project() {   # fresh copy of the repository (without artifacts / git)
  rm -rf "$P"; mkdir -p "$P"
  (cd "$SRC" && tar cf - --exclude=./Artifacts --exclude=./.git .) | (cd "$P" && tar xf -)
}
manifest_add() { printf '\\ir %s\n' "$1" >> "$P/postgres/objects.sql"; }   # append (after every dependency)
edit() {      # edit <file> <python expression on s>
  python3 - "$P/$1" "$2" <<'EOF'
import sys
p, expr = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
n = eval(expr, {"s": s})
assert n != s, "edit changed nothing: " + expr
open(p, "w", encoding="utf-8").write(n)
EOF
}
# run <expected exit> <cmd...>: run a project script and check its exit code
run() {
  local want="$1"; shift
  local rc=0
  (cd "$P" && "$@") >>"$LOG" 2>&1 || rc=$?
  [[ "$rc" == "$want" ]] || { fail "'$*' exited $rc, expected $want"; return 1; }
}
build()  { run 0 bash Build/validate-schema.sh; }
plan()   { local db="$1"; shift; run "${PLAN_RC:-0}" env DB_NAME="$db" "$@" bash Build/deploy.sh plan; }
apply()  { local want="$1" db="$2"; shift 2; run "$want" env DB_NAME="$db" "$@" bash Build/deploy.sh apply; }
summary(){ python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$P/Artifacts/deployment-summary.json" "$1"; }
plan_sql_has()  { grep -qiE "$1" "$P/Artifacts/deployment.sql" || fail "deployment.sql does not contain /$1/"; }
expect() { [[ "$1" == "$2" ]] || fail "${3:-value}: got '$1', expected '$2'"; }

scenario() {
  local id="$1" name="$2" fn="$3" t0 rc=0
  LOG="$OUT/scenario-$id.log"; : > "$LOG"
  say "---- [$id] $name"
  t0=$(date +%s)
  : > "$WORK/failures"
  ( set -e; "$fn" ); rc=$?          # not part of || / &&: set -e stays active inside the scenario
  local status=PASS; [[ $rc -eq 0 && ! -s "$WORK/failures" ]] || status=FAIL
  RESULTS+=("$id|$name|$status|$(( $(date +%s) - t0 ))")
  say "     $status ($(( $(date +%s) - t0 ))s)"
}

# ---------------------------------------------------------------------------------------- scenarios
s01_initial() {           # 1. initial deployment to an empty database (bootstrap)
  project; build
  newdb t_initial
  plan t_initial
  expect "$(summary 'd["mode"]')" bootstrap "plan mode"
  apply 0 t_initial
  expect "$(sql t_initial -c "SELECT count(*) FROM pg_tables WHERE schemaname IN ('app','app_auth','gpp','sjo','rospbu')")" 41 "tables"
  expect "$(sql t_initial -c "SELECT count(*) FROM app.statuses")" 4 "reference data"
  grep -q '"status": "succeeded"' "$P/Artifacts/verify-report.json" || fail "verification did not succeed"
  dropdb_ base_target
  admin -c 'CREATE DATABASE base_target TEMPLATE t_initial' >/dev/null
}

s15_repeat() {            # 15. repeated deployment with no schema changes
  project; build
  plan t_initial
  expect "$(summary 'd["has_changes"]')" False "changes on an up-to-date target"
  local d1 d2; d1=$(cat "$P/Artifacts/plan-digest.txt")
  plan t_initial; d2=$(cat "$P/Artifacts/plan-digest.txt")
  expect "$d2" "$d1" "plan digest of two identical plans (determinism)"
  apply 0 t_initial
  grep -q "apply schema" "$P/Artifacts/logs/deploy.log" && fail "pgschema apply ran although nothing changed"
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(1 if r["objects_created"] or r["objects_modified"] or r["objects_deleted"] else 0)' \
    "$P/Artifacts/deployment-report.json" || fail "the report lists changes"
}

add_demo_table() {
  cat > "$P/postgres/common/master-data/tables/21_demo_regions.sql" <<'EOF'
-- app.demo_regions - scenario test table
CREATE TABLE IF NOT EXISTS app.demo_regions (
    id          uuid DEFAULT gen_random_uuid() CONSTRAINT pk_demo_regions PRIMARY KEY,
    code        varchar(10)     NOT NULL,
    country_id  uuid            NULL CONSTRAINT fk_demo_regions_country REFERENCES app.countries (id)
);
CREATE INDEX IF NOT EXISTS ix_demo_regions_country ON app.demo_regions (country_id);
EOF
  manifest_add common/master-data/tables/21_demo_regions.sql
}

s02_add_table() {         # 2. adding a new table
  project; add_demo_table; build
  clone t_add_table
  plan t_add_table DB_SCHEMA=app
  expect "$(summary 'd["by_type"].get("table:create", 0)')" 1 "tables created"
  expect "$(summary 'd["destructive_changes"]')" 0 "destructive changes"
  apply 0 t_add_table DB_SCHEMA=app
  expect "$(sql t_add_table -c "SELECT to_regclass('app.demo_regions') IS NOT NULL")" t "table exists"
}

s03_add_column() {        # 3. adding a new column
  project
  edit postgres/sjo/tables/30_erp_systems.sql 's.replace("    is_active   boolean         NOT NULL DEFAULT true,\n", "    is_active   boolean         NOT NULL DEFAULT true,\n    region      varchar(30)     NULL,\n", 1)'
  build; clone t_add_column
  plan t_add_column DB_SCHEMA=sjo
  plan_sql_has 'ADD COLUMN region'
  expect "$(summary 'd["destructive_changes"]')" 0 "destructive changes"
  apply 0 t_add_column DB_SCHEMA=sjo
  expect "$(sql t_add_column -c "SELECT count(*) FROM information_schema.columns WHERE table_schema='sjo' AND table_name='erp_systems' AND column_name='region'")" 1 "column exists"
}

s04_modify_view() {       # 4. modifying an existing view (dependency-aware replacement)
  project
  edit postgres/auth/views/vw_user_summary.sql 's.replace("    u.password_hash\nFROM", "    u.password_hash,\n    u.created_at AS user_created_at\nFROM", 1)'
  build; clone t_view
  plan t_view DB_SCHEMA=app_auth
  plan_sql_has 'vw_user_summary'
  apply 0 t_view DB_SCHEMA=app_auth
  expect "$(sql t_view -c "SELECT count(*) FROM information_schema.columns WHERE table_schema='app_auth' AND table_name='vw_user_summary' AND column_name='user_created_at'")" 1 "view column"
}

s05_modify_function() {   # 5. modifying a function
  project
  edit postgres/common/apps/procedures/usp_application_list.sql 's.replace("ORDER BY a.id;", "ORDER BY a.id, a.code;  -- scenario 5", 1)'
  build; clone t_function
  plan t_function DB_SCHEMA=app
  plan_sql_has 'CREATE OR REPLACE FUNCTION usp_application_list'
  expect "$(summary 'd["destructive_changes"]')" 0 "destructive changes"
  apply 0 t_function DB_SCHEMA=app
  expect "$(sql t_function -c "SELECT position('scenario 5' in pg_get_functiondef('app.usp_application_list(text[],boolean)'::regprocedure)) > 0")" t "new body"
}

add_procedure() {
  mkdir -p "$P/postgres/procedures/demo"
  cat > "$P/postgres/procedures/demo/usp_demo_cleanup.sql" <<EOF
-- app.usp_demo_cleanup - scenario test procedure
CREATE OR REPLACE PROCEDURE app.usp_demo_cleanup(p_days integer)
LANGUAGE plpgsql
AS \$\$
BEGIN
    RAISE NOTICE 'cleanup $1 %', p_days;
END;
\$\$;
EOF
}
s06_modify_procedure() {  # 6. creating, then modifying a procedure
  project; add_procedure v1; manifest_add procedures/demo/usp_demo_cleanup.sql; build; clone t_procedure
  plan t_procedure DB_SCHEMA=app; plan_sql_has 'CREATE OR REPLACE PROCEDURE usp_demo_cleanup'
  apply 0 t_procedure DB_SCHEMA=app
  add_procedure v2; build
  plan t_procedure DB_SCHEMA=app; plan_sql_has "cleanup v2"
  apply 0 t_procedure DB_SCHEMA=app
  expect "$(sql t_procedure -c "SELECT prosrc LIKE '%cleanup v2%' FROM pg_proc WHERE proname='usp_demo_cleanup' AND prokind='p'")" t "procedure body"
}

s07_trigger() {           # 7. creating a trigger
  project; mkdir -p "$P/postgres/common/master-data/triggers"
  cat > "$P/postgres/common/master-data/triggers/trg_teams_updated_at.sql" <<'EOF'
-- Keeps app.teams.updated_at current
CREATE OR REPLACE FUNCTION app.ufn_teams_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_teams_updated_at BEFORE UPDATE ON app.teams
    FOR EACH ROW EXECUTE FUNCTION app.ufn_teams_touch_updated_at();
EOF
  manifest_add common/master-data/triggers/trg_teams_updated_at.sql
  build; clone t_trigger
  plan t_trigger DB_SCHEMA=app; plan_sql_has 'CREATE (OR REPLACE )?TRIGGER trg_teams_updated_at'
  apply 0 t_trigger DB_SCHEMA=app
  sql t_trigger -c "INSERT INTO app.teams (name, updated_at) VALUES ('Scenario team', '2000-01-01'); UPDATE app.teams SET description = 'x' WHERE name = 'Scenario team'" >/dev/null
  expect "$(sql t_trigger -c "SELECT updated_at > '2001-01-01' FROM app.teams WHERE name = 'Scenario team'")" t "trigger fired"
}

s08_index() {             # 8. adding an index (online: CREATE INDEX CONCURRENTLY, outside a transaction)
  project
  edit postgres/common/master-data/tables/18_statuses.sql 's + "CREATE INDEX IF NOT EXISTS ix_statuses_sort ON app.statuses (sort_order);\n"'
  build; clone t_index
  plan t_index DB_SCHEMA=app
  plan_sql_has 'CREATE INDEX CONCURRENTLY'
  [[ "$(summary 'd["non_transactional_steps"]')" -ge 1 ]] || fail "index step not reported as non-transactional"
  apply 0 t_index DB_SCHEMA=app
  expect "$(sql t_index -c "SELECT indisvalid FROM pg_index WHERE indexrelid = 'app.ix_statuses_sort'::regclass")" t "valid index"
}

s09_drop_object() {       # 9. dropping an object: blocked without approval, applied with it
  project; add_demo_table; build; clone t_drop
  apply_ok() { plan t_drop DB_SCHEMA=app; apply 0 t_drop DB_SCHEMA=app; }
  apply_ok
  project; build                                  # demo_regions removed from the project
  plan t_drop DB_SCHEMA=app
  expect "$(summary 'd["approval_required"]')" True "approval required"
  grep -q '"category": "data_loss"' "$P/Artifacts/destructive-changes.json" || fail "drop not classified as data_loss"
  apply 3 t_drop DB_SCHEMA=app
  expect "$(sql t_drop -c "SELECT to_regclass('app.demo_regions') IS NOT NULL")" t "table kept without approval"
  apply 0 t_drop DB_SCHEMA=app ALLOW_DESTRUCTIVE=true
  expect "$(sql t_drop -c "SELECT to_regclass('app.demo_regions') IS NULL")" t "table dropped after approval"
}

s10_rename_column() {     # 10. renaming a column: the diff is drop + add (blocked); done as a manual migration
  project
  edit postgres/sjo/tables/30_erp_systems.sql 's.replace("    description varchar(500)", "    details     varchar(500)", 1)'
  build; clone t_rename
  sql t_rename -c "INSERT INTO sjo.erp_systems (code, name, description) VALUES ('X1', 'Scenario ERP', 'keep me')" >/dev/null
  plan t_rename DB_SCHEMA=sjo
  grep -q '"path": "sjo.erp_systems.description"' "$P/Artifacts/destructive-changes.json" || fail "rename not flagged as a drop"
  apply 3 t_rename DB_SCHEMA=sjo
  # manual migration (ManualMigrations/Schema): ALTER TABLE ... RENAME COLUMN keeps the data
  sql t_rename -c "ALTER TABLE sjo.erp_systems RENAME COLUMN description TO details" >/dev/null
  plan t_rename DB_SCHEMA=sjo
  expect "$(summary 'd["has_changes"]')" False "changes after the manual rename"
  expect "$(sql t_rename -c "SELECT details FROM sjo.erp_systems WHERE code = 'X1'")" "keep me" "data preserved"
}

s11_dependencies() {      # 11. dependency handling: missing / mis-ordered / unlisted / duplicate objects
  project
  printf 'CREATE TABLE IF NOT EXISTS app.demo_orphan (id uuid PRIMARY KEY, x uuid REFERENCES app.not_there (id));\n' \
    > "$P/postgres/tables/90_demo_orphan.sql"; manifest_add tables/90_demo_orphan.sql
  run 5 bash Build/build-schema.sh
  grep -q "missing dependency" "$P/Artifacts/build-report.json" || fail "missing dependency not reported"
  project   # countries listed after states (which references it)
  edit postgres/objects.sql 's.replace("\\ir common/master-data/tables/14_countries.sql\n", "", 1).replace("\\ir common/master-data/tables/15_states.sql\n", "\\ir common/master-data/tables/15_states.sql\n\\ir common/master-data/tables/14_countries.sql\n", 1)'
  run 5 bash Build/build-schema.sh
  grep -q "defined later" "$P/Artifacts/build-report.json" || fail "ordering problem not reported"
  project; printf 'CREATE TABLE IF NOT EXISTS app.demo_unlisted (id uuid PRIMARY KEY);\n' > "$P/postgres/tables/91_unlisted.sql"
  run 5 bash Build/build-schema.sh
  grep -q "is not listed" "$P/Artifacts/build-report.json" || fail "unlisted file not reported"
  project; printf 'CREATE TABLE IF NOT EXISTS app.teams (id uuid PRIMARY KEY);\n' > "$P/postgres/tables/92_dup.sql"; manifest_add tables/92_dup.sql
  run 5 bash Build/build-schema.sh
  grep -q "duplicate definition" "$P/Artifacts/build-report.json" || fail "duplicate not reported"
  project; add_demo_table; build      # a valid cross-file dependency (FK to app.countries) builds and installs
}

s12_invalid_sql() {       # 12. invalid SQL: SQLFluff and the clean install both reject it
  project
  edit postgres/common/master-data/tables/19_processes.sql 's.replace("CREATE TABLE IF NOT EXISTS app.processes (", "CREATE TABLE IF NOT EXISTS app.processes (\n    broken_column  ,", 1)'
  run 5 env SKIP_LINT=false bash Build/validate-schema.sh
  grep -q '"code": "PRS"' "$P/Artifacts/lint-report.json" || fail "SQLFluff did not report the parse error"
  run 5 bash Build/validate-schema.sh                 # without lint: the clean install fails
  grep -q "schema.sql failed to install" "$P/Artifacts/logs/validate-schema.log" || fail "install failure not reported"
}

s13_connection_failure() {  # 13. database connection failure
  project; build
  run 4 env DB_HOST=no-such-host.invalid DB_NAME=t_initial bash Build/deploy.sh plan
  run 4 env DB_NAME=no_such_database bash Build/deploy.sh plan
  grep -q "trust-auth-not-used" "$P"/Artifacts/logs/*.log && fail "password printed in a log"
  return 0
}

s14_deployment_failure() {  # 14. deployment failure: rolled back, reported, exit code != 0
  project   # a type change the target cannot convert (integer -> date): fine on a clean build, fails on apply
  edit postgres/common/master-data/tables/19_processes.sql 's.replace("    sort_order  integer         NOT NULL DEFAULT 0,", "    sort_order  date            NULL,", 1)'
  build; clone t_fail
  sql t_fail -c "INSERT INTO app.processes (code, name, sort_order) VALUES ('P1', 'Scenario process', 7)" >/dev/null
  plan t_fail DB_SCHEMA=app
  grep -q '"category": "review"' "$P/Artifacts/destructive-changes.json" || fail "type change not flagged for review"
  apply 1 t_fail DB_SCHEMA=app
  grep -q '"status": "failed"' "$P/Artifacts/deployment-report.json" || fail "report does not say failed"
  expect "$(sql t_fail -c "SELECT data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='processes' AND column_name='sort_order'")" integer "failed change rolled back"
  expect "$(sql t_fail -c "SELECT sort_order FROM app.processes WHERE code = 'P1'")" 7 "data intact"
}

s16_drift() {             # 16. schema drift between source and target
  project; build; clone t_drift
  sql t_drift -c "ALTER TABLE app.teams ADD COLUMN rogue text; DROP INDEX app.uq_teams_code" >/dev/null
  run 5 env DB_NAME=t_drift DB_SCHEMA=app bash Build/verify.sh
  grep -q '"app": true' "$P/Artifacts/verify-report.json" || fail "drift not detected by verify"
  plan t_drift DB_SCHEMA=app
  grep -q '"path": "app.teams.rogue"' "$P/Artifacts/destructive-changes.json" || fail "drifted column not in the plan"
  plan_sql_has 'uq_teams_code'
  apply 3 t_drift DB_SCHEMA=app                      # removing the rogue column needs approval
}

s17_approval_gate() {     # approval: the reviewed digest must match the plan that is applied (UAT / PROD)
  project
  edit postgres/common/master-data/tables/18_statuses.sql 's + "CREATE INDEX IF NOT EXISTS ix_statuses_sort ON app.statuses (sort_order);\n"'
  build; clone t_approval
  plan t_approval DB_SCHEMA=app
  local digest; digest=$(cat "$P/Artifacts/plan-digest.txt")
  apply 3 t_approval DB_SCHEMA=app REQUIRE_PLAN_APPROVAL=true
  apply 3 t_approval DB_SCHEMA=app REQUIRE_PLAN_APPROVAL=true APPROVED_PLAN_DIGEST=0000deadbeef
  apply 0 t_approval DB_SCHEMA=app REQUIRE_PLAN_APPROVAL=true APPROVED_PLAN_DIGEST="$digest"
}

s18_target_changed() {    # the target changed between plan and apply: pgschema refuses the stale plan
  project
  edit postgres/common/master-data/tables/18_statuses.sql 's + "CREATE INDEX IF NOT EXISTS ix_statuses_sort ON app.statuses (sort_order);\n"'
  build; clone t_stale
  plan t_stale DB_SCHEMA=app
  sql t_stale -c "ALTER TABLE app.countries ADD COLUMN late_change text" >/dev/null
  apply 1 t_stale DB_SCHEMA=app
  grep -qi "fingerprint" "$P/Artifacts/logs/apply.log" "$P/Artifacts/logs/deploy.log" || fail "fingerprint mismatch not reported"
  expect "$(sql t_stale -c "SELECT to_regclass('app.ix_statuses_sort') IS NULL")" t "stale plan not applied"
}

ALL=(
  "01|Initial deployment to an empty database|s01_initial"
  "15|Repeated deployment with no schema changes|s15_repeat"
  "02|Adding a new table|s02_add_table"
  "03|Adding a new column|s03_add_column"
  "04|Modifying an existing view|s04_modify_view"
  "05|Modifying a function|s05_modify_function"
  "06|Modifying a procedure|s06_modify_procedure"
  "07|Creating a trigger|s07_trigger"
  "08|Adding an index|s08_index"
  "09|Dropping an object|s09_drop_object"
  "10|Renaming a column|s10_rename_column"
  "11|Handling dependencies between objects|s11_dependencies"
  "12|Handling invalid SQL|s12_invalid_sql"
  "13|Database connection failure|s13_connection_failure"
  "14|Deployment failure|s14_deployment_failure"
  "16|Schema drift between source and target|s16_drift"
  "17|Approval gate (plan digest)|s17_approval_gate"
  "18|Target changed after the plan was reviewed|s18_target_changed"
)

for i in $(seq 1 60); do admin -c 'SELECT 1' >/dev/null 2>&1 && break; sleep 1; done
for entry in "${ALL[@]}"; do
  IFS='|' read -r id name fn <<<"$entry"
  if (($# > 0)) && [[ " $* " != *" $id "* && " $* " != *" 01 "* ]] && [[ "$id" != 01 ]]; then continue; fi
  scenario "$id" "$name" "$fn"
done

python3 - "$OUT" "${RESULTS[@]}" <<'EOF'
import json, sys
out, *rows = sys.argv[1:]
res = [dict(zip(("id", "scenario", "result", "seconds"), r.split("|"))) for r in rows]
json.dump(res, open(out + "/results.json", "w"), indent=2)
lines = ["| # | Scenario | Result | Time |", "|---|---|---|---|"] + \
        ["| %s | %s | %s | %ss |" % (r["id"], r["scenario"], r["result"], r["seconds"]) for r in res]
passed = sum(r["result"] == "PASS" for r in res)
lines.append("\n%d of %d scenarios passed." % (passed, len(res)))
open(out + "/summary.md", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(0 if passed == len(res) else 1)
EOF
