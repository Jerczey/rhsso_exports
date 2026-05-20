#!/usr/bin/env bash
# Validates an offline dir export produced by export-realm-offline.sh
set -euo pipefail

EXPORT_DIR="${1:?Usage: $0 <offline-export-directory> [realm-name]}"
REALM="${2:-}"

if [[ -z "$REALM" ]]; then
  REALM=$(basename "$(ls -1 "$EXPORT_DIR"/*-realm.json 2>/dev/null | head -1)" | sed 's/-realm\.json$//')
fi

REALM_JSON="${EXPORT_DIR}/${REALM}-realm.json"
USERS_GLOB="${EXPORT_DIR}/${REALM}-users-*.json"

[[ -f "$REALM_JSON" ]] || { echo "FAIL: missing ${REALM_JSON}"; exit 1; }

echo "Verifying offline export: ${EXPORT_DIR}"
echo "Realm: ${REALM}"

FLOWS=$(jq '.authenticationFlows | length' "$REALM_JSON")
SCOPES=$(jq '.clientScopes | length' "$REALM_JSON")
CLIENTS=$(jq '.clients | length' "$REALM_JSON")
ROLES=$(jq '.roles.realm | length' "$REALM_JSON")
BFLOW=$(jq -r '.browserFlow' "$REALM_JSON")
SECRET=$(jq -r '.clients[]|select(.clientId=="client-0")|.secret // empty' "$REALM_JSON")
USER_FILES=$(ls -1 $USERS_GLOB 2>/dev/null | wc -l)
USER_COUNT=$(jq '[.users[]]|length' $USERS_GLOB 2>/dev/null | awk '{s+=$1} END {print s+0}')

checks=0
ok() { echo "  OK: $1"; checks=$((checks+1)); }
fail() { echo "  FAIL: $1"; exit 1; }

[[ "$BFLOW" == "browser" ]] && ok "browserFlow = browser" || fail "browserFlow"
[[ "$FLOWS" -ge 20 ]] && ok "authenticationFlows >= 20 ($FLOWS)" || fail "flows count"
[[ "$SCOPES" -ge 10 ]] && ok "clientScopes >= 10 ($SCOPES)" || fail "scopes count"
[[ "$CLIENTS" -ge 11 ]] && ok "clients >= 11 ($CLIENTS)" || fail "clients count"
[[ "$ROLES" -ge 8 ]] && ok "roles.realm >= 8 ($ROLES)" || fail "roles count"

jq -e '.clients[]|select(.clientId=="bench-client-1")' "$REALM_JSON" >/dev/null && ok "bench-client-1 present" || fail "bench-client-1"
jq -e '.clientScopes[]|select(.name=="bench-scope-1")' "$REALM_JSON" >/dev/null && ok "bench-scope-1 present" || fail "bench-scope-1"

[[ -n "$SECRET" && "$SECRET" != "**********" ]] \
  && ok "client-0 secret exported in clear (offline)" \
  || fail "client-0 secret missing or masked"

[[ "$USER_FILES" -ge 1 ]] && ok "users file(s): $USER_FILES" || fail "no users-*.json"
[[ "$USER_COUNT" -ge 5 ]] && ok "users exported: $USER_COUNT" || fail "expected >=5 users, got $USER_COUNT"

grep -q 'KC-SERVICES0035: Export finished successfully' "${EXPORT_DIR}/export.log" 2>/dev/null \
  && ok "export.log confirms success" || fail "export.log missing success message"

echo ""
echo "All checks passed ($checks)."
