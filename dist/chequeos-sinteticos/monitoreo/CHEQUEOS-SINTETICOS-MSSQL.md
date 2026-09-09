# Chequeos sintéticos — cliente Microsoft SQL Server

Script: **`monitoreo/synthetic-check-mssql.sh`**

Conecta con **`sqlcmd`** al SQL Server del cliente. **No usa Podman ni PostgreSQL.**

---

## Configuración (`config.env`)

```bash
DB_TYPE=mssql
KC_SERVER=https://sso.ejemplo.local/auth
KC_REALM=mi-realm

MSSQL_HOST=sqlserver.ejemplo.local
MSSQL_PORT=1433
MSSQL_DB=rhsso
MSSQL_USER=rhsso_read
MSSQL_PASSWORD='***'
MSSQL_TRUST_CERT=true    # Azure / TLS

# Opcional — login sintético
SYNTH_CLIENT_ID=mi-app
SYNTH_USER=usuario.prueba
SYNTH_PASSWORD='***'

# Opcional — balanceador
LB_URL=https://sso.ejemplo.local/auth
```

## Ejecutar

```bash
cd ejecucion
./monitoreo/synthetic-check-mssql.sh
```

## Capas

| Capa | Qué hace el script | Equivalente manual |
|------|-------------------|-------------------|
| 1 | Conexión BD | `sqlcmd … -Q "SELECT 1"` |
| 2 | Realm en tabla `realm` | `SELECT 1 FROM realm WHERE name = '…'` |
| 3 | HTTP `KC_SERVER/realms/master` | `curl -w '%{http_code}'` |
| 4 | HTTP `LB_URL/…` (si está definido) | Igual vía URL pública |
| 5 | Token OIDC (si `SYNTH_*` definidos) | `POST …/protocol/openid-connect/token` |

## Salida del script

**Todo OK** (con `LB_URL` y `SYNTH_*`):

```text
OK   SQL Server sqlserver.ejemplo.local:1433/rhsso
OK   Realm en BD (mi-realm)
OK   RHSSO https://sso.ejemplo.local/auth/realms/master
OK   Balanceador https://sso.ejemplo.local/auth/realms/master
OK   Login OIDC (mi-realm/usuario.prueba)
---
Passed: 5  Failed: 0
```

**Mínimo** (sin balanceador ni login):

```text
OK   SQL Server sqlserver.ejemplo.local:1433/rhsso
OK   Realm en BD (mi-realm)
OK   RHSSO https://sso.ejemplo.local/auth/realms/master
SKIP Login OIDC — defina SYNTH_USER, SYNTH_PASSWORD y SYNTH_CLIENT_ID para habilitar
---
Passed: 3  Failed: 0
```

Código de salida: `0` si `Failed: 0`; distinto de `0` si hubo algún `FAIL`.

## Ejemplos manuales y salida por capa

### Capa 1 — Conectividad

```bash
sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" \
  -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}" \
  -d "${MSSQL_DB}" -Q "SELECT 1 AS ok"
```

Con certificado (igual que el reporte de análisis):

```bash
sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -C \
  -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}" \
  -d "${MSSQL_DB}" -Q "SELECT 1 AS ok"
```

**OK:**

```text
ok
-----------
          1

(1 rows affected)
```

**FAIL:**

```text
Sqlcmd: Error: Microsoft ODBC Driver 17 for SQL Server : Login timeout expired.
```

**En script:** `OK SQL Server …` · `FAIL SQL Server …`

### Capa 2 — Realm en BD

```bash
sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" \
  -U "${MSSQL_USER}" -P "${MSSQL_PASSWORD}" \
  -d "${MSSQL_DB}" -Q "SELECT name FROM realm WHERE name = 'mi-realm'"
```

**OK:**

```text
name
------------
mi-realm

(1 rows affected)
```

**FAIL:** `(0 rows affected)`

**En script:** `OK Realm en BD (mi-realm)` · `FAIL Realm en BD (mi-realm)`

### Capa 3 — RHSSO

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "${KC_SERVER}/realms/master"
```

**OK:** `200`

**FAIL:** `000` · `404` · `502`

**En script:** `OK RHSSO ${KC_SERVER}/realms/master` · `FAIL RHSSO …`

### Capa 4 — Balanceador (opcional)

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "${LB_URL}/realms/master"
```

**OK:** `200`

**FAIL:** `502` · `503` · `000`

**En script:** `OK Balanceador ${LB_URL}/realms/master` · `FAIL Balanceador …`

### Capa 5 — Login

```bash
curl -sf \
  -d "client_id=${SYNTH_CLIENT_ID}" \
  -d "username=${SYNTH_USER}" \
  -d "password=${SYNTH_PASSWORD}" \
  -d 'grant_type=password' \
  "${KC_SERVER}/realms/${KC_REALM}/protocol/openid-connect/token" \
  | jq -e '.access_token != null'
```

**OK:** salida vacía, exit `0`; JSON con `access_token`.

**FAIL (ejemplos):**

```json
{"error":"invalid_grant","error_description":"Invalid user credentials"}
```

**En script:** `OK Login OIDC (mi-realm/usuario.prueba)` · `FAIL Login OIDC …`

## SPI / federación / LDAP

La capa 5 valida el **flujo completo de autenticación** en el entorno del cliente. Si los usuarios vienen de LDAP o un SPI propio, use credenciales de un usuario de prueba acordado con operaciones.

El paquete `ejecucion/` **no incluye** despliegue de SPI (eso es específico de cada instalación).

## Relación con análisis SQL

Reporte de clients en uso:

```bash
DB_TYPE=mssql ./analysis/client-usage-report.sh
```

Usa el mismo `sqlcmd`, `MSSQL_*` y `client-usage-report_mssql.sql`.

## Recorrido típico

```text
GET LB/realms/master  →  RHSSO  →  JDBC  →  SQL Server (MSSQL_HOST)
POST /token           →  RHSSO  →  usuarios locales / LDAP / SPI del cliente
```
