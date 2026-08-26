#!/usr/bin/env bash
# Enable readonly-property-file-random SPI on test-case realm
set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")" && pwd)"
EJECUCION_ROOT="${SETUP_ROOT}/../ejecucion"
# shellcheck source=../ejecucion/lib/env.sh
source "${EJECUCION_ROOT}/lib/env.sh"

REALM="${SPI_REALM:-test-case}"
PROVIDER_ID="${SPI_PROVIDER_ID:-readonly-property-file-random}"

"${KCADM}" config credentials \
  --server "$KC_SERVER" --realm master --user "$KC_ADMIN" --password "$KC_ADMIN_PASSWORD"

EXISTING=$("${KCADM}" get components -r "$REALM" -q name="$PROVIDER_ID" --fields id 2>/dev/null | jq -r '.[0].id // empty')
if [[ -n "$EXISTING" ]]; then
  echo "SPI component already configured: $EXISTING"
else
  "${KCADM}" create components -r "$REALM" \
    -s name="$PROVIDER_ID" \
    -s providerId="$PROVIDER_ID" \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s parentId="$("${KCADM}" get "realms/${REALM}" --fields id | jq -r '.id')" \
    -s 'config.priority=["0"]'
  echo "Created User Federation component: $PROVIDER_ID in realm $REALM"
fi

ACCOUNT_ID=$("${KCADM}" get clients -r "$REALM" -q clientId=account --fields id | jq -r '.[0].id')
"${KCADM}" update "clients/${ACCOUNT_ID}" -r "$REALM" -s directAccessGrantsEnabled=true
echo "Enabled directAccessGrants on client account in ${REALM}"

echo "Test login: user=tbrady password=superbowl (direct grant on account client)"
