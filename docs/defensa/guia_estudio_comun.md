# Guía de estudio común

Como la exposición es aleatoria, **todos** deben dominar lo esencial de cada parte. Esta guía resume lo que hay que poder explicar sin leer, las cifras clave y dónde está el detalle.

## 1. Lo que cada integrante debe poder explicar en 30 segundos

| Tema | Idea central | Dónde profundizar |
|---|---|---|
| Problema | Registrar ventas, cobros y operación sin errores aunque varias personas operen a la vez, y analizar con definiciones consistentes | Informe §2 |
| Pasajero, comprador, cliente | Toda persona puede comprar o viajar; cliente = persona con cuenta (subtipo 1:0..1). Así se resuelve la compra sin registro | `docs/01_requisitos/analisis_requisitos.md` §5.1 |
| Ruta, programación, vuelo | Ruta = par origen-destino; programación = número, hora y días con vigencia; vuelo = salida fechada generada por `ops.usp_generar_vuelos` | §5.2 |
| Precio histórico | El tiquete copia precio base y % de descuento; la tarifa usada no se edita: se cierra y se crea otra versión | `normalizacion.md` §5, PR-05 |
| Descuentos | Uno por tiquete, el mayor aplicable; por eso `VIPPLUS5` nunca se usa | Q20 |
| Pagos | Varios por tiquete; emisión al completar; la reserva vence a las 72 h o 3 h antes de la salida | PR-06, `ven.usp_registrar_pago` |
| Reembolsos | Vuelo cancelado o vencimiento: 100 %; regla de 24 h si se compró con 7+ días; si no, tramos por cabina | `ven.fn_politica_reembolso`, PR-12 |
| Zonas horarias | Hora local con desfase en `datetimeoffset`; transacciones en UTC; `AT TIME ZONE` con nombres de Windows | PR-14 |
| Normalización | 1FN atómico, 2FN sin dependencias parciales, 3FN sin transitivas; seis redundancias controladas | `normalizacion.md` |
| Dónde vive cada regla | Declarativa > trigger > procedimiento > consulta de verificación | `docs/03_arquitectura/arquitectura.md` §3 |
| Concurrencia | RCSI para lecturas; `UPDLOCK` sobre la fila del cupo, del tiquete o del recurso; índice único filtrado para asientos | `concurrencia.md` |
| Seguridad | Roles con privilegio mínimo, cadena de propiedad, enmascaramiento, cifrado, sin secretos | `seguridad.md` |
| Reproducibilidad | Semilla fija, CSV con SHA-256, carga transaccional con reglas activas, un comando | README |
| Nube | Preparada y documentada, **no desplegada**; requiere suscripción y autorización | `docs/05_azure/guia_azure.md` |

## 2. Cifras clave (todas de los resultados guardados)

| Cifra | Valor | Fuente |
|---|---|---|
| Tablas de negocio / columnas documentadas | 39 / 269 (41 tablas con control y pruebas) | Diccionario |
| Reglas de negocio | 42 (16 D, 20 T, 2 P, 3 combinadas, 1 A) | Análisis de requisitos |
| CHECK / FK / UNIQUE / índices únicos filtrados / triggers | 70 / 53 / 29 / 6 / 12 | Catálogo |
| Procedimientos / vistas | 16 de negocio + 4 de pruebas / 9 | Catálogo |
| Datos cargados | 3 588 vuelos, 232 096 personas, 323 718 tiquetes, 388 003 pagos, 18 182 reembolsos (≈1,19 M filas) en ~90 s | `carga_sintetica.json` |
| Pruebas | 23/23 T-SQL, 4/4 concurrencia, 23/23 pytest | `resultados_pruebas.md` |
| Defectos reales corregidos | 20 | `hallazgos_y_correcciones.md` |
| Ocupación ponderada | ECO 68,9 % · VIP 53,0 % | Q02 |
| Ventas brutas / cobros / reembolsos (jul-oct) | 73,52 / 72,27 / 3,03 millones USD | Q03 |
| Identidad de caja | 0,00 USD de diferencia | Q19 |
| Compras hechas por compradores registrados | 41,9 % (generador: 42 %) | Q08 |
| Cancelación voluntaria (vuelos de sep-oct) | 4,87 % (generador: 5 %) | Q09 |
| Puntualidad | 78,4 % llega con < 15 min de demora | Q15 |
| Horas máximas de piloto en 672 h | 94,5 (límite de referencia: 100) | Q18 |

## 3. Conceptos que suelen preguntar

- **Dependencia funcional:** X → Y si el valor de X determina el de Y.
- **Anomalías:** de inserción (no se puede registrar algo sin otra cosa), actualización (un dato repetido queda inconsistente) y eliminación (borrar una fila borra información ajena).
- **Clave candidata, primaria, sustituta, natural:** `id_tiquete` es sustituta; `numero_tiquete` es natural y única.
- **Índice único filtrado:** unicidad solo sobre las filas que cumplen el filtro (tiquetes activos).
- **Escritura sesgada (*write skew*):** dos transacciones validan con el mismo estado y ambas escriben; se evita bloqueando un recurso común.
- **`READ_COMMITTED_SNAPSHOT`:** las lecturas ven la última versión confirmada y no bloquean; predeterminado en Azure SQL Database.
- **`SET XACT_ABORT ON`:** ante un error, la transacción se revierte completa.
- **Cadena de propiedad:** si el procedimiento y las tablas tienen el mismo dueño, `EXECUTE` sobre el procedimiento basta.
- **Trigger set-based:** procesa todas las filas de `inserted`/`deleted` de una vez, nunca fila por fila.
- **`GO`:** separador de lotes de SSMS/sqlcmd; no es T-SQL.
- **Parámetros enlazados:** el valor viaja separado del texto SQL; evita la inyección.

## 4. Mapa del repositorio

| Si preguntan por… | Abrir |
|---|---|
| Fuentes, discrepancias y requisitos | `docs/00_fuentes/` |
| Reglas RN y supuestos SUP | `docs/01_requisitos/analisis_requisitos.md` |
| Diagramas, normalización, diccionario | `docs/02_modelo/` |
| Arquitectura, concurrencia, seguridad | `docs/03_arquitectura/` |
| Laptop y Azure | `docs/04_entorno_local/`, `docs/05_azure/` |
| Pruebas y hallazgos | `docs/06_pruebas/`, `evidence/` |
| Consultas con resultados e interpretación | `docs/07_consultas/catalogo_consultas.md` |
| Código | `sql/`, `src/aerolinea/` |

## 5. Ejercicio de preparación

Cada integrante, por separado: (1) explicar en voz alta tres diapositivas elegidas al azar en menos de 1:30 cada una; (2) responder cinco preguntas de `preguntas_defensa.md` sin mirar la respuesta; (3) ejecutar la demostración una vez en su propio equipo o en el de quien la hará.
