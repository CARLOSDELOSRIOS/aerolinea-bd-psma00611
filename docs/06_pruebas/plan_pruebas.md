# Plan de pruebas y estado por entorno

## 1. Niveles de prueba

| Nivel | Qué verifica | Cómo | Dónde está |
|---|---|---|---|
| N1 · Unitarias de la aplicación | División de lotes por `GO`, validación de la configuración, escape de credenciales, traducción de errores, documentación y parámetros de las consultas, réplica de la política de reembolso | `pytest` (no necesita servidor) | `tests/` |
| N2 · Reglas de la base | Cada regla de negocio crítica se intenta violar y se comprueba el rechazo con el número de error esperado; los casos válidos se ejecutan de punta a punta | `tst.usp_ejecutar_pruebas` (PR-01 a PR-23) | `sql/12_pruebas_integridad.sql` |
| N3 · Concurrencia | Sobreventa, asiento duplicado, doble cobro y asignación automática con sesiones simultáneas reales | Hilos de Python con una conexión cada uno y una barrera de arranque (PC-01 a PC-04) | `src/aerolinea/pruebas.py` |
| N4 · Integración de datos | Que casi 1,2 millones de filas sintéticas cumplan **todas** las reglas activas | La carga se aplica en una transacción sin desactivar restricciones ni triggers; si una fila viola una regla, se revierte todo | `stg.usp_aplicar_carga_sintetica` |
| N5 · Validación de consultas | Que las consultas midan lo que dicen | Controles de conciliación (Q19, PR-20, PR-21, PR-23) y recuperación de parámetros conocidos del generador (Q08, Q09) | `sql/consultas/`, `reports/resultados/` |
| N6 · Entorno | Versión, edición, permisos, cifrado y protocolo de la conexión | `sql/00_verificacion_entorno.sql`, `python -m aerolinea verificar-conexion`, `scripts/windows/verificar_entorno.ps1` | `evidence/<entorno>/` |

**Garantizado por la base vs. verificado por la aplicación.** N2, N3 y N4 comprueban reglas que **impone el motor** (restricciones, triggers, procedimientos): se cumplen aunque los datos lleguen por SSMS, por una carga masiva o por otra aplicación. N1 verifica la aplicación de Python. N5 verifica la lógica de las consultas analíticas, que no impiden datos incorrectos: solo los miden.

## 2. Casos de prueba de la base (N2)

| ID | Regla(s) | Caso |
|---|---|---|
| PR-01 | FK | Pago de un tiquete inexistente |
| PR-02 | CHECK | Ruta circular, porcentaje > 100, correo inválido, sobreocupación, IATA en minúsculas, subtipo de localización incorrecto |
| PR-03 | Requisito del enunciado | Compra web de una persona sin cuenta |
| PR-04 | RN-21 | Descuento exclusivo de registrados: rechazado sin cuenta, aplicado con cuenta |
| PR-05 | RN-19, RN-20 | Precio histórico: tarifa usada inmutable, nueva versión, precio del tiquete inmutable |
| PR-06 | RN-23, RN-24 | Pago rechazado sin efecto, pago parcial, pago final que emite |
| PR-07 | RN-23, RN-25, RN-37 | Sobrepago (procedimiento y trigger) y efectivo en canal web |
| PR-08 | RN-12, RN-13, RN-14 | Asiento duplicado, asiento de otra cabina, pasajero repetido |
| PR-09 | RN-11 | Venta 13 en una cabina de 12; la cancelación libera la plaza |
| PR-10 | Atomicidad | Si falla el tiquete, la compra de la misma transacción se revierte |
| PR-11 | RN-08, RN-24 | Transiciones de estado inválidas |
| PR-12 | RN-36 | Regla de 24 h, tramos por cabina, reembolso repartido entre dos pagos |
| PR-13 | SUP-07, SUP-11 | Cancelación de vuelo con reembolso total; vencimiento de reservas |
| PR-14 | RN-05, RN-06 | Desfase horario incorrecto, llegada anterior a la salida, día ISO independiente de `DATEFIRST` |
| PR-15 | RN-09, RN-33, RN-35 | Solape de avión y de tripulante, rol incompatible, despegue sin tripulación |
| PR-16 | RN-29 | Pagos y tiquetes no se eliminan |
| PR-17 | RN-03, RN-18, RN-32 | Programación y tarifa solapadas; venta web con vendedor |
| PR-18 | RN-04 | Generación de vuelos idempotente |
| PR-19 | Seguridad | Permisos del analista y de la aplicación; enmascaramiento |
| PR-20 | Análisis | La vista no multiplica importes; una unión ingenua sí |
| PR-21 | RN-40 | Inventario conciliado, sin sobrecobros, identidad de caja exacta en los datos cargados |
| PR-22 | RN-36 | Cada reembolso cargado coincide con la función de política |
| PR-23 | Vistas y procedimientos | El resumen financiero concilia; `rpt.v_vuelo` no pierde ni duplica vuelos |

Las pruebas crean sus escenarios en vuelos 9900–9999 de una ruta reservada (BOS–ORD), los revierten o los limpian al terminar, y no alteran los datos analizados en el informe.

## 3. Estado por entorno

| Nivel | Contenedor Linux (SQL Server 2022 Developer) | Laptop Windows (SQL Server local) | Azure SQL Database |
|---|---|---|---|
| N1 · pytest | **Ejecutada**: 22 de 22 superadas | Pendiente | No aplica (no usa servidor) |
| N2 · PR-01 a PR-23 | **Ejecutada**: ver `evidence/contenedor_linux/resultados_pruebas.md` | Pendiente | Pendiente |
| N3 · PC-01 a PC-04 | **Ejecutada**: ver el mismo archivo | Pendiente | Pendiente |
| N4 · Carga completa | **Ejecutada**: `evidence/contenedor_linux/carga_sintetica.json` | Pendiente | Pendiente |
| N5 · Consultas Q01–Q20 | **Ejecutada**: `reports/resultados/manifiesto_consultas.json` | Pendiente | Pendiente |
| N6 · Entorno | **Ejecutada** en el contenedor: `verificacion_conexion.json` | Pendiente (`verificar_entorno.ps1`, script 00) | Pendiente (`sql/azure/verificacion_azure.sql`) |

Regla seguida: una prueba se declara «superada» solo si se observó su resultado. Los resultados del contenedor **no** sustituyen a los de la laptop ni a los de Azure: el contenedor valida que el código T-SQL y Python funciona en un motor SQL Server real, no el entorno del equipo ni el requisito de nube.

## 4. Lo que no se probó (límites declarados)

- **Versiones anteriores del motor:** el código evita funciones posteriores a SQL Server 2016 SP1, pero solo se ejecutó en SQL Server 2022 (nivel de compatibilidad 160). No se probó en 2016, 2017 ni 2019.
- **Windows:** la autenticación integrada, el comportamiento de SSMS y el *pooling* del administrador de controladores de Windows no se probaron (ver H-13 en `hallazgos_y_correcciones.md`; el proyecto desactiva el *pooling*).
- **Azure:** nada se ejecutó en la nube.
- **Rendimiento:** los tiempos medidos (carga en ~90 s) son del contenedor; no son una prueba de carga ni de escalabilidad.
- **Cobertura de reglas:** RN-01 a RN-42 tienen mecanismo en la base; no todas tienen un caso de prueba dedicado (por ejemplo, RN-38 y RN-39 se apoyan solo en restricciones declarativas sin caso explícito).

## 5. Cómo repetir

```powershell
python -m pytest                                              # N1
python -m aerolinea --evidencia evidence\laptop_windows pruebas   # N2 + N3
python -m aerolinea consultas                                 # N5
```
