#!/usr/bin/env bash
# RHSSO 7.6 lab PostgreSQL — Red Hat catalog image, port 5433 (pg-primary-site-a stays on 5432)
set -euo pipefail

PG_DATA="${PG_DATA:-/opt/MW/rhsso/pg_data/rhsso-rhel17}"
PG_IMAGE="${PG_IMAGE:-registry.access.redhat.com/hi/postgresql:17}"
CONTAINER="${PG_CONTAINER:-my-postgres}"
PG_PORT="${PG_PORT:-5433}"
PG_USER="${PG_USER:-yurek}"
PG_PASSWORD="${PG_PASSWORD:-yurekpassword}"
PG_DB="${PG_DB:-rhsso}"
TZ="${TZ:-America/Santiago}"

# rhbk-mc database must remain offline for this lab
podman stop pg-primary-site-a 2>/dev/null || true

if [[ ! -d "$PG_DATA/PG_VERSION" ]]; then
  mkdir -p "$PG_DATA"
fi

podman rm -f "$CONTAINER" 2>/dev/null || true
podman run -d --name "$CONTAINER" \
  -p "127.0.0.1:${PG_PORT}:5432" \
  -v "$PG_DATA:/var/lib/postgresql/data:U,Z" \
  -e POSTGRES_USER="$PG_USER" \
  -e POSTGRES_PASSWORD="$PG_PASSWORD" \
  -e POSTGRES_DB="$PG_DB" \
  -e TZ="$TZ" \
  "$PG_IMAGE"

echo "Waiting for PostgreSQL (${PG_IMAGE})..."
for _ in $(seq 1 45); do
  if podman exec "$CONTAINER" pg_isready -U "$PG_USER" -d "$PG_DB" >/dev/null 2>&1; then
    echo "OK: $CONTAINER on 127.0.0.1:${PG_PORT} db=${PG_DB} user=${PG_USER} tz=${TZ}"
    podman exec "$CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -c "SHOW timezone; SELECT name FROM realm ORDER BY name;"
    exit 0
  fi
  sleep 1
done
echo "ERROR: PostgreSQL did not become ready" >&2
podman logs "$CONTAINER" | tail -20 >&2
exit 1
