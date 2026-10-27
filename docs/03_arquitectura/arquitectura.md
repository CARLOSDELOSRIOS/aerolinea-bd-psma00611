# Arquitectura de la solución

## 1. Vista general

```
             ┌──────────────────────────── Equipo (laptop Windows) ────────────────────────────┐
             │  SSMS (administración)      Python 3 + pyodbc + pandas (aplicación reproducible) │
             │        │                         │  python -m aerolinea <comando>                │
             └────────┼─────────────────────────┼───────────────────────────────────────────────┘
                      │ TDS cifrado (ODBC 18)   │
        ┌─────────────▼─────────────────────────▼──────────────┐      ┌──────────────────────────┐
        │  SQL Server local (MSSQLSERVER) · base AerolineaDB    │ ───► │ Azure SQL Database       │
        │  desarrollo, pruebas y carga sintética                │      │ (requisito de nube;      │
        └───────────────────────────────────────────────────────┘      │  mismo código T-SQL)     │
                                                                        └──────────────────────────┘
```

- **Motor de base de datos** (SQL Server / Azure SQL Database): guarda los datos y **garantiza** las reglas de negocio (restricciones, triggers, procedimientos, transacciones).
- **SSMS**: herramienta de administración y de ejecución manual de scripts; no forma parte de la lógica.
- **Python** (`src/aerolinea`): despliegue ordenado de scripts, generación y carga de datos sintéticos, consultas parametrizadas, exportación a CSV, gráficos, pruebas de concurrencia y documentación generada desde el catálogo.

## 2. Organización de la base de datos por esquemas

| Esquema | Contenido | Quién lo usa |
|---|---|---|
| `ref` | Catálogos y referencia: países, estados, zonas horarias, localizaciones, aeropuertos, cabinas, modelos de avión, métodos de pago, estados y transiciones, motivos, parámetros, mensajes de error | Todas las capas (lectura) |
| `ops` | Operación: configuraciones de asientos, aviones, rutas, programaciones, vuelos, inventario por cabina, tripulación | Operaciones |
| `rh` | Departamentos, cargos y empleados | Operaciones y ventas (vendedores) |
| `ven` | Personas, clientes, compras, tarifas, descuentos, políticas de cancelación, tiquetes, pagos, reembolsos | Ventas |
| `rpt` | Vistas y procedimientos de reporte; única puerta del analista | Análisis |
| `aud` | Auditoría de cambios de estado | Control |
| `adm` | Registro de despliegue de scripts | Administración |
| `stg` | Área de carga masiva (sin restricciones) | Carga sintética |
| `tst` | Escenarios y pruebas automatizadas | Pruebas |

Separar por esquemas permite conceder permisos por área (`GRANT SELECT ON SCHEMA::rpt`) y deja visible la frontera entre datos operativos y analíticos.

## 3. Dónde vive cada regla (y por qué)

Orden de preferencia aplicado: **restricción declarativa → trigger → procedimiento → verificación por consulta**.

| Mecanismo | Se usa para | Ejemplos | Razón |
|---|---|---|---|
| PK, FK, UNIQUE, CHECK, índice único filtrado, columna calculada | Reglas de una fila o de unicidad | RN-01, RN-11 (CHECK de capacidad), RN-12 (asiento único), RN-22 (precio final) | El motor las aplica siempre, a cualquier cliente y en cualquier carga; son autodocumentadas y el optimizador las aprovecha |
| Trigger `AFTER` set-based | Reglas entre filas o tablas que deben cumplirse aunque se escriba sin pasar por un procedimiento | Transiciones de estado, solapes de avión y tripulación, tarifa vigente, inventario, inmutabilidad | Una regla que solo vive en un procedimiento se puede saltar con un `INSERT` directo o una carga masiva |
| Procedimiento almacenado | Orquestar operaciones de varios pasos y devolver mensajes de negocio | Emitir, pagar, cancelar, generar vuelos | Una unidad transaccional con parámetros tipados y permisos por `EXECUTE` |
| Consulta de verificación | Propiedades globales que conviene medir, no bloquear | Conciliación de inventario (RN-40), identidad de caja, horas de tripulación (Q18, Q19) | Detecta errores que ningún mecanismo anterior cubre |

Alternativas consideradas:

- *Toda la lógica en la aplicación (Python)*: descartada; la base quedaría expuesta a cualquier otro cliente (SSMS, cargas, otras aplicaciones) y la concurrencia sería más difícil de controlar.
- *Toda la lógica en procedimientos*: descartada como única barrera; una carga masiva o una sentencia directa las evitaría. Los procedimientos se mantienen para la orquestación y los mensajes.
- *Restricciones `CHECK` con funciones escalares definidas por el usuario* para reglas entre tablas: descartadas; se evalúan fila a fila, no ven el estado de otras transacciones de forma segura y degradan las cargas.

## 4. Tiempo y zonas horarias

- Horarios de vuelo en `datetimeoffset(0)` **con el desfase local del aeropuerto** (salida con el de origen, llegada con el de destino). Así se conserva la hora local que ve el pasajero y la conversión a UTC es exacta, incluso con llegadas al día siguiente y con el cambio de horario del 1 de noviembre de 2026.
- La conversión usa `AT TIME ZONE` con nombres de zona de Windows (`Eastern Standard Time`, `US Mountain Standard Time` para Phoenix, `Hawaiian Standard Time` para Honolulu), disponibles tanto en SQL Server como en Azure SQL Database.
- Sellos de tiempo transaccionales (compra, pago, reembolso) en UTC (`datetime2(0)`, sufijo `_utc`).
- Día de la semana ISO calculado con `DATEDIFF(DAY, '19000101', fecha) % 7 + 1`, que no depende de `SET DATEFIRST` ni del idioma de la sesión.

## 5. Flujo de datos sintéticos

```
generador.py (semilla 20261106) ─► CSV en data/sintetico + manifiesto con SHA-256
          │                                   (reproducibles bit a bit)
          └─► stg.* (inserción rápida en lotes, fast_executemany)
                 └─► stg.usp_aplicar_carga_sintetica  (UNA transacción, todas las reglas activas)
                          └─► ref / ops / rh / ven / aud
```

La carga no desactiva restricciones ni triggers: si un dato sintético viola una regla, la transacción completa se revierte. Que la carga termine es en sí una prueba de coherencia de los datos (ver `docs/06_pruebas`).

## 6. Componentes de Python

| Módulo | Responsabilidad |
|---|---|
| `config.py` | Lee la configuración de `.env` o variables de entorno; valida que Azure use cifrado y validación de certificado |
| `db.py` | Cadena de conexión (ODBC 18/17), autenticación de Windows, SQL o Microsoft Entra, transacciones, traducción de errores, lectura de todos los conjuntos de resultados |
| `sql_script.py` | Divide scripts por `GO` del lado del cliente respetando comentarios y cadenas |
| `despliegue.py` | Verificación del entorno y ejecución ordenada de scripts |
| `generador.py`, `carga.py` | Datos sintéticos deterministas y carga |
| `consultas.py` | Catálogo Q01–Q20 con parámetros enlazados, CSV y manifiesto |
| `graficos.py` | Figuras a partir de los CSV |
| `operaciones.py` | Invocación de procedimientos (emitir, pagar, cancelar) y demostración transaccional |
| `pruebas.py` | Pruebas T-SQL y de concurrencia con hilos |
| `documentar.py` | Diccionario de datos, descripciones `MS_Description` y diagramas físicos desde el catálogo |
| `cli.py` | Interfaz de línea de comandos (`python -m aerolinea …`) |
