# Monitoreo — paquete cliente

Chequeos sintéticos para el entorno del **cliente** (sin Podman). Elegir según la base de datos configurada en `config.env`.

| Base de datos | Script | Documentación |
|---------------|--------|---------------|
| PostgreSQL | `./monitoreo/synthetic-check-pg.sh` | [CHEQUEOS-SINTETICOS-PG.md](CHEQUEOS-SINTETICOS-PG.md) |
| Microsoft SQL Server | `./monitoreo/synthetic-check-mssql.sh` | [CHEQUEOS-SINTETICOS-MSSQL.md](CHEQUEOS-SINTETICOS-MSSQL.md) |

```bash
cd ejecucion
cp config.env.example config.env
# editar KC_SERVER, PG_* o MSSQL_*, realm, usuarios de prueba

# PostgreSQL
./monitoreo/synthetic-check-pg.sh

# SQL Server
./monitoreo/synthetic-check-mssql.sh
```

El laboratorio interno (Podman + HAProxy + SPI) está en [../../setup/monitoreo/](../../setup/monitoreo/).

## Variables comunes (login opcional)

En `config.env` (opcional, para capa de login):

| Variable | Descripción |
|----------|-------------|
| `SYNTH_REALM` | Realm a probar (default: `KC_REALM`) |
| `SYNTH_CLIENT_ID` | Client OIDC con *Direct access grants* |
| `SYNTH_USER` / `SYNTH_PASSWORD` | Usuario de prueba (local o federado) |
| `LB_URL` | URL del balanceador (si aplica), p. ej. `https://sso/cliente/auth` |

Si no se definen `SYNTH_*`, el script valida BD + HTTP y omite el login.
