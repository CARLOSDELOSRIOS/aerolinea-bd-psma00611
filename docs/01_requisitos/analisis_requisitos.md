# Análisis de requisitos y reglas de negocio

## 1. Contexto y problema

Una aerolínea comercial nueva iniciará operaciones domésticas en Estados Unidos. Necesita una base de datos transaccional que registre su red de rutas, la programación recurrente, los vuelos con fecha concreta, la flota, la tripulación, la venta de tiquetes por canales físicos y web, los pagos, los descuentos, las cancelaciones y los reembolsos. La misma base debe permitir consultas para la toma de decisiones (ocupación, ventas, cobros, utilización de flota y demanda).

El enunciado (F1) fija diez relaciones mínimas y pide ser exhaustivos con los atributos. Este documento traduce ese enunciado en requisitos verificables y declara qué se decidió cuando el enunciado era ambiguo.

## 2. Clasificación de los requisitos

| Prefijo | Significado |
|---|---|
| **RE** | Requisito explícito del enunciado (F1, F3, F4). |
| **SUP** | Supuesto académico: decisión razonable para resolver una ambigüedad. Es reversible y está documentado. |
| **MEJ** | Mejora propuesta por el equipo. No la exige la fuente. |

## 3. Actores

| Actor | Descripción | Interacción con la base de datos |
|---|---|---|
| Cliente registrado | Persona con cuenta (correo de acceso, número de viajero). | Compra tiquetes, consulta sus compras, viaja como pasajero. |
| Comprador no registrado | Persona sin cuenta que compra en web o en un punto físico. | Compra tiquetes; sus datos se guardan como `persona` sin `cliente`. |
| Pasajero | Persona que viaja con un tiquete. Puede ser o no el comprador, y estar o no registrada. | Es el titular del tiquete. |
| Agente de ventas | Empleado en un mostrador de aeropuerto u oficina de ciudad. | Emite tiquetes y registra pagos (incluido efectivo). |
| Planificador de operaciones | Empleado de operaciones. | Mantiene rutas y programación, genera vuelos, asigna aviones y tripulación, cambia estados de vuelo. |
| Tripulante | Piloto o tripulante de cabina. | Se asigna a vuelos. |
| Analista comercial | Usuario de reportes. | Lee vistas del esquema `rpt` sin acceso a datos sensibles. |
| Pasarela de pago (sistema externo) | Autoriza o rechaza cobros con tarjeta. | Su respuesta se registra como estado del pago. |
| Administrador de BD | Equipo técnico. | Despliega scripts, ejecuta pruebas y cargas. |

## 4. Casos de uso

| ID | Caso de uso | Actor principal | Implementación |
|---|---|---|---|
| CU-01 | Registrar persona y, opcionalmente, crear cuenta de cliente | Cliente / agente | `ven.usp_registrar_persona`, `ven.usp_registrar_cliente` |
| CU-02 | Definir ruta y programación semanal | Planificador | `ops.ruta`, `ops.programacion`, `ops.programacion_dia` |
| CU-03 | Generar vuelos con fecha a partir de la programación | Planificador | `ops.usp_generar_vuelos` |
| CU-04 | Asignar avión a un vuelo | Planificador | `ops.usp_asignar_avion` |
| CU-05 | Asignar tripulación a un vuelo | Planificador | `ops.asignacion_tripulacion` (+ trigger de reglas) |
| CU-06 | Consultar disponibilidad de un vuelo por cabina | Cliente / agente | `rpt.v_ocupacion_vuelo_cabina`, consulta Q15 |
| CU-07 | Emitir tiquete con tarifa vigente y descuento opcional | Cliente / agente | `ven.usp_emitir_tiquete` |
| CU-08 | Asignar o cambiar asiento | Cliente / agente | `ven.usp_asignar_asiento` |
| CU-09 | Registrar pago (total, parcial, fallido o pendiente) | Cliente / agente / pasarela | `ven.usp_registrar_pago`, `ven.usp_resolver_pago` |
| CU-10 | Cancelar tiquete y calcular reembolso | Cliente / agente | `ven.usp_cancelar_tiquete` |
| CU-11 | Vencer reservas no pagadas | Proceso batch | `ven.usp_vencer_reservas` |
| CU-12 | Cambiar estado de vuelo (demora, salida, llegada, cancelación) | Operaciones | `ops.usp_cambiar_estado_vuelo` |
| CU-13 | Consultar indicadores de gestión | Analista | Vistas `rpt.*`, consultas Q01-Q18, Python |

## 5. Decisiones de dominio (ambigüedades resueltas)

### 5.1 Pasajero, comprador y cliente registrado

- **Persona** (`ven.persona`) es cualquier individuo identificado en una compra: comprador o pasajero.
- **Cliente** (`ven.cliente`) es la especialización de persona con cuenta registrada (relación 1:0..1, la clave de cliente es la misma clave de persona). Así se cumple RE "Clientes: pasajeros registrados".
- Cada **compra** tiene un comprador (persona) y cada **tiquete** tiene un pasajero (persona). Comprador y pasajero pueden coincidir o no.
- **Compra sin registro** (RE): el comprador es una persona sin fila en `cliente`. No se exige crear cuenta.
- SUP-01: las personas no registradas no se deduplican; cada compra sin registro puede crear una persona nueva. La deduplicación por documento queda como trabajo futuro.

### 5.2 Ruta, programación recurrente y vuelo con fecha

El enunciado describe la ruta con "origen, destino, día de la semana y hora prevista". En la normalización se observa que el **precio depende de la ruta y la cabina, no del día ni de la hora** (RE). Si el día y la hora formaran parte de la ruta, la tarifa se repetiría por cada horario. Por eso:

- `ops.ruta` = par dirigido origen → destino (con distancia).
- `ops.programacion` = número de vuelo, ruta, hora local de salida, duración y vigencia.
- `ops.programacion_dia` = días de la semana en que opera esa programación (1 = lunes … 7 = domingo, ISO 8601).
- `ops.vuelo` = ocurrencia con fecha concreta, generada desde una programación (RE "los vuelos se generan a partir de una ruta programada").

La combinación ruta + programación + día satisface el requisito de origen, destino, día y hora; la trazabilidad se explica en el informe.

### 5.3 Aeropuerto y canal de venta (localizaciones)

`ref.localizacion` generaliza las tres clases de localización del enunciado:

- `AER` aeropuerto: área física de salida y llegada (subtipo `ref.aeropuerto` con código IATA, ICAO y coordenadas). Puede tener mostrador de venta.
- `OFI` oficina de venta en ciudad: área física de venta.
- `WEB` ubicación web (sitio y aplicación móvil) donde se compran tiquetes.

El **canal** de una compra (físico o web) se deriva del tipo de la localización de venta; no se almacena aparte.

### 5.4 Capacidad, asientos y disponibilidad

- La capacidad depende del **avión asignado** y de su **configuración de asientos** (`ops.configuracion_asientos`, `ops.asiento_configuracion`).
- `ops.vuelo_cabina` guarda, por vuelo y cabina, la capacidad y las plazas ocupadas. Es un inventario controlado (desnormalización justificada en `docs/02_modelo/normalizacion.md`).
- SUP-02: el asiento es opcional al comprar y puede asignarse después. La capacidad se controla aunque el asiento no se haya elegido.
- SUP-03: un cambio de avión con tiquetes ya vendidos solo se admite hacia la misma configuración. El cambio de equipo con reacomodo queda fuera de alcance.

### 5.5 Tarifas y precio histórico

- RE: el precio depende de la combinación ruta + cabina (`ven.tarifa`).
- SUP-04: cada tarifa tiene un **período de venta** (`vigente_desde`, `vigente_hasta`). La tarifa aplicable es la vigente en la **fecha de compra**. No se modela la gestión dinámica de ingresos (revenue management) ni temporadas por fecha de viaje.
- El tiquete conserva `precio_base_usd` y `porcentaje_descuento` del momento de la venta. Son un **hecho histórico**: el precio pactado no cambia aunque cambie la tarifa o el descuento.

### 5.6 Descuentos

- RE: porcentaje sobre el precio original.
- SUP-05: **como máximo un descuento por tiquete** (no acumulables). Se evita así la ambigüedad entre aplicar porcentajes en forma aditiva o sucesiva. La alternativa (tabla asociativa con regla de composición) se discute en el informe.
- Condiciones opcionales del descuento: vigencia por fecha de compra, cabina, días mínimos de anticipación y exclusividad para compradores registrados.

### 5.7 Pagos

- RE: un tiquete puede generar uno o más pagos.
- Estados del pago: `PENDIENTE` → `CONFIRMADO` | `FALLIDO` | `ANULADO`. Solo los pagos confirmados cuentan como cobro.
- SUP-06: el tiquete se crea como `RESERVADO` y pasa a `EMITIDO` cuando los pagos confirmados cubren el precio final. Los **pagos parciales** son pagos confirmados que todavía no cubren el total.
- SUP-07: plazo de pago de la reserva = mínimo entre 72 horas desde la compra y 3 horas antes de la salida (parámetro `HORAS_LIMITE_PAGO`).
- SUP-08: el efectivo solo se acepta en localizaciones físicas.
- MEJ-01: no se almacenan números completos de tarjeta, solo los últimos cuatro dígitos y la marca. Es un principio de minimización de datos.

### 5.8 Cancelaciones y reembolsos

- SUP-09 (política académica configurable en `ven.politica_cancelacion`): el reembolso es un porcentaje del monto cobrado, que depende de la cabina y de las horas que faltan para la salida.
- SUP-10: cancelación voluntaria dentro de las 24 h posteriores a la compra, si la compra se hizo con al menos 7 días de anticipación, implica reembolso del 100 %. La regla se inspira en la regla de 24 horas del Departamento de Transporte de EE. UU. (14 CFR 259.5(b)(4)); no pretende reproducir la normativa completa.
- SUP-11: cancelación del vuelo por la aerolínea o vencimiento de la reserva implican reembolso del 100 % de lo cobrado.
- El reembolso se registra contra los pagos confirmados, empezando por el más reciente. Lo no reembolsado es una penalidad retenida.

### 5.9 Estados y transiciones válidas

| Entidad | Estado inicial | Transiciones válidas | Estados finales |
|---|---|---|---|
| Vuelo | PROGRAMADO | PROGRAMADO→DEMORADO, PROGRAMADO→EN_VUELO, PROGRAMADO→CANCELADO, DEMORADO→DEMORADO, DEMORADO→EN_VUELO, DEMORADO→CANCELADO, EN_VUELO→ATERRIZADO | ATERRIZADO, CANCELADO |
| Tiquete | RESERVADO | RESERVADO→EMITIDO, RESERVADO→CANCELADO, EMITIDO→USADO, EMITIDO→NO_PRESENTADO, EMITIDO→CANCELADO | USADO, NO_PRESENTADO, CANCELADO |
| Pago | PENDIENTE, CONFIRMADO o FALLIDO | PENDIENTE→CONFIRMADO, PENDIENTE→FALLIDO, PENDIENTE→ANULADO | CONFIRMADO, FALLIDO, ANULADO |

Las transiciones se almacenan como datos (`ref.transicion_vuelo`, `ref.transicion_tiquete`, `ref.transicion_pago`) y las validan triggers.

### 5.10 Fechas, zonas horarias y llegadas al día siguiente

- Los horarios de vuelo se guardan como `datetimeoffset(0)` en la **hora local del aeropuerto** correspondiente: salida con el desfase del origen y llegada con el del destino. La comparación entre valores `datetimeoffset` se hace en UTC, por lo que la duración y el orden temporal son correctos aunque los vuelos crucen zonas horarias o lleguen al día siguiente.
- La hora local se calcula con `AT TIME ZONE` y la zona horaria del aeropuerto. Se respetan el horario de verano (fin el 1-nov-2026) y las zonas sin horario de verano (Phoenix, Honolulu).
- Las marcas transaccionales (compra, pago, reembolso, cancelación) se guardan en UTC (`datetime2(0)`, sufijo `_utc`).
- El día de la semana se calcula sin depender de `SET DATEFIRST`: `(DATEDIFF(DAY, '19000101', fecha) % 7) + 1`, porque el 1-ene-1900 fue lunes.

### 5.11 Asignación temporal de aviones y tripulación

- Un avión no puede estar asignado a dos vuelos cuyos intervalos programados se solapen, considerando un tiempo mínimo de rotación en tierra (parámetro `MIN_ROTACION_AVION`, 40 min).
- Un tripulante no puede estar en dos vuelos solapados (parámetro `MIN_DESCANSO_TRIPULACION`, 30 min).
- El rol en vuelo debe ser compatible con el cargo (pilotos → CAPITAN/PRIMER_OFICIAL; cabina → JEFE_CABINA/AUXILIAR_VUELO).
- Para iniciar un vuelo (pasar a `EN_VUELO`) se exige tripulación completa: un capitán, un primer oficial y tripulantes de cabina en número ≥ ⌈asientos/50⌉ (SUP-12, supuesto académico).
- SUP-13: la base no impone los límites de tiempo de vuelo y descanso de la normativa aeronáutica (14 CFR parte 117); solo impide solapes con un descanso mínimo. Los datos sintéticos se planifican con cuatro equipos por línea en bloques de tres días para no superar 100 horas de vuelo en 28 días por piloto (referencia de 14 CFR 117.23), y la consulta Q18 lo verifica (mecanismo A).

## 6. Reglas de negocio verificables

Mecanismo: **D** = restricción declarativa (PK, FK, UNIQUE, CHECK, índice único filtrado, columna calculada); **T** = trigger; **P** = procedimiento almacenado; **A** = verificación por consulta o prueba (no impide el dato inválido).

| ID | Regla | Mecanismo | Objeto principal |
|---|---|---|---|
| RN-01 | Origen y destino de una ruta son distintos; no hay rutas duplicadas | D | `ck_ruta_origen_destino`, `uq_ruta_origen_destino` |
| RN-02 | El día de la semana está entre 1 y 7 y no se repite por programación | D | `ck_programacion_dia_semana`, PK compuesta |
| RN-03 | Un número de vuelo no tiene vigencias solapadas | T | `ops.trg_programacion_reglas` |
| RN-04 | No hay dos vuelos de la misma programación en la misma fecha local | D | `uq_vuelo_programacion_fecha` (columna calculada persistida) |
| RN-05 | La llegada programada es posterior a la salida; la duración está entre 20 y 1080 min | D | `ck_vuelo_horario` |
| RN-06 | Los desfases horarios de salida y llegada coinciden con la zona del aeropuerto | T | `ops.trg_vuelo_reglas` |
| RN-07 | Las horas reales son coherentes con el estado del vuelo | D | `ck_vuelo_estado_horas` |
| RN-08 | Las transiciones de estado de vuelo, tiquete y pago son válidas | T | triggers + tablas `ref.transicion_*` |
| RN-09 | Un avión no se solapa en dos vuelos (con rotación mínima) | T | `ops.trg_vuelo_reglas` |
| RN-10 | Solo aviones en estado ACTIVO se asignan a vuelos | T | `ops.trg_vuelo_reglas` |
| RN-11 | Las plazas ocupadas nunca superan la capacidad (sin sobreventa) | D + T | `ck_vuelo_cabina_capacidad` + `ven.trg_tiquete_reglas` |
| RN-12 | Un asiento no se vende dos veces en el mismo vuelo | D | `ux_tiquete_vuelo_asiento` (índice único filtrado) |
| RN-13 | El asiento existe en la configuración del avión y corresponde a la cabina del tiquete | T | `ven.trg_tiquete_reglas` |
| RN-14 | Un pasajero no tiene dos tiquetes activos en el mismo vuelo | D | `ux_tiquete_vuelo_pasajero` |
| RN-15 | La cabina del tiquete existe en el vuelo | D | FK `(id_vuelo, codigo_cabina)` → `ops.vuelo_cabina` |
| RN-16 | La tarifa del tiquete corresponde a su cabina | D | FK `(id_tarifa, codigo_cabina)` → `ven.tarifa` |
| RN-17 | La tarifa corresponde a la ruta del vuelo y estaba vigente en la fecha de compra; el precio base copiado es el de la tarifa | T | `ven.trg_tiquete_reglas` |
| RN-18 | No hay tarifas con vigencias solapadas para la misma ruta y cabina | T | `ven.trg_tarifa_reglas` |
| RN-19 | Precio, tarifa, vuelo, cabina, pasajero y descuento de un tiquete son inmutables (precio histórico) | T | `ven.trg_tiquete_reglas` |
| RN-20 | Una tarifa usada en tiquetes no cambia de precio ni de vigencia inicial | T | `ven.trg_tarifa_reglas` |
| RN-21 | Descuento: 0 % si no hay descuento; el porcentaje copiado coincide con el del descuento; está vigente, aplica a la cabina, cumple la anticipación y la exclusividad de registro | D + T | `ck_tiquete_descuento` + trigger |
| RN-22 | Precio final = precio base − redondeo(precio base × % / 100, 2) | D | columnas calculadas persistidas |
| RN-23 | La suma de pagos confirmados no supera el precio final | T | `ven.trg_pago_reglas` |
| RN-24 | El tiquete solo pasa a EMITIDO si está totalmente pagado | T | `ven.trg_tiquete_reglas` |
| RN-25 | El efectivo solo se cobra en localizaciones físicas | T | `ven.trg_pago_reglas` |
| RN-26 | Los pagos con tarjeta guardan los últimos 4 dígitos; los demás no | D | `ck_pago_tarjeta` |
| RN-27 | Coherencia entre el estado del pago y sus fechas, referencia o motivo de rechazo | D | `ck_pago_estado_datos` |
| RN-28 | Un reembolso solo procede sobre un pago confirmado de un tiquete cancelado y la suma por pago no supera el monto del pago | T | `ven.trg_reembolso_reglas` |
| RN-29 | Pagos y reembolsos no se eliminan | T | triggers `INSTEAD OF DELETE` |
| RN-30 | Un tiquete cancelado tiene fecha y motivo de cancelación | D | `ck_tiquete_cancelacion` |
| RN-31 | La compra es anterior a la salida del vuelo | T | `ven.trg_tiquete_reglas` |
| RN-32 | Una venta web no tiene vendedor; una venta física sí | T | `ven.trg_compra_reglas` |
| RN-33 | Rol de tripulación compatible con el cargo; sin solapes; empleado vigente | T | `ops.trg_asignacion_tripulacion_reglas` |
| RN-34 | Un solo capitán, un solo primer oficial y un solo jefe de cabina por vuelo | D | índices únicos filtrados |
| RN-35 | Un vuelo pasa a EN_VUELO solo con avión y tripulación completa (SUP-12) | T | `ops.trg_vuelo_reglas` (error 50029) |
| RN-36 | Política de reembolso (24 h, cabina, anticipación, causa) | P | `ven.fn_politica_reembolso`, `ven.usp_cancelar_tiquete` |
| RN-37 | El monto de un pago no supera el saldo pendiente (mensaje amigable) | P (+T) | `ven.usp_registrar_pago` |
| RN-38 | Correo de acceso de cliente único; número de viajero único | D | `uq_cliente_email`, `uq_cliente_numero_viajero` |
| RN-39 | Empleado mayor de 18 años al contratarse; terminación posterior a contratación | D | `ck_empleado_*` |
| RN-40 | Plazas ocupadas = tiquetes activos (conciliación del inventario) | A | prueba PR-21 + `rpt.v_conciliacion_inventario` |
| RN-41 | El pasajero de un tiquete tiene fecha de nacimiento y género registrados (datos exigidos para volar) | T | `ven.trg_tiquete_reglas` (error 50046) |
| RN-42 | Solo se registran pagos sobre tiquetes en estado RESERVADO (pendientes de pago) | T + P | `ven.trg_pago_reglas` (50053), `ven.usp_registrar_pago` |

## 7. Requisitos no funcionales

| ID | Requisito | Clase |
|---|---|---|
| RNF-01 | Base desplegable en Azure SQL Database (requisito de nube) | RE |
| RNF-02 | Consultas ejecutadas desde un lenguaje de programación (Python) | RE |
| RNF-03 | Scripts en GitHub | RE (guías) |
| RNF-04 | Reproducibilidad: datos sintéticos con semilla fija y resultados regenerables con un comando | MEJ |
| RNF-05 | Conexiones cifradas; sin secretos en el repositorio | MEJ |
| RNF-06 | Compatibilidad mínima SQL Server 2016 SP1 (nivel de compatibilidad 130) y Azure SQL Database | MEJ |
| RNF-07 | Control de concurrencia sin sobreventa ni asientos duplicados | MEJ (exigido por el usuario) |
| RNF-08 | Separación de privilegios mediante roles | MEJ |

## 8. Alcance

**Dentro:** red doméstica de EE. UU., una moneda (USD), dos cabinas, tiquetes de un tramo (cupón único), compras con varios tiquetes (familia, ida y vuelta), pagos múltiples, un descuento por tiquete, cancelación y reembolso, flota con configuraciones de asientos, tripulación con roles, estados y auditoría de cambios.

**Fuera:** impuestos y tasas gubernamentales, gestión dinámica de ingresos, sobreventa deliberada (*overbooking*) y compensaciones, equipaje, check-in y pase de abordar, programa de lealtad con millas, conexiones multitramo con tarifa combinada, mantenimiento de aeronaves, cumplimiento normativo completo (FAA, DOT, TSA, PCI DSS) y sistemas reales de distribución (GDS).
