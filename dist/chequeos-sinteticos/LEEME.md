# Chequeos sintéticos RHSSO 7.6 — paquete cliente

Herramientas para validar de punta a punta: **base de datos → RHSSO → balanceador (opcional) → login OIDC**.

Elija el script según su base de datos. PostgreSQL: `psql` nativo, o fallback `podman exec` si define `PG_CONTAINER`.

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `monitoreo/synthetic-check-pg.sh` | PostgreSQL (`psql` o Podman con `PG_CONTAINER`) |
| `monitoreo/synthetic-check-mssql.sh` | Microsoft SQL Server (`sqlcmd`) |
| `monitoreo/CHEQUEOS-SINTETICOS-PG.md` | Documentación y ejemplos `curl` / `psql` |
| `monitoreo/CHEQUEOS-SINTETICOS-MSSQL.md` | Documentación y ejemplos `curl` / `sqlcmd` |
| `monitoreo/README.md` | Índice rápido |
| `config.env.ejemplo.txt` | Variables de monitoreo para `config.env` |

## Requisitos

- Paquete `ejecucion/` de RHSSO exports (incluye `lib/env.sh` y `config.env`)
- `curl`, `jq`
- PostgreSQL: cliente `psql` (o Podman + `PG_CONTAINER` en lab) y acceso a la BD RHSSO
- SQL Server: `sqlcmd` y acceso a la BD RHSSO

## Instalación

1. Copiar la carpeta `monitoreo/` dentro de su `ejecucion/` existente:

   ```bash
   cp -r monitoreo /ruta/a/ejecucion/
   chmod +x /ruta/a/ejecucion/monitoreo/*.sh
   ```

2. Añadir en `ejecucion/config.env` las variables de `config.env.ejemplo.txt` (ajustar valores).

3. Ejecutar:

   ```bash
   cd ejecucion

   # PostgreSQL
   ./monitoreo/synthetic-check-pg.sh

   # Microsoft SQL Server
   ./monitoreo/synthetic-check-mssql.sh
   ```

Salida esperada: líneas `OK` / `FAIL` y resumen `Passed: N  Failed: 0`. Código de salida `0` si todo pasó.

## Capas que valida

1. Conectividad a la base de datos
2. Realm presente en tabla `realm`
3. HTTP `KC_SERVER/realms/master` → 200
4. HTTP vía `LB_URL` (si está definido)
5. Token OIDC con usuario de prueba (si `SYNTH_*` está configurado)

## Nota

Este paquete es para **entornos cliente**. El laboratorio interno (Podman, HAProxy, SPI) no se incluye aquí.

Documentación general del paquete de ejecución: `ejecucion/README.md`.
