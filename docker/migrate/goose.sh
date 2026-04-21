#!/usr/bin/env sh

set -eu

DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-chat_system}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
GOOSE_DRIVER="${GOOSE_DRIVER:-postgres}"
GOOSE_MIGRATION_DIR="${GOOSE_MIGRATION_DIR:-/app/migrations}"
GOOSE_DBSTRING="${GOOSE_DBSTRING:-postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable}"

if [ "$#" -eq 0 ]; then
  set -- up
fi

command="$1"
shift || true

bootstrap_goose_version_table() {
  legacy_exists="$(psql "${GOOSE_DBSTRING}" -tA -c "SELECT to_regclass('public.schema_migrations') IS NOT NULL;")"
  goose_exists="$(psql "${GOOSE_DBSTRING}" -tA -c "SELECT to_regclass('public.goose_db_version') IS NOT NULL;")"

  if [ "${legacy_exists}" != "t" ]; then
    return
  fi

  legacy_count="$(psql "${GOOSE_DBSTRING}" -tA -c "
    SELECT COUNT(*)
    FROM schema_migrations
    WHERE regexp_replace(version, '^([0-9]+).*', '\1') ~ '^[0-9]+$';
  ")"

  if [ "${legacy_count}" = "0" ]; then
    return
  fi

  echo "Bootstrapping goose version tracking from legacy schema_migrations..."
  psql "${GOOSE_DBSTRING}" -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS goose_db_version (
    id BIGSERIAL PRIMARY KEY,
    version_id BIGINT NOT NULL,
    is_applied BOOLEAN NOT NULL,
    tstamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO goose_db_version (version_id, is_applied)
SELECT DISTINCT CAST(regexp_replace(version, '^([0-9]+).*', '\1') AS BIGINT), TRUE
FROM schema_migrations
WHERE regexp_replace(version, '^([0-9]+).*', '\1') ~ '^[0-9]+$'
  AND NOT EXISTS (
    SELECT 1
    FROM goose_db_version g
    WHERE g.version_id = CAST(regexp_replace(schema_migrations.version, '^([0-9]+).*', '\1') AS BIGINT)
      AND g.is_applied = TRUE
  )
ORDER BY 1;
"
}

case "${command}" in
  create)
    exec goose -dir "${GOOSE_MIGRATION_DIR}" create "$@"
    ;;
  up|up-by-one|down|down-to|redo|reset|status|version|validate|fix)
    echo "Waiting for Postgres at ${DB_HOST}:${DB_PORT}..."
    until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; do
      sleep 2
    done
    bootstrap_goose_version_table
    exec goose -dir "${GOOSE_MIGRATION_DIR}" "${command}" "${GOOSE_DRIVER}" "${GOOSE_DBSTRING}" "$@"
    ;;
  *)
    exec goose "$command" "$@"
    ;;
esac
