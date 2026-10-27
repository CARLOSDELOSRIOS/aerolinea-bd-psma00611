/* =============================================================================
   Q15 · Puntualidad y cancelaciones operativas por ruta
   Pregunta     : ¿Qué rutas llegan a tiempo y cuáles acumulan demoras o cancelaciones?
   Utilidad     : gestión operativa y de servicio.
   Granularidad : una fila por ruta.
   Filtros      : vuelos con fecha local entre @fecha_desde y @fecha_hasta y salida anterior a la fecha de corte.
   Fórmulas     : a tiempo = llegada real menos de 15 min después de la programada (criterio usado por
                  la estadística de puntualidad de EE. UU.); % a tiempo = a tiempo / vuelos ATERRIZADOS;
                  tasa de cancelación = CANCELADOS / (ATERRIZADOS + CANCELADOS); p90 con PERCENTILE_CONT.
   Técnicas     : CTE, PERCENTILE_CONT ... OVER (PARTITION BY), agregación condicional.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT v.ruta, v.codigo_estado, v.demora_llegada_min,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY v.demora_llegada_min) OVER (PARTITION BY v.ruta) AS p90_demora
    FROM rpt.v_vuelo AS v
    WHERE v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
      AND v.codigo_estado IN ('ATERRIZADO', 'CANCELADO')
)
SELECT ruta,
       SUM(CASE WHEN codigo_estado = 'ATERRIZADO' THEN 1 ELSE 0 END)                         AS vuelos_operados,
       SUM(CASE WHEN codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END)                          AS vuelos_cancelados,
       CAST(SUM(CASE WHEN codigo_estado = 'ATERRIZADO' AND demora_llegada_min < 15 THEN 1 ELSE 0 END) * 1.0
            / NULLIF(SUM(CASE WHEN codigo_estado = 'ATERRIZADO' THEN 1 ELSE 0 END), 0) AS DECIMAL(7,4)) AS puntualidad,
       CAST(AVG(CASE WHEN codigo_estado = 'ATERRIZADO' THEN demora_llegada_min * 1.0 END) AS DECIMAL(7,1)) AS demora_media_llegada_min,
       CAST(MAX(p90_demora) AS DECIMAL(7,1))                                                AS p90_demora_llegada_min,
       CAST(SUM(CASE WHEN codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_cancelacion
FROM base
GROUP BY ruta
ORDER BY puntualidad;
