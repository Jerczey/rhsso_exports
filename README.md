# rhsso_exports

Herramientas para **Red Hat Single Sign-On 7.6** (Keycloak 18 / WildFly):

1. **Exportar** de forma completa: realm + **clientId** + configuración + **Browser Flow** + **client scopes** (partial u offline KCS).
2. **Detectar** qué **clientId** están en uso y cuáles no, vía reporte SQL (PostgreSQL o Microsoft SQL Server).

## Estructura

| Carpeta | Audiencia | Contenido |
|---------|-----------|-----------|
| **`ejecucion/`** | Cliente | Scripts, SQL, `config.env` — **entregar solo esto** |
| **`setup/`** | Interno | Creación de realms de lab + pruebas funcionales |

```
rhsso_exports/
├── ejecucion/          ← paquete de ejecución
│   ├── config.env.example
│   ├── lib/env.sh
│   ├── export/
│   ├── analysis/       (client-usage-report_pg.sql | _mssql.sql)
│   ├── monitoreo/      (synthetic-check-pg | -mssql + docs cliente)
│   └── exports/
└── setup/
    ├── setup-test-realm.sh
    ├── setup-five-realms.sh
    ├── monitoreo/      (synthetic-check-pg-lab + doc lab)
    └── pruebas-funcionales/
```

## Inicio rápido (cliente)

```bash
cd ejecucion
cp config.env.example config.env
# editar RHSSO_HOME, KC_*, DB_TYPE, credenciales

./export/export-realm-partial.sh
DB_TYPE=pg ./analysis/client-usage-report.sh
```

Documentación completa: [ejecucion/README.md](ejecucion/README.md)
