#!/usr/bin/env sh

set -eu

DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-chat_system}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-/app/migrations}"

export PGPASSWORD="${DB_PASSWORD}"

echo "Waiting for Postgres at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; do
  sleep 2
done

echo "Ensuring migration tracking table exists..."
psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  -v ON_ERROR_STOP=1 \
  -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);"

echo "Applying pending migrations..."
for file in $(find "${MIGRATIONS_DIR}" -maxdepth 1 -type f -name '*.sql' | sort); do
  version="$(basename "${file}")"

  applied="$(psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -tA \
    -v ON_ERROR_STOP=1 \
    -c "SELECT 1 FROM schema_migrations WHERE version = '${version}' LIMIT 1;")"

  if [ "${applied}" = "1" ]; then
    echo "Skipping already applied migration: ${version}"
    continue
  fi

  echo "Running migration: ${version}"
  psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -f "${file}"

  psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -c "INSERT INTO schema_migrations (version) VALUES ('${version}');"

  echo "Applied migration: ${version}"
done

echo "Migration run completed."
