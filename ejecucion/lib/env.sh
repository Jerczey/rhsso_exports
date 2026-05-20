# Variables comunes — copiar config.env.example a config.env y ajustar.
EJECUCION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${EJECUCION_ROOT}/config.env" ]]; then
  # shellcheck source=/dev/null
  source "${EJECUCION_ROOT}/config.env"
fi

# RHSSO / Keycloak
export RHSSO_HOME="${RHSSO_HOME:-/opt/MW/rhsso/rh-sso-7.6.12}"
export KC_SERVER="${KC_SERVER:-http://127.0.0.1:8080/auth}"
export KC_ADMIN="${KC_ADMIN:-admin}"
export KC_REALM="${KC_REALM:-}"
export KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-}"
export JBOSS_CLI="${JBOSS_CLI:-${RHSSO_HOME}/bin/jboss-cli.sh}"
export KCADM="${KCADM:-${RHSSO_HOME}/bin/kcadm.sh}"
export SERVER_CONFIG="${SERVER_CONFIG:-standalone.xml}"
export JBOSS_CONTROLLER="${JBOSS_CONTROLLER:-127.0.0.1:9990}"

# Salidas de export
export EXPORTS_PARTIAL="${EXPORTS_PARTIAL:-${EJECUCION_ROOT}/exports/partial}"
export EXPORTS_OFFLINE="${EXPORTS_OFFLINE:-${EJECUCION_ROOT}/exports/offline}"
export EXPORTS_ANALYSIS="${EXPORTS_ANALYSIS:-${EJECUCION_ROOT}/exports/analysis}"

# PostgreSQL (ejemplo podman)
export DB_TYPE="${DB_TYPE:-pg}"
export PG_CONTAINER="${PG_CONTAINER:-my-postgres}"
export PG_USER="${PG_USER:-yurek}"
export PG_DB="${PG_DB:-rhsso}"

# Microsoft SQL Server
export MSSQL_HOST="${MSSQL_HOST:-localhost}"
export MSSQL_PORT="${MSSQL_PORT:-1433}"
export MSSQL_DB="${MSSQL_DB:-rhsso}"
export MSSQL_USER="${MSSQL_USER:-rhsso}"
export MSSQL_PASSWORD="${MSSQL_PASSWORD:-}"
export SQLCMD="${SQLCMD:-sqlcmd}"
