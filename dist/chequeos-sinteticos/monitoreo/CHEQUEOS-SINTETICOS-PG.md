# Chequeos sintéticos — cliente PostgreSQL

Script: **`monitoreo/synthetic-check-pg.sh`**

Conecta con **`psql`** al servidor PostgreSQL del cliente (`PG_HOST`, `PG_PORT`). **No usa Podman.**

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

## Ejemplos manuales

### Capa 1 — Conectividad

```bash
PGPASSWORD="${PG_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
  -U "${PG_USER}" -d "${PG_DB}" -c "SELECT 1 AS ok"
```

### Capa 2 — Realm en BD

```bash
PGPASSWORD="${PG_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
  -U "${PG_USER}" -d "${PG_DB}" -tAc \
  "SELECT 1 FROM realm WHERE name='mi-realm'"
```

### Capa 3 — RHSSO

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  "${KC_SERVER}/realms/master"
```

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

## SPI / federación

Si el cliente usa **User Storage SPI** (LDAP, properties, custom), la capa 5 debe usar un **usuario que exista en esa federación**. El script no despliega SPI; solo comprueba que el login devuelve token.

Errores frecuentes: `unauthorized_client` (direct grant off), `invalid_grant` (usuario/SPI/federación).

## Relación con análisis SQL

Reporte de clients en uso: `./analysis/client-usage-report.sh` con `DB_TYPE=pg` (mismas credenciales PG).
