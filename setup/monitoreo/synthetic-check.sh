#!/usr/bin/env bash
# Alias de compatibilidad — lab PostgreSQL (Podman).
exec "$(cd "$(dirname "$0")" && pwd)/synthetic-check-pg-lab.sh" "$@"
