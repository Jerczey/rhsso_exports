#!/usr/bin/env bash
# Objetivo 1 — Export offline KCS 3999401 (RHSSO parado).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/env.sh
source "${SCRIPT_DIR}/../lib/env.sh"

REALM_NAME="${1:-}"
OUT_DIR="${OUT_DIR:-${EXPORTS_OFFLINE}}"
TS=$(date +%Y%m%d-%H%M%S)
WAIT_SECS="${WAIT_SECS:-180}"

RHSSO_PGREP_PATTERN="Djboss.home.dir=${RHSSO_HOME}"
if pgrep -f "${RHSSO_PGREP_PATTERN}" >/dev/null 2>&1; then
  echo "ERROR: RHSSO en ejecución. Detener primero:" >&2
  echo "  ${JBOSS_CLI} --connect --controller=${JBOSS_CONTROLLER} command=:shutdown" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}/${TS}"
EXPORT_DIR="$(cd "${OUT_DIR}/${TS}" && pwd)"
LOG="${EXPORT_DIR}/export.log"
touch "$LOG"

MIGRATION_OPTS=(
  "-Dkeycloak.migration.action=export"
  "-Dkeycloak.migration.provider=dir"
  "-Dkeycloak.migration.dir=${EXPORT_DIR}"
)

if [[ -n "$REALM_NAME" ]]; then
  MIGRATION_OPTS+=("-Dkeycloak.migration.realmName=${REALM_NAME}")
  echo "Exporting realm '${REALM_NAME}' -> ${EXPORT_DIR}"
else
  echo "Exporting ALL realms -> ${EXPORT_DIR}"
fi

cd "${RHSSO_HOME}/bin"
./standalone.sh --server-config="${SERVER_CONFIG}" "${MIGRATION_OPTS[@]}" >"$LOG" 2>&1 &
STANDALONE_PID=$!

cleanup() {
  if kill -0 "$STANDALONE_PID" 2>/dev/null; then
    "${JBOSS_CLI}" --connect --controller="${JBOSS_CONTROLLER}" command=:shutdown >>"$LOG" 2>&1 || true
    for _ in $(seq 1 30); do
      kill -0 "$STANDALONE_PID" 2>/dev/null || break
      sleep 1
    done
    kill -9 "$STANDALONE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "Waiting for export (pid ${STANDALONE_PID}, log: ${LOG}) ..."
for _ in $(seq 1 "$WAIT_SECS"); do
  if grep -q 'KC-SERVICES0035: Export finished successfully' "$LOG" 2>/dev/null; then
    echo "Export finished successfully."
    sleep 3
    "${JBOSS_CLI}" --connect --controller="${JBOSS_CONTROLLER}" command=:shutdown >>"$LOG" 2>&1 || true
    for _ in $(seq 1 60); do
      kill -0 "$STANDALONE_PID" 2>/dev/null || break
      sleep 1
    done
    break
  fi
  if ! kill -0 "$STANDALONE_PID" 2>/dev/null; then
    grep -q 'KC-SERVICES0035' "$LOG" || { echo "ERROR: standalone terminó sin export" >&2; tail -30 "$LOG"; exit 1; }
    break
  fi
  sleep 1
done

if ! grep -q 'KC-SERVICES0035: Export finished successfully' "$LOG"; then
  echo "ERROR: export no completó en ${WAIT_SECS}s" >&2
  tail -40 "$LOG"
  exit 1
fi

echo ""
find "$EXPORT_DIR" -maxdepth 1 -type f ! -name 'export.log' -printf '  %f\n' 2>/dev/null | sort \
  || find "$EXPORT_DIR" -maxdepth 1 -type f ! -name 'export.log' | sort

if [[ -x "${SCRIPT_DIR}/verify-offline-export.sh" && -n "$REALM_NAME" ]]; then
  "${SCRIPT_DIR}/verify-offline-export.sh" "$EXPORT_DIR" "$REALM_NAME"
fi
