#!/usr/bin/env bash
# Uso interno — crea realm export-lab para laboratorio.
set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EJECUCION_ROOT="${SETUP_ROOT}/ejecucion"
# shellcheck source=../ejecucion/lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"

: "${KC_ADMIN_PASSWORD:?Defina KC_ADMIN_PASSWORD en ejecucion/config.env}"
REALM="${REALM:-export-lab}"

"${KCADM}" config credentials \
  --server "$KC_SERVER" --realm master --user "$KC_ADMIN" --password "$KC_ADMIN_PASSWORD"

if ! "${KCADM}" get "realms/${REALM}" >/dev/null 2>&1; then
  "${KCADM}" create realms -s realm="$REALM" -s enabled=true -s displayName="Export Lab"
  echo "Created realm ${REALM}"
else
  echo "Realm ${REALM} already exists"
fi

SCOPE_ID=$("${KCADM}" create "realms/${REALM}/client-scopes" -r "$REALM" \
  -s name=export-lab-scope -s protocol=openid-connect -s 'description=Custom scope for export lab' -i 2>/dev/null || true)

if ! "${KCADM}" get "realms/${REALM}/clients" -r "$REALM" -q clientId=export-lab-app 2>/dev/null | jq -e 'length > 0' >/dev/null; then
  "${KCADM}" create "realms/${REALM}/clients" -r "$REALM" \
    -s clientId=export-lab-app -s enabled=true -s protocol=openid-connect \
    -s publicClient=false -s standardFlowEnabled=true -s directAccessGrantsEnabled=true \
    -s 'redirectUris=["http://localhost:8080/*"]' -s 'webOrigins=["+"]'
  echo "Created client export-lab-app"
fi

if ! "${KCADM}" get "realms/${REALM}/clients" -r "$REALM" -q clientId=export-lab-public 2>/dev/null | jq -e 'length > 0' >/dev/null; then
  "${KCADM}" create "realms/${REALM}/clients" -r "$REALM" \
    -s clientId=export-lab-public -s enabled=true -s protocol=openid-connect \
    -s publicClient=true -s standardFlowEnabled=true \
    -s 'redirectUris=["http://localhost:9999/*"]'
  echo "Created client export-lab-public"
fi

# Eventos: solo tipos necesarios para detectar uso de clients (ver ejecucion/README.md)
"${KCADM}" update "realms/${REALM}" -r "$REALM" \
  -s eventsEnabled=true \
  -s eventsExpiration=604800 \
  -s 'enabledEventTypes=["LOGIN","LOGOUT","CLIENT_LOGIN","CODE_TO_TOKEN","REFRESH_TOKEN"]'

CID=$("${KCADM}" get "realms/${REALM}/clients" -r "$REALM" -q clientId=export-lab-app --fields id | jq -r '.[0].id')
SECRET=$("${KCADM}" get "realms/${REALM}/clients/${CID}/client-secret" -r "$REALM" | jq -r '.value')

echo ""
echo "Realm ready: ${REALM}"
echo "  Partial export: cd ejecucion && KC_REALM=${REALM} ./export/export-realm-partial.sh"
