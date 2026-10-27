# Normalización y desnormalizaciones justificadas

Este documento muestra que el esquema relacional está en tercera forma normal (3FN) —en la mayoría de las relaciones también en forma normal de Boyce-Codd (FNBC)— y justifica las pocas redundancias controladas. Las dependencias funcionales (DF) se escriben `X → Y` («X determina a Y»). Se usan los nombres de tablas del modelo físico.

## 1. Punto de partida: la «planilla de ventas» sin normalizar

Si la aerolínea registrara sus ventas en una única tabla plana, cada fila tendría:

```
VENTA(numero_tiquete, codigo_reserva, fecha_compra, canal, vendedor, comprador_nombre, comprador_email,
      pasajero_nombre, pasajero_documento, numero_vuelo, fecha_vuelo, origen, destino, hora_salida, dias_operacion,
      matricula_avion, modelo_avion, cabina, asiento, precio_tarifa, codigo_descuento, porcentaje_descuento,
      precio_final, pagos(monto, metodo, estado, fecha)*, reembolsos(monto, fecha, motivo)*, estado_tiquete)
```

Problemas:

| Anomalía | Ejemplo en la planilla |
|---|---|
| Grupos repetitivos (viola 1FN) | `pagos` y `reembolsos` son listas; `dias_operacion` = «1,3,5» |
| Inserción | No se puede registrar una ruta, un avión o una tarifa nueva hasta vender un tiquete |
| Actualización | Cambiar la hora de salida del XX101 obliga a modificar miles de filas; si se olvida una, el horario queda inconsistente |
| Eliminación | Si se borran los tiquetes de un vuelo cancelado se pierde que el avión N321XA existe y su configuración |
| Ambigüedad | Comprador y pasajero mezclados: una misma persona aparece con datos distintos en cada fila |

## 2. Primera forma normal (1FN)

Cada atributo es atómico y no hay grupos repetitivos:

- Los pagos y reembolsos pasan a relaciones propias: `ven.pago(id_pago, id_tiquete, …)` y `ven.reembolso(id_reembolso, id_pago, …)`.
- Los días de operación de un horario se separan en `ops.programacion_dia(id_programacion, dia_semana)`; la clave compuesta impide repetir un día (RN-02).
- Los asientos de cada configuración se listan en `ops.asiento_configuracion(id_configuracion, codigo_asiento)`.
- Los nombres de personas se separan en `nombres` y `apellidos`; el documento de identidad en tipo, número y país.

## 3. Segunda forma normal (2FN): sin dependencias parciales

Solo las relaciones con clave compuesta pueden violar 2FN. Se revisan todas:

| Relación (clave) | Atributos no clave | ¿Dependen de toda la clave? |
|---|---|---|
| `ops.programacion_dia (id_programacion, dia_semana)` | — | No hay atributos no clave |
| `ops.vuelo_cabina (id_vuelo, codigo_cabina)` | `capacidad`, `plazas_ocupadas` | Sí: la capacidad VIP del vuelo 123 depende del vuelo **y** de la cabina |
| `ops.asiento_configuracion (id_configuracion, codigo_asiento)` | `fila`, `letra`, `codigo_cabina`, `es_ventana`, `es_pasillo`, `es_salida_emergencia` | Sí: el asiento 12A es VIP en una configuración y económico en otra |
| `ops.asignacion_tripulacion (id_vuelo, id_empleado)` | `rol_vuelo`, `asignado_utc` | Sí: el rol es del empleado **en ese vuelo** |
| `ref.transicion_* (estado_origen, estado_destino)` | — | No hay atributos no clave |

Ejemplo de violación evitada: guardar el `nombre` del empleado en `asignacion_tripulacion` crearía la DF parcial `id_empleado → nombre`; por eso el nombre vive solo en `rh.empleado`.

## 4. Tercera forma normal (3FN): sin dependencias transitivas

Principales DF y cómo se descompusieron:

| DF transitiva detectada en la planilla | Descomposición |
|---|---|
| `numero_tiquete → numero_vuelo → origen, destino, hora_salida` | `ven.tiquete → ops.vuelo → ops.programacion → ops.ruta → ref.aeropuerto` |
| `numero_vuelo, fecha_vuelo → matricula_avion → modelo_avion, configuración` | `ops.vuelo.id_avion → ops.avion.id_configuracion → ops.configuracion_asientos.id_modelo → ref.modelo_avion` |
| `codigo_reserva → comprador, canal, vendedor, fecha_compra` | `ven.compra` separada de `ven.tiquete` (una compra agrupa varios tiquetes) |
| `pasajero_documento → pasajero_nombre` | `ven.persona` |
| `cliente → numero_viajero, email_acceso, nivel_lealtad` | `ven.cliente` como subtipo 1:0..1 de `ven.persona` |
| `aeropuerto → ciudad, estado, zona_horaria` | `ref.localizacion` (supertipo) y `ref.aeropuerto` (subtipo) |
| `codigo_cargo → departamento, categoria_tripulacion` | `rh.cargo` |
| `codigo_estado → descripcion, es_final, ocupa_inventario` | `ref.estado_vuelo`, `ref.estado_tiquete`, `ref.estado_pago` |

Comprobación sobre la relación más compleja, `ven.tiquete`:

- Claves candidatas: `id_tiquete` (sustituta) y `numero_tiquete` (natural, única). Ambas determinan todos los atributos.
- `id_vuelo, codigo_asiento` también es única **solo para tiquetes activos** (índice único filtrado `ux_tiquete_vuelo_asiento`); no es una clave candidata en sentido estricto porque los tiquetes cancelados liberan el asiento.
- `precio_final_usd` y `monto_descuento_usd` dependen de `precio_base_usd` y `porcentaje_descuento` (DF entre atributos no clave). No crean anomalías porque son **columnas calculadas persistidas**: el motor las recalcula y nadie puede escribirlas. Se documentan como derivadas.

### 4.1 Forma normal de Boyce-Codd (FNBC)

La mayoría de las relaciones cumple FNBC porque todo determinante es clave candidata. Casos revisados:

- `ops.ruta`: `id_ruta → …` y `(id_aeropuerto_origen, id_aeropuerto_destino) → id_ruta`; ambos determinantes son claves candidatas (la segunda por `uq_ruta_origen_destino`).
- `ven.tarifa`: `(id_ruta, codigo_cabina, vigente_desde) → precio_base_usd`. Es clave candidata (única). La regla «sin vigencias solapadas» (RN-18) no es una DF y se garantiza con trigger.
- `ops.programacion`: `(numero_vuelo, vigente_desde)` es clave candidata; el no solapamiento de vigencias (RN-03) también se garantiza con trigger.

## 5. Desnormalizaciones controladas (y por qué no generan anomalías)

| # | Redundancia | Motivo | Control que evita la anomalía |
|---|---|---|---|
| 1 | `ven.tiquete.precio_base_usd` y `porcentaje_descuento` copian el precio de `ven.tarifa` y el porcentaje de `ven.descuento` | **Precio histórico**: el precio pactado es un hecho de la venta. Si la tarifa cambia mañana, el tiquete vendido hoy no debe cambiar. Formalmente, la DF `id_tarifa → precio_base_usd` vale solo «en el momento de la venta». | RN-17/RN-21: el trigger verifica que el valor copiado coincide con el vigente al vender. RN-19: el precio del tiquete es inmutable. RN-20: una tarifa usada no cambia de precio; se crea una nueva versión con otra vigencia. |
| 2 | `ops.vuelo_cabina.plazas_ocupadas` (contador) | Evitar contar tiquetes en cada venta y, sobre todo, disponer de **una fila que bloquear** para serializar ventas concurrentes (semáforo por vuelo y cabina). | Solo lo actualiza `ven.trg_tiquete_reglas` en la misma transacción que el cambio de estado del tiquete; `CHECK (plazas_ocupadas <= capacidad)` impide la sobreventa; `rpt.v_conciliacion_inventario` y la prueba PR-21 comprueban que coincide con el recuento (RN-40); `ops.usp_sincronizar_inventario` lo recalcula si hiciera falta. |
| 3 | `ops.vuelo_cabina.capacidad` copia la capacidad de la configuración del avión | Un vuelo puede ponerse a la venta antes de asignarle avión; la capacidad comercial debe existir desde el principio. | Al asignar avión se sincroniza; cambiar a un avión de otra configuración con ventas activas está prohibido (SUP-03, error 50025). |
| 4 | `ops.vuelo.fecha_salida_local` | Clave natural del vuelo: «XX101 del 2026-11-06». | Columna calculada persistida a partir de `salida_programada`; no se puede escribir. Sostiene `uq_vuelo_programacion_fecha` (RN-04). |
| 5 | `ref.aeropuerto.tipo_localizacion` (constante `AER`) | Garantizar que un aeropuerto solo pueda ser subtipo de una localización de tipo aeropuerto. | Columna calculada constante + FK compuesta `(id_localizacion, tipo_localizacion)` → `ref.localizacion`. |
| 6 | `ven.tiquete.codigo_cabina` junto a `id_tarifa` | Permite dos FK compuestas que garantizan declarativamente que la cabina del tiquete existe en el vuelo (RN-15) y que la tarifa es de esa misma cabina (RN-16). | FK `(id_vuelo, codigo_cabina)` → `ops.vuelo_cabina` y FK `(id_tarifa, codigo_cabina)` → `ven.tarifa`. |

## 6. Decisiones relacionadas que se defendieron en el diseño

- **Asiento sin FK hacia `ops.asiento_configuracion`.** El mapa de asientos depende del avión asignado al vuelo (`vuelo → avion → configuracion`). Una FK obligaría a guardar `id_configuracion` en el tiquete, que es una dependencia transitiva de `id_vuelo` (violaría 3FN) y quedaría desactualizada si se cambia el avión. Se valida con trigger (RN-13, error 50049).
- **Estados como datos.** Los estados válidos y sus transiciones están en tablas (`ref.estado_*`, `ref.transicion_*`), no en `CHECK` con listas fijas: agregar un estado no exige alterar tablas y las transiciones se pueden consultar y documentar.
- **Claves sustitutas y naturales.** Las entidades transaccionales usan claves sustitutas (`IDENTITY`) y conservan sus claves naturales como `UNIQUE` (`numero_tiquete`, `codigo_reserva`, `matricula`, `codigo_iata`). Los catálogos pequeños usan la clave natural como PK (`codigo_cabina`, `codigo_estado`) para que los datos sean legibles sin uniones.
- **Supertipo/subtipo.** `ven.persona` → `ven.cliente` (1:0..1) resuelve «comprador sin registro»: toda persona puede comprar o viajar; solo algunas tienen cuenta. `ref.localizacion` → `ref.aeropuerto` resuelve «localizaciones físicas y web»: oficinas, aeropuertos y canales web comparten la misma tabla de canal de venta.
