# Funciones HTTP / OIDC compartidas — chequeos sintéticos cliente.
# shellcheck shell=bash

synth_record() {
  local status="$1" name="$2"
  if [[ "$status" == ok ]]; then
    echo "OK   $name"
    SYNTH_PASS=$((SYNTH_PASS + 1))
  else
    echo "FAIL $name" >&2
    SYNTH_FAIL=$((SYNTH_FAIL + 1))
  fi
}

synth_http_ok() {
  local url="$1"
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time "${CURL_TIMEOUT:-10}" "$url" 2>/dev/null || echo "000")
  [[ "$code" == "200" ]]
}

synth_token_ok() {
  local base="$1"
  local realm="${SYNTH_REALM:-${KC_REALM:-master}}"
  local client="${SYNTH_CLIENT_ID:?Defina SYNTH_CLIENT_ID}"
  local user="${SYNTH_USER:?Defina SYNTH_USER}"
  local pass="${SYNTH_PASSWORD:?Defina SYNTH_PASSWORD}"
  curl -sf --max-time "${CURL_TIMEOUT:-10}" \
    -d "client_id=${client}" \
    -d "username=${user}" \
    -d "password=${pass}" \
    -d 'grant_type=password' \
    "${base}/realms/${realm}/protocol/openid-connect/token" \
    | jq -e '.access_token != null' >/dev/null 2>&1
}

synth_check_rhsso_http() {
  local base="${KC_SERVER:?Defina KC_SERVER en config.env}"
  base="${base%/}"
  if synth_http_ok "${base}/realms/master"; then
    synth_record ok "RHSSO ${base}/realms/master"
  else
    synth_record fail "RHSSO ${base}/realms/master"
  fi
  if [[ -n "${LB_URL:-}" ]]; then
    local lb="${LB_URL%/}"
    if synth_http_ok "${lb}/realms/master"; then
      synth_record ok "Balanceador ${lb}/realms/master"
    else
      synth_record fail "Balanceador ${lb}/realms/master"
    fi
  fi
}

synth_check_login() {
  local base="${KC_SERVER%/}"
  if synth_token_ok "$base"; then
    synth_record ok "Login OIDC (${SYNTH_REALM:-${KC_REALM}}/${SYNTH_USER})"
  else
    synth_record fail "Login OIDC (${SYNTH_REALM:-${KC_REALM}}/${SYNTH_USER})"
  fi
}

synth_summary() {
  echo "---"
  echo "Passed: ${SYNTH_PASS}  Failed: ${SYNTH_FAIL}"
  [[ "${SYNTH_FAIL}" -eq 0 ]]
}
