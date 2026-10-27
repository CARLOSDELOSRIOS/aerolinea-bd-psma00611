/* =============================================================================
   Q09 · Tasa de cancelación por ruta y motivo
   Pregunta     : ¿Dónde se cancelan más tiquetes y por qué causa?
   Utilidad     : separar cancelaciones voluntarias (demanda) de las operativas (vuelos cancelados).
   Granularidad : una fila por ruta.
   Filtros      : tiquetes de vuelos con salida entre @fecha_desde y @fecha_hasta.
   Fórmulas     : denominador = tiquetes vendidos (todos los estados);
                  tasa por motivo = tiquetes cancelados por ese motivo / tiquetes vendidos.
   Técnicas     : agregación condicional (pivote con CASE), GROUP BY, ORDER BY por expresión.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.ruta,
       COUNT(*)                                                                                   AS tiquetes_vendidos,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VOLUNTARIA' THEN 1 ELSE 0 END)                AS cancel_voluntarias,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VUELO_CANCELADO' THEN 1 ELSE 0 END)           AS cancel_por_vuelo,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VENCIMIENTO' THEN 1 ELSE 0 END)               AS cancel_por_vencimiento,
       CAST(SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VOLUNTARIA' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4))      AS tasa_voluntaria,
       CAST(SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VUELO_CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_por_vuelo,
       CAST(SUM(CASE WHEN v.codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4))                   AS tasa_total
FROM rpt.v_venta AS v
WHERE v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
GROUP BY v.ruta
ORDER BY tasa_total DESC;
