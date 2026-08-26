#!/usr/bin/env bash
# Build and deploy user-storage SPI (with random delay) to RHSSO 7.6
set -euo pipefail

QUICKSTART="/home/jgodoy/Desktop/yes/crc/redhat-sso-quickstarts/user-storage-simple"
RHSSO_HOME="${RHSSO_HOME:-/opt/MW/rhsso/rh-sso-7.6.12}"
DEPLOY="${RHSSO_HOME}/standalone/deployments/user-storage-properties-example.jar"

cd "$QUICKSTART"
mvn -q clean package -DskipTests
cp target/user-storage-properties-example.jar "$DEPLOY"
echo "Deployed $(basename "$DEPLOY") — waiting for WildFly scanner..."
for _ in $(seq 1 30); do
  if [[ -f "${DEPLOY}.deployed" ]]; then
    echo "OK: SPI deployed"
    exit 0
  fi
  if [[ -f "${DEPLOY}.failed" ]]; then
    echo "ERROR: deployment failed — see ${DEPLOY}.failed" >&2
    exit 1
  fi
  sleep 2
done
echo "WARN: deployment marker not found yet; check server log" >&2
