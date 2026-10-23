#!/bin/sh
# Runs once, when the postgres container initialises an empty data directory
# (mounted into /docker-entrypoint-initdb.d by the docker-compose files).
# Creates schema "app" and loads the demo data from database/postgres (mounted at /db-scripts).
set -e

echo "Deploying Cargill Custom Apps schema into database '$POSTGRES_DB'..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /db-scripts/deploy_schema.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /db-scripts/seed.sql
echo "Schema and demo data loaded."
