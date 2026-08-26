# RHSSO — Paquete de ejecución (cliente)

Entregable para el cliente: **solo esta carpeta `ejecucion/`** (más `config.env`).

## Configuración inicial

```bash
cd ejecucion
cp config.env.example config.env
# Editar: RHSSO_HOME, KC_*, PG_* o MSSQL_*
```

Todas las rutas usan **`${RHSSO_HOME}`** (por defecto `/opt/MW/rhsso/rh-sso-7.6.12`), no rutas fijas en los scripts.

| Variable | Descripción |
|----------|-------------|
| `RHSSO_HOME` | Instalación RHSSO (contiene `bin/kcadm.sh`, `bin/standalone.sh`) |
| `KC_SERVER` | URL base (`http://host:8080/auth`) |
| `KC_REALM` | Realm a exportar |
| `KC_ADMIN` / `KC_ADMIN_PASSWORD` | Credenciales admin |
| `DB_TYPE` | `pg` o `mssql` para el reporte de clients |
| `PG_*` | PostgreSQL (ej. podman) |
| `MSSQL_*` | SQL Server |

---

## Objetivo 1 — Export completo

| Requerimiento | Partial¹ | Offline KCS² |
|---------------|----------|--------------|
| Realm + **clientId** + conf | Sí | Sí |
| **Browser Flow** | Sí | Sí |
| **Client scopes** | Sí | Sí |
| Usuarios | No | Sí |

¹ `./export/export-realm-partial.sh` — RHSSO **en marcha**  
² `./export/export-realm-offline.sh` — RHSSO **parado** ([KCS 3999401](https://access.redhat.com/solutions/3999401))

```bash
# Partial
export KC_REALM=mi-realm
./export/export-realm-partial.sh
./export/verify-export-json.sh exports/partial/mi-realm-*.json mi-realm

# Offline
${RHSSO_HOME}/bin/jboss-cli.sh --connect --controller=${JBOSS_CONTROLLER} command=:shutdown
./export/export-realm-offline.sh mi-realm
cd ${RHSSO_HOME}/bin && ./standalone.sh
```

---

## Objetivo 2 — clientId en uso / no en uso

```bash
# PostgreSQL (podman) — ejemplo de este lab
DB_TYPE=pg ./analysis/client-usage-report.sh

# Microsoft SQL Server
DB_TYPE=mssql MSSQL_PASSWORD='***' ./analysis/client-usage-report.sh
```

### PostgreSQL (podman)

```bash
podman exec -i ${PG_CONTAINER} psql -U ${PG_USER} -d ${PG_DB} \
  < analysis/client-usage-report_pg.sql
```

### Microsoft SQL Server (sqlcmd)

```bash
sqlcmd -S ${MSSQL_HOST},${MSSQL_PORT} -U ${MSSQL_USER} -P "${MSSQL_PASSWORD}" \
  -d ${MSSQL_DB} -i analysis/client-usage-report_mssql.sql
# Azure / certificado: MSSQL_TRUST_CERT=true en config.env
```

| `usage_status` | Significado |
|----------------|-------------|
| `IN_USE` | Sesión, token offline o evento de usuario |
| `SYSTEM_CLIENT` | Client de plantilla Keycloak |
| `NO_ACTIVITY_DETECTED` | Sin actividad medible |

---

## Eventos de usuario — precaución de performance

Para mejorar el reporte (columna `user_events_total`) hace falta guardar eventos, pero **no activar “todo”**:

- Red Hat documenta que el registro masivo de eventos impacta rendimiento y almacenamiento ([KCS / best practices — event logging](https://access.redhat.com/solutions/7037597)).
- `eventsExpiration=604800` son **7 días** (segundos); pasado ese plazo se purgan de la BD.
- En la consola: *Realm Settings → Events → User events* → **Save events ON**, elegir solo los tipos necesarios (p. ej. `LOGIN`, `LOGOUT`, `CLIENT_LOGIN`, `CODE_TO_TOKEN`, `REFRESH_TOKEN`).
- Evitar guardar todos los tipos si no son requeridos para auditoría.

Ejemplo acotado con `kcadm` (sustituir `<realm>`):

```bash
${RHSSO_HOME}/bin/kcadm.sh update realms/<realm> -r <realm> \
  -s eventsEnabled=true \
  -s eventsExpiration=604800 \
  -s 'enabledEventTypes=["LOGIN","LOGOUT","CLIENT_LOGIN","CODE_TO_TOKEN","REFRESH_TOKEN"]'
```

Sin eventos, el SQL sigue funcionando con sesiones y tokens offline en tiempo real.

---

## Objetivo 3 — Chequeos sintéticos (monitoreo E2E)

Scripts y documentación separados por base de datos. **No usan Podman** — el cliente conecta a su PostgreSQL o SQL Server nativo.

| BD | Script | Documentación |
|----|--------|---------------|
| PostgreSQL | `./monitoreo/synthetic-check-pg.sh` | [monitoreo/CHEQUEOS-SINTETICOS-PG.md](monitoreo/CHEQUEOS-SINTETICOS-PG.md) |
| SQL Server | `./monitoreo/synthetic-check-mssql.sh` | [monitoreo/CHEQUEOS-SINTETICOS-MSSQL.md](monitoreo/CHEQUEOS-SINTETICOS-MSSQL.md) |

Índice: [monitoreo/README.md](monitoreo/README.md). El lab interno (Podman + HAProxy + SPI) está en `setup/monitoreo/`.

---

## Limpieza de salidas

```bash
./clean-exports.sh
```

Borra `exports/partial/*`, `exports/offline/*`, `exports/analysis/*`.
