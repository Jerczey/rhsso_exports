#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/env.sh
source "${SCRIPT_DIR}/lib/env.sh"

rm -rf "${EXPORTS_PARTIAL:?}"/* "${EXPORTS_OFFLINE:?}"/* "${EXPORTS_ANALYSIS:?}"/* 2>/dev/null || true
touch "${EXPORTS_PARTIAL}/.gitkeep" "${EXPORTS_OFFLINE}/.gitkeep" 2>/dev/null || mkdir -p "${EXPORTS_PARTIAL}" "${EXPORTS_OFFLINE}" "${EXPORTS_ANALYSIS}"

echo "Limpiado: ${EXPORTS_PARTIAL} ${EXPORTS_OFFLINE} ${EXPORTS_ANALYSIS}"
