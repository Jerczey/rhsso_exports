#!/usr/bin/env bash
# Start RHSSO 7.6 with lab JDK and log file
set -euo pipefail

RHSSO_HOME="${RHSSO_HOME:-/opt/MW/rhsso/rh-sso-7.6.12}"
LOG="${RHSSO_LOG:-/tmp/rhsso-standalone.log}"
export JAVA_HOME="${JAVA_HOME:-/opt/MW/rhsso/jdk/jdk-11.0.32+9}"
export TZ="${TZ:-America/Santiago}"

if pgrep -f 'org.jboss.as.standalone.*rh-sso' >/dev/null 2>&1; then
  echo "RHSSO already running"
  exit 0
fi

cd "${RHSSO_HOME}/bin"
nohup ./standalone.sh >> "$LOG" 2>&1 &
echo "Starting RHSSO (log: $LOG)"
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/auth/realms/master 2>/dev/null || echo 000)
  if [[ "$code" == "200" ]]; then
    echo "OK: RHSSO up at http://127.0.0.1:8080/auth (${i}s)"
    exit 0
  fi
  sleep 2
done
echo "ERROR: RHSSO did not respond on :8080 — check $LOG" >&2
exit 1
