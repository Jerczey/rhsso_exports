#!/usr/bin/env bash
# Uso interno — 5 realms bench-realm-1..5 para pruebas.
set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../ejecucion/lib/env.sh
source "${SETUP_ROOT}/ejecucion/lib/env.sh"

: "${KC_ADMIN_PASSWORD:?Defina KC_ADMIN_PASSWORD en ejecucion/config.env}"

"${KCADM}" config credentials \
  --server "$KC_SERVER" --realm master --user "$KC_ADMIN" --password "$KC_ADMIN_PASSWORD"

for i in 1 2 3 4 5; do
  REALM="bench-realm-${i}"
  echo "=== Provisioning ${REALM} ==="

  if ! "${KCADM}" get "realms/${REALM}" >/dev/null 2>&1; then
    "${KCADM}" create realms -s realm="$REALM" -s enabled=true \
      -s displayName="Benchmark Realm ${i}"
    echo "  Created realm"
  else
    echo "  Realm exists"
  fi

  # 5 client scopes
  for s in 1 2 3 4 5; do
    SCOPE="bench-scope-${s}"
    if ! "${KCADM}" get "realms/${REALM}/client-scopes" -r "$REALM" --fields name \
      | jq -e --arg n "$SCOPE" '.[] | select(.name==$n)' >/dev/null 2>&1; then
      "${KCADM}" create "realms/${REALM}/client-scopes" -r "$REALM" \
        -s name="$SCOPE" -s protocol=openid-connect \
        -s "description=Benchmark scope ${s} in ${REALM}" >/dev/null
      echo "  + scope ${SCOPE}"
    fi
  done

  # 5 application clients (+ client-0 for keycloak-benchmark login scenario)
  for c in 1 2 3 4 5; do
    CID="bench-client-${c}"
    if ! "${KCADM}" get "realms/${REALM}/clients" -r "$REALM" -q "clientId=${CID}" \
      | jq -e 'length > 0' >/dev/null 2>&1; then
      "${KCADM}" create "realms/${REALM}/clients" -r "$REALM" \
        -s clientId="$CID" -s enabled=true -s protocol=openid-connect \
        -s publicClient=false -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=true \
        -s 'redirectUris=["http://localhost:8080/*","http://0.0.0.0:8080/*"]' \
        -s 'webOrigins=["+"]' >/dev/null
      echo "  + client ${CID}"
    fi
  done

  # Benchmark-standard client-0 (LoginUserPassword scenario)
  if ! "${KCADM}" get "realms/${REALM}/clients" -r "$REALM" -q clientId=client-0 \
    | jq -e 'length > 0' >/dev/null 2>&1; then
    "${KCADM}" create "realms/${REALM}/clients" -r "$REALM" \
      -s clientId=client-0 -s enabled=true -s protocol=openid-connect \
      -s publicClient=false -s standardFlowEnabled=true \
      -s secret=client-0-secret \
      -s 'redirectUris=["*"]' -s 'webOrigins=["+"]' >/dev/null
    echo "  + client client-0 (benchmark)"
  fi

  # 5 users (user-0 .. user-4)
  for u in $(seq 0 4); do
    UNAME="user-${u}"
    if ! "${KCADM}" get "realms/${REALM}/users" -r "$REALM" -q "username=${UNAME}" \
      | jq -e 'length > 0' >/dev/null 2>&1; then
      "${KCADM}" create users -r "$REALM" \
        -s username="$UNAME" -s enabled=true \
        -s email="${UNAME}@bench.local" >/dev/null
      "${KCADM}" set-password -r "$REALM" --username "$UNAME" \
        --new-password "${UNAME}-password" >/dev/null
      echo "  + user ${UNAME}"
    fi
  done

  # 5 realm roles
  for r in 1 2 3 4 5; do
    RNAME="bench-role-${r}"
    if ! "${KCADM}" get "realms/${REALM}/roles" -r "$REALM" --fields name \
      | jq -e --arg n "$RNAME" '.[] | select(.name==$n)' >/dev/null 2>&1; then
      "${KCADM}" create "realms/${REALM}/roles" -r "$REALM" -s name="$RNAME" >/dev/null
      echo "  + role ${RNAME}"
    fi
  done

  "${KCADM}" update "realms/${REALM}" -r "$REALM" \
    -s eventsEnabled=true \
    -s eventsExpiration=604800 \
    -s 'enabledEventTypes=["LOGIN","LOGOUT","CLIENT_LOGIN","CODE_TO_TOKEN","REFRESH_TOKEN"]' >/dev/null
done

echo ""
echo "Done. Realms: bench-realm-1 .. bench-realm-5"
echo "Each realm: 5 scopes, 5 bench-client-*, client-0, 5 users, 5 roles"
