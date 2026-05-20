#!/usr/bin/env bash
# Objetivo 1 — Partial export (servidor en marcha).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/env.sh
source "${SCRIPT_DIR}/../lib/env.sh"

: "${KC_ADMIN_PASSWORD:?Defina KC_ADMIN_PASSWORD en config.env}"
: "${KC_REALM:?Defina KC_REALM en config.env}"

EXPORT_CLIENTS="${EXPORT_CLIENTS:-true}"
EXPORT_GROUPS_ROLES="${EXPORT_GROUPS_ROLES:-true}"
OUT_DIR="${OUT_DIR:-${EXPORTS_PARTIAL}}"

mkdir -p "$OUT_DIR"
TS=$(date +%Y%m%d-%H%M%S)
OUT_FILE="$OUT_DIR/${KC_REALM}-${TS}.json"

TOKEN=$(curl -sf \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN}" \
  -d "password=${KC_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  "${KC_SERVER}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "ERROR: token inválido. Revise KC_SERVER, KC_ADMIN, KC_ADMIN_PASSWORD" >&2
  exit 1
fi

QUERY="exportClients=${EXPORT_CLIENTS}&exportGroupsAndRoles=${EXPORT_GROUPS_ROLES}"
curl -sf -X POST \
  "${KC_SERVER}/admin/realms/${KC_REALM}/partial-export?${QUERY}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  | jq . > "$OUT_FILE"

echo "Exported realm '${KC_REALM}' -> ${OUT_FILE}"
jq -r '
  "  authenticationFlows: \(.authenticationFlows | length // 0)",
  "  clientScopes:        \(.clientScopes | length // 0)",
  "  clients:             \(.clients | length // 0)",
  "  realm roles:         \(.roles.realm | length // 0)",
  "  browserFlow:         \(.browserFlow // "n/a")"
' "$OUT_FILE"
