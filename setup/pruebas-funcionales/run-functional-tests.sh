#!/usr/bin/env bash
# Uso interno — valida scripts de ejecucion/.
set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EJECUCION_ROOT="${SETUP_ROOT}/ejecucion"
# shellcheck source=../../ejecucion/lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"

EXPORT_SCRIPT="${EJECUCION_ROOT}/export/export-realm-partial.sh"
ANALYSIS_SCRIPT="${EJECUCION_ROOT}/analysis/client-usage-report.sh"
TS=$(date +%Y%m%d-%H%M%S)
RUN_DIR="${SETUP_ROOT}/setup/pruebas-funcionales/runs/${TS}"
EXPORT_DIR="${RUN_DIR}"
REPORT_FILE="${RUN_DIR}/test-results.txt"
BENCHMARK_REALM="${BENCHMARK_REALM:-bench-realm-1}"
KCB="${KCB:-/home/jerczey/Desktop/yes/crc/keycloak-benchmark/benchmark/target/keycloak-benchmark-999.0.0-SNAPSHOT/bin/kcb.sh}"
BENCHMARK_URL="${BENCHMARK_URL:-http://rhsso.local:8080/auth}"

mkdir -p "$RUN_DIR"
: > "$REPORT_FILE"

log() { echo "$1" | tee -a "$REPORT_FILE"; }
pass() { log "  PASS: $1"; }
fail() { log "  FAIL: $1"; exit 1; }

"${KCADM}" config credentials \
  --server "$KC_SERVER" --realm master --user "$KC_ADMIN" --password "${KC_ADMIN_PASSWORD:-admin}" >/dev/null

log "Test 1: Partial export (5 realms)"
for i in 1 2 3 4 5; do
  REALM="bench-realm-${i}"
  export KC_REALM="$REALM" OUT_DIR="$EXPORT_DIR"
  "$EXPORT_SCRIPT" >/dev/null
  FILE=$(ls -t "$EXPORT_DIR/${REALM}-"*.json 2>/dev/null | head -1)
  [[ -n "$FILE" ]] || fail "${REALM}: sin JSON"
  pass "${REALM}: $(basename "$FILE")"
done

log "Test 2: Benchmark + analysis (DB_TYPE=${DB_TYPE})"
[[ -x "$KCB" ]] || fail "kcb.sh no encontrado"
BENCH_LOG="${RUN_DIR}/benchmark.log"
: > "$BENCH_LOG"
"$KCB" --scenario=keycloak.scenario.authentication.LoginUserPassword \
  --server-url="${BENCHMARK_URL}" --realm-name="${BENCHMARK_REALM}" \
  --users-per-sec=2 --ramp-up=5 --measurement=15 --ramp-down=3 \
  2>&1 | tee -a "$BENCH_LOG" | tail -10
grep -qE '> failed[[:space:]]+0 \( *0%\)' "$BENCH_LOG" || fail "benchmark con fallos"
DB_TYPE="${DB_TYPE}" OUT="${RUN_DIR}/client-usage.txt" "$ANALYSIS_SCRIPT"
pass "analysis report generado"

log "ALL TESTS PASSED"
