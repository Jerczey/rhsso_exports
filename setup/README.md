# Setup y pruebas (uso interno)

No entregar al cliente. Usar para preparar laboratorio y validar `ejecucion/`.

## Restaurar entorno tras cambio de OS

```bash
# 1) PostgreSQL lab — Red Hat catalog image, puerto 5433 (pg-primary-site-a offline en 5432)
./podman/start-postgres.sh

# 2) Configuración de ejecución
cp ../ejecucion/config.env.example ../ejecucion/config.env

# 3) Arrancar RHSSO 7.6 (JDK 11 en /opt/MW/rhsso/jdk, TZ America/Santiago)
./start-rhsso.sh

# 4) HAProxy lab (separado de rhbk-mc kc-haproxy-lb) — front :9080 -> RHSSO :8080
./podman/start-haproxy.sh

# 5) Hosts + SPI + chequeo sintético
./configure-hosts.sh
./deploy-user-storage-spi.sh
./configure-spi-realm.sh
./monitoreo/synthetic-check-pg-lab.sh
```

### Detener todo el lab

```bash
./stop-stack.sh
# o por componente:
./stop-rhsso.sh
./podman/stop-haproxy.sh
./podman/stop-postgres.sh
```

No arranca ni detiene `pg-primary-site-a` (rhbk-mc en :5432).

Notas (regla `redhat-stack.mdc` — Red Hat first):
- **PostgreSQL**: `registry.access.redhat.com/hi/postgresql:17` en **127.0.0.1:5433**
- **rhbk-mc** `pg-primary-site-a` debe permanecer **offline** (puerto 5432 reservado)
- **Timezone**: `America/Santiago` en PG, JVM (`standalone.conf`) y JDBC
- Datos PG: `/opt/MW/rhsso/pg_data/rhsso-rhel17`
- `standalone.sh`: `JAVA_HOME=/opt/MW/rhsso/jdk/jdk-11.0.32+9`

## Datos de lab

Realms: `master`, `test-case`, `export-lab`, `bench-realm-1` … `bench-realm-5`  
Admin master: `admin` / `admin`  
SPI test user: `tbrady` / `superbowl` (readonly-property-file-random)

## SPI user-storage-random (RHSSO 7.6)

Código portado a `redhat-sso-quickstarts/user-storage-simple` (sin OpenTelemetry; delay aleatorio en `isValid`).

```bash
./deploy-user-storage-spi.sh
./configure-spi-realm.sh
```

## Monitoreo E2E

- Lab: [monitoreo/CHEQUEOS-SINTETICOS-PG-LAB.md](monitoreo/CHEQUEOS-SINTETICOS-PG-LAB.md) + `synthetic-check-pg-lab.sh`
- Cliente: [../ejecucion/monitoreo/](../ejecucion/monitoreo/) (PG y MSSQL, sin Podman)
