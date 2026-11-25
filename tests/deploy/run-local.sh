#!/usr/bin/env bash
# =====================================================================================================
# Runs the deployment scenario tests on this machine with Docker:
# a disposable PostgreSQL 17 container + the tool image, on a private network; both are removed afterwards.
#
#   bash tests/deploy/run-local.sh [scenario-id ...]      e.g. bash tests/deploy/run-local.sh 01 09
#
# TOOLS_IMAGE (default latam-invoice-db-tools:dev) is built from Docker/Dockerfile when missing.
# =====================================================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOLS_IMAGE="${TOOLS_IMAGE:-latam-invoice-db-tools:dev}"
PG_IMAGE="postgres:17.6-alpine@sha256:ef257d85f76e48da1c64832459b59fcaba1a4dac97bf5d7450c77753542eee94"
NET="dbtest-net-$$"; PG="dbtest-pg-$$"
# Docker Desktop on Windows (Git Bash) needs a Windows path for bind mounts
MOUNT="$ROOT"; command -v cygpath >/dev/null 2>&1 && MOUNT="$(cygpath -w "$ROOT")"
export MSYS_NO_PATHCONV=1

cleanup() { docker rm -f "$PG" >/dev/null 2>&1 || true; docker network rm "$NET" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker image inspect "$TOOLS_IMAGE" >/dev/null 2>&1 || docker build -f "$ROOT/Docker/Dockerfile" -t "$TOOLS_IMAGE" "$ROOT"
docker network create "$NET" >/dev/null
docker run -d --name "$PG" --network "$NET" -e POSTGRES_HOST_AUTH_METHOD=trust "$PG_IMAGE" >/dev/null
docker run --rm --network "$NET" -v "$MOUNT:/workspace" -w /workspace -e TEST_PG_HOST="$PG" \
  "$TOOLS_IMAGE" bash tests/deploy/scenarios.sh "$@"
