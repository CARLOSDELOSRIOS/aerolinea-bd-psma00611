# Control de concurrencia

## 1. Problemas que se deben evitar

| Riesgo | Escenario | Consecuencia |
|---|---|---|
| Sobreventa | Dos agentes venden a la vez la última plaza VIP de un vuelo | 13 pasajeros para 12 asientos |
| Asiento duplicado | Dos clientes eligen el 12A del mismo vuelo en el mismo segundo | Dos tarjetas de embarque para un asiento |
| Sobrecobro | Dos pagos simultáneos del saldo total de un tiquete | Se cobra dos veces |
| Escritura sesgada (*write skew*) | Dos transacciones validan la misma regla con datos que la otra todavía no ha confirmado (p. ej., asignar el mismo avión a dos vuelos solapados) | Ambas pasan la validación y el resultado conjunto viola la regla |

## 2. Nivel de aislamiento elegido

La base usa **READ COMMITTED con versiones de fila** (`READ_COMMITTED_SNAPSHOT ON`), que es el valor predeterminado de Azure SQL Database. Se activa también en local (`01_crear_base_datos_local.sql`) para que el comportamiento probado sea el mismo que en la nube.

- Ventaja: las lecturas (reportes, consultas del analista) no bloquean a las escrituras ni al revés.
- Riesgo: una lectura normal ve la última versión **confirmada**, no la que otra transacción está escribiendo. Por eso toda validación que decide si se puede escribir lee con **bloqueo** (`UPDLOCK`), lo que la convierte en una lectura de la versión actual que, además, espera a que la otra transacción termine.

Alternativas descartadas:

| Alternativa | Por qué no |
|---|---|
| `SERIALIZABLE` en todas las transacciones | Bloqueos de rango amplios, interbloqueos frecuentes en la carga y en ventas concurrentes; penaliza a todo el sistema para proteger unas pocas reglas |
| `SNAPSHOT` | Detecta conflictos de actualización, pero no evita la escritura sesgada entre filas distintas (cada transacción ve su instantánea) |
| Bloqueo optimista en la aplicación (`rowversion`) | Útil para edición interactiva (las tablas `vuelo` y `tiquete` tienen `version_fila` para ello), pero no basta para reglas que involucran varias filas |
| Bloqueos de aplicación (`sp_getapplock`) | Funcionan, pero quedan fuera del modelo de datos y son fáciles de olvidar en un camino de código nuevo |

## 3. Mecanismos concretos

### 3.1 Inventario: el semáforo `ops.vuelo_cabina`

Cada vuelo tiene una fila por cabina con `capacidad` y `plazas_ocupadas`. Al insertar o cambiar de estado un tiquete, el trigger `ven.trg_tiquete_reglas`:

1. Calcula el cambio neto de plazas por vuelo y cabina (un tiquete `RESERVADO`, `EMITIDO`, `USADO` o `NO_PRESENTADO` ocupa; `CANCELADO` o `VENCIDO` libera; lo define `ref.estado_tiquete.ocupa_inventario`).
2. Lee la fila de inventario con `UPDLOCK, ROWLOCK`: la segunda venta concurrente del mismo vuelo y cabina **espera** a que la primera confirme o revierta.
3. Si no hay plaza, lanza el error 50020; si hay, actualiza el contador.
4. La restricción `ck_vuelo_cabina_capacidad CHECK (plazas_ocupadas <= capacidad)` es la última barrera: aunque alguien desactivara el paso 3, el motor rechaza la sobreventa.

Ventas de vuelos distintos o de cabinas distintas no se bloquean entre sí (bloqueo de una sola fila).

### 3.2 Asientos: índice único filtrado

```sql
CREATE UNIQUE INDEX ux_tiquete_vuelo_asiento ON ven.tiquete (id_vuelo, codigo_asiento)
WHERE codigo_asiento IS NOT NULL AND codigo_estado IN ('RESERVADO','EMITIDO','USADO','NO_PRESENTADO');
```

Es una garantía declarativa: aunque dos transacciones intenten el mismo asiento a la vez, el motor solo admite una; la otra recibe el error 2601, que el procedimiento traduce a 50120 («asiento ocupado»). Los tiquetes cancelados quedan fuera del filtro y liberan el asiento.

La **asignación automática** (`ven.usp_asignar_asiento` sin asiento indicado) busca «el primer asiento libre». Con 30 sesiones simultáneas todas encontraban el mismo asiento y 24 fallaban (efecto manada). La corrección fue tomar primero el semáforo `ops.vuelo_cabina` con `UPDLOCK`: las asignaciones automáticas del mismo vuelo y cabina se serializan y cada una ve los asientos que tomaron las anteriores. Ver PC-04 en `docs/06_pruebas/hallazgos_y_correcciones.md`.

### 3.3 Pagos: bloqueo de la fila del tiquete

`ven.usp_registrar_pago` lee el tiquete con `UPDLOCK, ROWLOCK` antes de calcular el saldo; el trigger `ven.trg_pago_reglas` también bloquea los tiquetes afectados antes de sumar los pagos confirmados. Dos pagos simultáneos del mismo tiquete se ejecutan uno detrás del otro: el segundo ve el saldo actualizado y, si excede, se rechaza (50135 en el procedimiento o 50054 en el trigger).

### 3.4 Avión y tripulación: bloqueo del recurso padre

Para impedir que dos transacciones asignen el mismo avión (o el mismo tripulante) a vuelos solapados, el trigger bloquea primero la fila de `ops.avion` (o de `rh.empleado`) con `UPDLOCK` y después revisa la agenda ordenada del recurso con `LAG`. Bloquear el padre es más barato y más predecible que bloquear rangos de la tabla de vuelos.

### 3.5 Transacciones y errores

- Todos los procedimientos usan `SET XACT_ABORT ON` + `TRY/CATCH` + `THROW`: cualquier error revierte la operación completa.
- Un procedimiento abre transacción propia solo si no hay una abierta (`@@TRANCOUNT = 0`), lo que permite componer operaciones y probarlas dentro de transacciones que luego se revierten.
- Python usa conexiones con `autocommit` explícito; la demostración (`python -m aerolinea demo`) ejecuta el flujo completo en una transacción que se revierte por defecto.

## 4. Evidencia

Las pruebas de concurrencia (`src/aerolinea/pruebas.py`) lanzan hilos con una barrera para que las sesiones empiecen a la vez, cada una con su propia conexión:

| Prueba | Escenario | Resultado esperado |
|---|---|---|
| PC-01 | 40 sesiones compran la cabina VIP de 12 plazas | Exactamente 12 éxitos y 28 rechazos 50020; `plazas_ocupadas` = 12 |
| PC-02 | 20 sesiones piden el asiento 12A | Exactamente 1 éxito y 19 rechazos 50120 |
| PC-03 | 10 pagos simultáneos del saldo total de un tiquete | Exactamente 1 pago confirmado; el resto rechazado |
| PC-04 | 30 asignaciones automáticas de asiento simultáneas | 30 asientos distintos, ningún error |

Los resultados observados están en `evidence/<entorno>/resultados_pruebas.md`. Limitación: las pruebas se ejecutaron en un contenedor Linux con SQL Server 2022; deben repetirse en la laptop del equipo y en Azure SQL Database para tener evidencia en esos entornos.
