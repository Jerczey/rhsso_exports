# Setup y pruebas (uso interno)

No entregar al cliente. Usar para preparar laboratorio y validar `ejecucion/`.

```bash
# 1) Configurar ejecucion primero
cp ../ejecucion/config.env.example ../ejecucion/config.env

# 2) Crear datos de prueba
./setup-test-realm.sh
./setup-five-realms.sh

# 3) Pruebas funcionales
./pruebas-funcionales/run-functional-tests.sh
```

Salidas de pruebas: `setup/pruebas-funcionales/runs/<timestamp>/`
