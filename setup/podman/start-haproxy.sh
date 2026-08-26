#!/usr/bin/env bash
# HAProxy for RHSSO 7.6 lab — separate from rhbk-mc kc-haproxy-lb
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER="${HAPROXY_CONTAINER:-rhsso-haproxy}"
IMAGE="${HAPROXY_IMAGE:-registry.access.redhat.com/hi/haproxy:3}"
FRONT_PORT="${HAPROXY_FRONT_PORT:-9080}"
BACK_PORT="${RHSSO_BACK_PORT:-8080}"

podman rm -f "$CONTAINER" 2>/dev/null || true
podman run -d --name "$CONTAINER" \
  --network=host \
  -v "$SCRIPT_DIR/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:Z,ro" \
  "$IMAGE" \
  -f /usr/local/etc/haproxy/haproxy.cfg

echo "OK: $CONTAINER (host network) front=$FRONT_PORT -> RHSSO back=$BACK_PORT"
echo "Add to /etc/hosts: 127.0.0.1 rhsso.local"
