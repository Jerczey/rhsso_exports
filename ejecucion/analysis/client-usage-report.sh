#!/usr/bin/env bash
# Objetivo 2 — Reporte clientId en uso / sin uso.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/env.sh
source "${SCRIPT_DIR}/../lib/env.sh"

OUT="${OUT:-}"
[[ -z "$OUT" && -n "${REPORT_OUT:-}" ]] && OUT="${REPORT_OUT}"
[[ -n "$OUT" && "$OUT" != /* ]] && OUT="${EXPORTS_ANALYSIS}/${OUT}"
[[ -n "$OUT" ]] && mkdir -p "$(dirname "$OUT")"

run_pg() {
  local sql="${SCRIPT_DIR}/client-usage-report_pg.sql"
  echo "PostgreSQL: container=${PG_CONTAINER} db=${PG_DB} user=${PG_USER}"
  if [[ -n "$OUT" ]]; then
    podman exec -i "${PG_CONTAINER}" psql -U "${PG_USER}" -d "${PG_DB}" < "$sql" | tee "$OUT"
    echo "Guardado: $OUT"
  else
    podman exec -i "${PG_CONTAINER}" psql -U "${PG_USER}" -d "${PG_DB}" < "$sql"
  fi
}

run_mssql() {
  local sql="${SCRIPT_DIR}/client-usage-report_mssql.sql"
  : "${MSSQL_PASSWORD:?Defina MSSQL_PASSWORD en config.env}"
  local server="${MSSQL_HOST},${MSSQL_PORT}"
  echo "SQL Server: server=${server} db=${MSSQL_DB} user=${MSSQL_USER}"
  local -a cmd=(
    "${SQLCMD}" -S "$server" -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}"
    -d "${MSSQL_DB}" -i "$sql" -b
  )
  [[ "${MSSQL_TRUST_CERT:-false}" == "true" ]] && cmd+=(-C)
  if [[ -n "$OUT" ]]; then
    "${cmd[@]}" | tee "$OUT"
    echo "Guardado: $OUT"
  else
    "${cmd[@]}"
  fi
}

case "${DB_TYPE}" in
  pg|postgres|postgresql) run_pg ;;
  mssql|sqlserver|sql)  run_mssql ;;
  *)
    echo "ERROR: DB_TYPE='${DB_TYPE}' no soportado. Use: pg | mssql" >&2
    exit 1
    ;;
esac
