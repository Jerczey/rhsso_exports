#!/usr/bin/env bash
# Ensure rhsso.local resolves to lab RHSSO (127.0.0.1)
set -euo pipefail

HOSTS_LINE="127.0.0.1 rhsso.local"
if grep -qE '^[[:space:]]*127\.0\.0\.1[[:space:]]+rhsso\.local' /etc/hosts; then
  echo "OK: rhsso.local already in /etc/hosts"
else
  echo "$HOSTS_LINE" | sudo tee -a /etc/hosts >/dev/null
  echo "Added: $HOSTS_LINE"
fi
