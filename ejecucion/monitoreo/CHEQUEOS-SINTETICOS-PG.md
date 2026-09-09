# Chequeos sintéticos — cliente PostgreSQL

Script: **`monitoreo/synthetic-check-pg.sh`**

Conecta con **`psql`** al PostgreSQL del cliente (`PG_HOST`, `PG_PORT`). Si no hay `psql` en el host y `PG_CONTAINER` está definido, el script usa **`podman exec`** (útil en lab).

---

## Configuración (`config.env`)

```bash
KC_SERVER=https://sso.ejemplo.local/auth
KC_REALM=mi-realm

PG_HOST=db.ejemplo.local
PG_PORT=5432
PG_USER=rhsso_read
PG_PASSWORD='***'
PG_DB=rhsso

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
./monitoreo/synthetic-check-pg.sh
```

## Capas

| Capa | Qué hace el script | Equivalente manual |
|------|-------------------|-------------------|
| 1 | Conexión BD | `psql … -c "SELECT 1"` |
| 2 | Realm en tabla `realm` | `SELECT 1 FROM realm WHERE name='…'` |
| 3 | HTTP `KC_SERVER/realms/master` | `curl -w '%{http_code}'` |
| 4 | HTTP `LB_URL/…` (si está definido) | Igual vía URL pública |
| 5 | Token OIDC (si `SYNTH_*` definidos) | `POST …/protocol/openid-connect/token` |

## Salida del script

**Todo OK** (con `LB_URL` y `SYNTH_*`):

```text
OK   PostgreSQL db.ejemplo.local:5432/rhsso
OK   Realm en BD (mi-realm)
OK   RHSSO https://sso.ejemplo.local/auth/realms/master
OK   Balanceador https://sso.ejemplo.local/auth/realms/master
OK   Login OIDC (mi-realm/usuario.prueba)
---
Passed: 5  Failed: 0
```

**Mínimo** (sin balanceador ni login):

```text
OK   PostgreSQL db.ejemplo.local:5432/rhsso
OK   Realm en BD (mi-realm)
OK   RHSSO https://sso.ejemplo.local/auth/realms/master
SKIP Login OIDC — defina SYNTH_USER, SYNTH_PASSWORD y SYNTH_CLIENT_ID para habilitar
---
Passed: 3  Failed: 0
```

**Con fallos** (ejemplo: BD caída, RHSSO arriba):

```text
FAIL PostgreSQL 127.0.0.1:5433/rhsso
FAIL Realm en BD (test-case)
OK   RHSSO http://127.0.0.1:8080/auth/realms/master
SKIP Login OIDC — defina SYNTH_USER, SYNTH_PASSWORD y SYNTH_CLIENT_ID para habilitar
---
Passed: 1  Failed: 2
```

Código de salida: `0` si `Failed: 0`; distinto de `0` si hubo algún `FAIL`.

## Ejemplos manuales y salida por capa

### Capa 1 — Conectividad

```bash
PGPASSWORD="${PG_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
  -U "${PG_USER}" -d "${PG_DB}" -c "SELECT 1 AS ok"
```

**OK:**

```text
 ok
----
  1
(1 row)
```

**FAIL:**

```text
psql: error: connection to server at "127.0.0.1", port 5433 failed: Connection refused
```

**En script:** `OK PostgreSQL …` · `FAIL PostgreSQL …`

### Capa 2 — Realm en BD

```bash
PGPASSWORD="${PG_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
  -U "${PG_USER}" -d "${PG_DB}" -tAc \
  "SELECT 1 FROM realm WHERE name='mi-realm'"
```

**OK:** `1`

**FAIL:** (sin salida) o error de conexión

**En script:** `OK Realm en BD (mi-realm)` · `FAIL Realm en BD (mi-realm)`

### Capa 3 — RHSSO

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "${KC_SERVER}/realms/master"
```

**OK:** `200`

**FAIL:** `000` (sin respuesta) · `404` · `502`

**En script:** `OK RHSSO ${KC_SERVER}/realms/master` · `FAIL RHSSO …`

### Capa 4 — Balanceador (opcional)

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "${LB_URL}/realms/master"
```

**OK:** `200`

**FAIL:** `502` · `503` · `000`

**En script:** `OK Balanceador ${LB_URL}/realms/master` · `FAIL Balanceador …`

### Capa 5 — Login (usuario local o federado / SPI del cliente)

```bash
curl -sf \
  -d "client_id=${SYNTH_CLIENT_ID}" \
  -d "username=${SYNTH_USER}" \
  -d "password=${SYNTH_PASSWORD}" \
  -d 'grant_type=password' \
  "${KC_SERVER}/realms/${KC_REALM}/protocol/openid-connect/token" \
  | jq -e '.access_token != null'
```

**OK:** salida vacía, exit `0`; el JSON incluye token:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUI...",
  "expires_in": 300,
  "token_type": "Bearer"
}
```

**FAIL (ejemplos):**

```json
{"error":"invalid_grant","error_description":"Invalid user credentials"}
```

```json
{"error":"unauthorized_client","error_description":"Client not allowed for direct access grants"}
```

**En script:** `OK Login OIDC (mi-realm/usuario.prueba)` · `FAIL Login OIDC …`

## SPI / federación

Si el cliente usa **User Storage SPI** (LDAP, properties, custom), la capa 5 debe usar un **usuario que exista en esa federación**. El script no despliega SPI; solo comprueba que el login devuelve token.

Errores frecuentes: `unauthorized_client` (direct grant off), `invalid_grant` (usuario/SPI/federación).

## Relación con análisis SQL

Reporte de clients en uso: `./analysis/client-usage-report.sh` con `DB_TYPE=pg` (mismas credenciales PG).
