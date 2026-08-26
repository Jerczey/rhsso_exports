#!/usr/bin/env bash
# Chequeos sintéticos — laboratorio interno (Podman + PostgreSQL Red Hat + HAProxy + SPI).
set -uo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EJECUCION_ROOT="${SETUP_ROOT}/ejecucion"
# shellcheck source=../../ejecucion/lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"

DIRECT_URL="${DIRECT_URL:-http://127.0.0.1:8080/auth}"
LB_URL="${LB_URL:-http://127.0.0.1:9080/auth}"
REALM="${SYNTH_REALM:-test-case}"
SPI_USER="${SPI_USER:-tbrady}"
SPI_PASS="${SPI_PASS:-superbowl}"
CLIENT_ID="${SYNTH_CLIENT_ID:-account}"
TIMEOUT="${CURL_TIMEOUT:-10}"

pass=0
fail=0

record() {
  local status="$1" name="$2"
  if [[ "$status" == ok ]]; then
    echo "OK   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name" >&2
    fail=$((fail + 1))
  fi
}

http_ok() {
  local url="$1"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
  [[ "$code" == "200" ]]
}

token_ok() {
  local base="$1"
  curl -sf --max-time "$TIMEOUT" \
    -d "client_id=${CLIENT_ID}" \
    -d "username=${SPI_USER}" \
    -d "password=${SPI_PASS}" \
    -d "grant_type=password" \
    "${base}/realms/${REALM}/protocol/openid-connect/token" \
    | jq -e '.access_token != null' >/dev/null 2>&1
}

if podman exec "${PG_CONTAINER}" pg_isready -U "${PG_USER}" -d "${PG_DB}" >/dev/null 2>&1; then
  record ok "PostgreSQL container ${PG_CONTAINER}"
else
  record fail "PostgreSQL container ${PG_CONTAINER}"
fi

if podman exec "${PG_CONTAINER}" psql -U "${PG_USER}" -d "${PG_DB}" -tAc "SELECT 1 FROM realm WHERE name='${REALM}'" 2>/dev/null | grep -q 1; then
  record ok "PostgreSQL realm data (${REALM})"
else
  record fail "PostgreSQL realm data (${REALM})"
fi

if http_ok "${DIRECT_URL}/realms/master"; then
  record ok "RHSSO direct /realms/master"
else
  record fail "RHSSO direct /realms/master"
fi

if http_ok "${LB_URL}/realms/master"; then
  record ok "RHSSO via HAProxy /realms/master"
else
  record fail "RHSSO via HAProxy /realms/master"
fi

if token_ok "${DIRECT_URL}"; then
  record ok "Direct grant login SPI (${REALM}/${SPI_USER})"
else
  record fail "Direct grant login SPI (${REALM}/${SPI_USER})"
fi

echo "---"
echo "Passed: $pass  Failed: $fail"
[[ "$fail" -eq 0 ]]
