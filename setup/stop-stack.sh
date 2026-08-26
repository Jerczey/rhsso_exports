#!/usr/bin/env bash
# Detiene el stack completo del lab: RHSSO → HAProxy → PostgreSQL.
set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Deteniendo stack RHSSO lab..."
"${SETUP_ROOT}/stop-rhsso.sh"
"${SETUP_ROOT}/podman/stop-haproxy.sh"
"${SETUP_ROOT}/podman/stop-postgres.sh"
echo "Stack lab detenido."
