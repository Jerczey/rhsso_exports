# Chequeos sintéticos — laboratorio PostgreSQL (Podman)

Documentación del script **`synthetic-check-pg-lab.sh`**. Solo aplica al lab interno con contenedor Podman, HAProxy y SPI de prueba.

Para el **cliente** (PostgreSQL o SQL Server sin Podman): [../../ejecucion/monitoreo/README.md](../../ejecucion/monitoreo/README.md).

---

## Qué valida

| Capa | Comando equivalente | OK |
|------|---------------------|-----|
| 1. Contenedor PG | `podman exec my-postgres pg_isready …` | `accepting connections` |
| 2. Realm en BD | `psql` vía Podman → `SELECT 1 FROM realm …` | `1` |
| 3. RHSSO directo | `GET http://127.0.0.1:8080/auth/realms/master` | HTTP `200` |
| 4. HAProxy lab | `GET http://127.0.0.1:9080/auth/realms/master` | HTTP `200` |
| 5. Login SPI | `POST …/token` (direct grant) | JSON con `access_token` |

## Ejecutar

```bash
cd setup
./monitoreo/synthetic-check-pg-lab.sh
# o: ./monitoreo/synthetic-check.sh
```

Prerrequisitos: ver [../README.md](../README.md) (`start-postgres.sh`, `start-rhsso.sh`, `start-haproxy.sh`, SPI).

## Variables (lab)

| Variable | Default | Uso |
|----------|---------|-----|
| `PG_CONTAINER` | `my-postgres` | Capas 1–2 |
| `PG_USER` / `PG_DB` | `yurek` / `rhsso` | Capas 1–2 |
| `DIRECT_URL` | `http://127.0.0.1:8080/auth` | Capas 3, 5 |
| `LB_URL` | `http://127.0.0.1:9080/auth` | Capa 4 |
| `SYNTH_REALM` | `test-case` | Capas 2, 5 |
| `SYNTH_CLIENT_ID` | `account` | Capa 5 |
| `SPI_USER` / `SPI_PASS` | `tbrady` / `superbowl` | Capa 5 |

## SPI en el lab

Provider **`readonly-property-file-random`**: usuarios en `users.properties` del JAR desplegado. El chequeo 5 confirma que la federación responde, no solo que RHSSO esté arriba.

Configuración:

```bash
./deploy-user-storage-spi.sh
./configure-spi-realm.sh
```

## Ejemplos manuales

### Capa 1

```bash
podman exec my-postgres pg_isready -U yurek -d rhsso
```

### Capa 2

```bash
podman exec my-postgres psql -U yurek -d rhsso -tAc \
  "SELECT 1 FROM realm WHERE name='test-case'"
```

### Capa 3

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  http://127.0.0.1:8080/auth/realms/master
```

### Capa 4

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  http://127.0.0.1:9080/auth/realms/master
```

### Capa 5 (SPI)

```bash
curl -sf \
  -d 'client_id=account' \
  -d 'username=tbrady' \
  -d 'password=superbowl' \
  -d 'grant_type=password' \
  http://127.0.0.1:8080/auth/realms/test-case/protocol/openid-connect/token \
  | jq -e '.access_token != null'
```

## Recorrido

```text
:9080 → HAProxy → :8080 RHSSO → JDBC :5433 → my-postgres (Red Hat PG 17)
POST /token → SPI readonly-property-file-random → users.properties
```
