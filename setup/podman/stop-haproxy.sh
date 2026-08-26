#!/usr/bin/env bash
# Detiene HAProxy del lab (rhsso-haproxy). No toca kc-haproxy-lb de rhbk-mc.
set -euo pipefail

CONTAINER="${HAPROXY_CONTAINER:-rhsso-haproxy}"

if ! podman container exists "$CONTAINER" 2>/dev/null; then
  echo "OK: contenedor ${CONTAINER} no existe"
  exit 0
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]]; then
  echo "OK: ${CONTAINER} ya detenido"
  exit 0
fi

podman stop "$CONTAINER" >/dev/null
echo "OK: ${CONTAINER} detenido"
