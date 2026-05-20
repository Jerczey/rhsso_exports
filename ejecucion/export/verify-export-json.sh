#!/usr/bin/env bash
# Objetivo 1 — Verificar JSON: realm, browser flow, scopes, clients.
set -euo pipefail

JSON="${1:?Usage: $0 <realm-export.json> [realm-esperado]}"
REALM_EXPECTED="${2:-}"

[[ -f "$JSON" ]] || { echo "FAIL: no existe $JSON"; exit 1; }
echo "Checking: $JSON"

R=$(jq -r '.realm // empty' "$JSON")
BF=$(jq -r '.browserFlow // empty' "$JSON")
FLOWS=$(jq '.authenticationFlows | length' "$JSON")
SCOPES=$(jq '.clientScopes | length' "$JSON")
CLIENTS=$(jq '.clients | length' "$JSON")
HAS_BROWSER=$(jq '[.authenticationFlows[]? | select(.alias=="browser")] | length' "$JSON")

fail() { echo "  FAIL: $1"; exit 1; }
ok() { echo "  OK: $1"; }

[[ -n "$R" ]] && ok "realm = $R" || fail "missing .realm"
[[ -z "$REALM_EXPECTED" || "$R" == "$REALM_EXPECTED" ]] || fail "realm mismatch"
[[ "$BF" == "browser" ]] && ok "browserFlow = browser" || fail "browserFlow"
[[ "$HAS_BROWSER" -ge 1 ]] && ok "authenticationFlows incluye browser" || fail "sin flow browser"
[[ "$SCOPES" -ge 1 ]] && ok "clientScopes = $SCOPES" || fail "sin clientScopes"
[[ "$CLIENTS" -ge 1 ]] && ok "clients = $CLIENTS" || fail "sin clients (use exportClients=true u offline)"
jq -e '.clients[0].clientId' "$JSON" >/dev/null && ok "clients[].clientId presente"

echo "Cubre: realm, browser flow, scopes, clientId + configuración."
