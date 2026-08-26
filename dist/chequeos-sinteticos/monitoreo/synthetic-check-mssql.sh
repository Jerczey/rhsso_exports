#!/usr/bin/env bash
# Chequeos sintéticos — cliente con Microsoft SQL Server.
set -uo pipefail

MONITOREO_ROOT="$(cd "$(dirname "$0")" && pwd)"
EJECUCION_ROOT="$(cd "${MONITOREO_ROOT}/.." && pwd)"
# shellcheck source=../lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"
# shellcheck source=lib/common.sh
source "${MONITOREO_ROOT}/lib/common.sh"

SYNTH_PASS=0
SYNTH_FAIL=0

: "${MSSQL_HOST:?Defina MSSQL_HOST en config.env}"
: "${MSSQL_PORT:?Defina MSSQL_PORT en config.env}"
: "${MSSQL_DB:?Defina MSSQL_DB en config.env}"
: "${MSSQL_USER:?Defina MSSQL_USER en config.env}"
: "${MSSQL_PASSWORD:?Defina MSSQL_PASSWORD en config.env}"

REALM="${SYNTH_REALM:-${KC_REALM:-master}}"
export SYNTH_REALM="$REALM"
SERVER="${MSSQL_HOST},${MSSQL_PORT}"

mssql_query() {
  local -a cmd=(
    "${SQLCMD}" -S "$SERVER" -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}"
    -d "${MSSQL_DB}" -Q "$1" -b -h -1
  )
  [[ "${MSSQL_TRUST_CERT:-false}" == "true" ]] && cmd+=(-C)
  "${cmd[@]}" 2>/dev/null
}

if mssql_query "SELECT 1" | grep -q 1; then
  synth_record ok "SQL Server ${SERVER}/${MSSQL_DB}"
else
  synth_record fail "SQL Server ${SERVER}/${MSSQL_DB}"
fi

if mssql_query "SELECT 1 FROM realm WHERE name = '${REALM}'" | grep -q 1; then
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
