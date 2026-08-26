#!/usr/bin/env bash
# Detiene PostgreSQL del lab (my-postgres). No toca pg-primary-site-a (rhbk-mc).
set -euo pipefail

CONTAINER="${PG_CONTAINER:-my-postgres}"

if ! podman container exists "$CONTAINER" 2>/dev/null; then
  echo "OK: contenedor ${CONTAINER} no existe"
  exit 0
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]]; then
  echo "OK: ${CONTAINER} ya detenido"
  exit 0
fi

podman stop "$CONTAINER" >/dev/null
echo "OK: ${CONTAINER} detenido (pg-primary-site-a no se modifica)"
