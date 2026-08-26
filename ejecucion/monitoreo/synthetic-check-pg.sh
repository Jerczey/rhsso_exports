#!/usr/bin/env bash
# Chequeos sintéticos — PostgreSQL nativo (psql) o fallback Podman si PG_CONTAINER está definido.
set -uo pipefail

MONITOREO_ROOT="$(cd "$(dirname "$0")" && pwd)"
EJECUCION_ROOT="$(cd "${MONITOREO_ROOT}/.." && pwd)"
# shellcheck source=../lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"
# shellcheck source=lib/common.sh
source "${MONITOREO_ROOT}/lib/common.sh"

SYNTH_PASS=0
SYNTH_FAIL=0

: "${PG_HOST:?Defina PG_HOST en config.env}"
: "${PG_PORT:?Defina PG_PORT en config.env}"
: "${PG_USER:?Defina PG_USER en config.env}"
: "${PG_DB:?Defina PG_DB en config.env}"

REALM="${SYNTH_REALM:-${KC_REALM:-master}}"
export SYNTH_REALM="$REALM"
export PGPASSWORD="${PG_PASSWORD:-${PGPASSWORD:-}}"

pg_via_podman() {
  [[ -n "${PG_CONTAINER:-}" ]] \
    && command -v podman >/dev/null 2>&1 \
    && podman container exists "${PG_CONTAINER}" 2>/dev/null \
    && podman ps --format '{{.Names}}' | grep -qx "${PG_CONTAINER}"
}

pg_exec() {
  if command -v psql >/dev/null 2>&1; then
    PGPASSWORD="${PGPASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DB}" "$@"
  elif pg_via_podman; then
    podman exec "${PG_CONTAINER}" psql -U "${PG_USER}" -d "${PG_DB}" "$@"
  else
    return 127
  fi
}

pg_label="PostgreSQL ${PG_HOST}:${PG_PORT}/${PG_DB}"
if pg_via_podman && ! command -v psql >/dev/null 2>&1; then
  pg_label="PostgreSQL container ${PG_CONTAINER}"
fi

if pg_exec -c "SELECT 1" >/dev/null 2>&1; then
  synth_record ok "$pg_label"
else
  synth_record fail "$pg_label"
fi

if pg_exec -tAc "SELECT 1 FROM realm WHERE name='${REALM}'" 2>/dev/null | grep -q 1; then
  synth_record ok "Realm en BD (${REALM})"
else
  synth_record fail "Realm en BD (${REALM})"
fi

synth_check_rhsso_http

if [[ -n "${SYNTH_USER:-}" && -n "${SYNTH_PASSWORD:-}" && -n "${SYNTH_CLIENT_ID:-}" ]]; then
  synth_check_login
else
  echo "SKIP Login OIDC — defina SYNTH_USER, SYNTH_PASSWORD y SYNTH_CLIENT_ID para habilitar"
fi

synth_summary
