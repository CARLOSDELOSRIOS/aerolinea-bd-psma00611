/* =============================================================================
   Q10 · Utilización de la flota
   Pregunta     : ¿Cuántas horas diarias vuela cada avión y cuáles están subutilizados?
   Utilidad     : planificación de flota, reservas y mantenimiento.
   Granularidad : una fila por avión.
   Filtros      : vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta.
   Fórmulas     : horas bloque programadas = SUM(minutos programados) / 60;
                  utilización media = horas bloque / días del período (no solo días con vuelos);
                  días activos = días con al menos un vuelo.
   Técnicas     : LEFT JOIN (incluye aviones sin vuelos), agregación sobre vista, RANK().
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH uso AS (
    SELECT u.id_avion, COUNT(*) AS dias_activos, SUM(u.vuelos) AS vuelos,
           SUM(u.minutos_bloque_programados) AS minutos_programados, SUM(u.minutos_bloque_reales) AS minutos_reales
    FROM rpt.v_utilizacion_avion_dia AS u
    WHERE u.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY u.id_avion
)
SELECT a.matricula,
       m.modelo,
       a.estado_operativo,
       ISNULL(u.dias_activos, 0)                                                     AS dias_activos,
       ISNULL(u.vuelos, 0)                                                           AS vuelos,
       CAST(ISNULL(u.minutos_programados, 0) / 60.0 AS DECIMAL(9,1))                 AS horas_bloque_programadas,
       CAST(ISNULL(u.minutos_reales, 0) / 60.0 AS DECIMAL(9,1))                      AS horas_bloque_reales,
       CAST(ISNULL(u.minutos_programados, 0) / 60.0 / (DATEDIFF(DAY, @fecha_desde, @fecha_hasta) + 1) AS DECIMAL(5,2)) AS horas_promedio_por_dia,
       RANK() OVER (ORDER BY ISNULL(u.minutos_programados, 0) DESC)                  AS rango_utilizacion
FROM ops.avion AS a
JOIN ops.configuracion_asientos AS c ON c.id_configuracion = a.id_configuracion
JOIN ref.modelo_avion AS m ON m.id_modelo = c.id_modelo
LEFT JOIN uso AS u ON u.id_avion = a.id_avion
ORDER BY rango_utilizacion, a.matricula;
