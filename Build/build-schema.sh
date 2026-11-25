#!/usr/bin/env bash
# =====================================================================================================
# build-schema.sh - assemble the desired database state from the source files (no database needed).
#
#   Build/build-schema.sh
#
# Reads postgres/objects.sql (the ordered object manifest), postgres/predeploy/*.sql and
# postgres/postdeploy/*.sql and writes:
#   Artifacts/schema.sql            complete desired state (pre-deployment + every object, manifest order)
#   Artifacts/predeploy.sql         schemas / default privileges (run before every deployment)
#   Artifacts/postdeploy.sql        idempotent reference data (run after every deployment)
#   Artifacts/object-manifest.json  files in order, their sha256 and the objects each defines
#   Artifacts/build-report.json     status, counts, errors
# Fails (exit 5) on: files missing from / unlisted in / duplicated in the manifest, duplicate object
# definitions, references to undefined objects or to objects defined later, objects in unmanaged schemas,
# non-declarative statements (DML, DROP, ALTER TABLE other than ADD CONSTRAINT, DO blocks other than guarded
# ADD CONSTRAINT, psql meta-commands, transaction control) and credentials in SQL.
# =====================================================================================================
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

step "build: $OBJECT_MANIFEST -> $ARTIFACTS_DIR"
git_info
rm -f "$ARTIFACTS_DIR"/{schema,predeploy,postdeploy}.sql "$ARTIFACTS_DIR"/{object-manifest,build-report}.json

rc=0
"$PY" "$BUILD_DIR/lib/dbproject.py" build --root "$ROOT_DIR" --out "$ARTIFACTS_DIR" \
  --source-dir "$SOURCE_DIR" --manifest "$OBJECT_MANIFEST" --predeploy-dir "$PREDEPLOY_DIR" \
  --postdeploy-dir "$POSTDEPLOY_DIR" --schemas "$MANAGED_SCHEMAS" --commit "${GIT_COMMIT:-}" 2> >(tee -a "$LOG_FILE" >&2) || rc=$?
[[ $rc -eq 0 ]] || die "$rc" "build failed - see $ARTIFACTS_DIR/build-report.json"
info "schema.sql sha256 $(sha256sum "$ARTIFACTS_DIR/schema.sql" | cut -c1-16)"
