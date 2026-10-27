/* =============================================================================
   Q11 · Distribución de la demanda por día de la semana y franja horaria
   Pregunta     : ¿Qué días y horas de salida concentran la demanda?
   Utilidad     : ajustar frecuencias y horarios de la programación semanal.
   Granularidad : una fila por día de la semana (ISO, 1 = lunes) y franja de salida local.
   Filtros      : vuelos ATERRIZADOS con fecha local entre @fecha_desde y @fecha_hasta.
   Fórmula      : factor = pasajeros volados / asientos ofrecidos (ponderado).
                  El día se calcula sin depender de SET DATEFIRST (vista rpt.v_vuelo).
   Técnicas     : CTE, CASE para franjas, GROUP BY de dos dimensiones.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT v.dia_semana_iso,
           CASE WHEN v.hora_salida_local < 9 THEN '1. Madrugada-mañana (<09h)'
                WHEN v.hora_salida_local < 13 THEN '2. Media mañana (09-13h)'
                WHEN v.hora_salida_local < 18 THEN '3. Tarde (13-18h)'
                ELSE '4. Noche (>=18h)' END AS franja,
           o.capacidad, o.usados
    FROM rpt.v_vuelo AS v
    JOIN rpt.v_ocupacion_vuelo_cabina AS o ON o.id_vuelo = v.id_vuelo
    WHERE v.codigo_estado = 'ATERRIZADO' AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
)
SELECT dia_semana_iso,
       CHOOSE(dia_semana_iso, 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo') AS dia,
       franja,
       SUM(usados)                                                   AS pasajeros_volados,
       SUM(capacidad)                                                AS asientos_ofrecidos,
       CAST(SUM(usados) * 1.0 / SUM(capacidad) AS DECIMAL(7,4))      AS factor_ocupacion
FROM base
GROUP BY dia_semana_iso, franja
ORDER BY dia_semana_iso, franja;
