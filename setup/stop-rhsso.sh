#!/usr/bin/env bash
# Detiene RHSSO 7.6 lab (solo rh-sso-7.6.12, no otros JBoss/EAP).
set -euo pipefail

RHSSO_HOME="${RHSSO_HOME:-/opt/MW/rhsso/rh-sso-7.6.12}"
PATTERN="org.jboss.as.standalone.*${RHSSO_HOME}"

if ! pgrep -f "$PATTERN" >/dev/null 2>&1; then
  echo "RHSSO 7.6 ya detenido (${RHSSO_HOME})"
  exit 0
fi

pkill -f "$PATTERN" 2>/dev/null || true
for _ in $(seq 1 15); do
  pgrep -f "$PATTERN" >/dev/null 2>&1 || break
  sleep 1
done

if pgrep -f "$PATTERN" >/dev/null 2>&1; then
  echo "ERROR: RHSSO sigue en ejecución" >&2
  pgrep -af "$PATTERN" >&2 || true
  exit 1
fi

echo "OK: RHSSO 7.6 detenido"
