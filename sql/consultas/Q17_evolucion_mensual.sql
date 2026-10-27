/* =============================================================================
   Q17 · Evolución mensual de las ventas (variación y acumulado)
   Pregunta     : ¿Cómo crece la venta mes a mes desde la apertura?
   Utilidad     : seguimiento de la curva de arranque de una aerolínea nueva.
   Granularidad : una fila por mes de venta y cabina.
   Filtros      : tiquetes no cancelados vendidos hasta la fecha de corte.
   Fórmulas     : variación = (ventas del mes - ventas del mes anterior) / ventas del mes anterior (LAG);
                  acumulado = SUM() OVER (ORDER BY mes ROWS UNBOUNDED PRECEDING).
                  El último mes puede estar incompleto según la fecha de corte.
   Técnicas     : CTE, LAG(), SUM() OVER con marco de ventana, NULLIF.
   ============================================================================= */
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_venta), MONTH(fecha_venta), 1) AS mes, codigo_cabina,
           COUNT(*) AS tiquetes, SUM(precio_final_usd) AS ventas_usd
    FROM rpt.v_venta
    WHERE codigo_estado <> 'CANCELADO'
    GROUP BY DATEFROMPARTS(YEAR(fecha_venta), MONTH(fecha_venta), 1), codigo_cabina
)
SELECT mes, codigo_cabina, tiquetes, ventas_usd,
       LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes)                         AS ventas_mes_anterior_usd,
       CAST((ventas_usd - LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes))
            / NULLIF(LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes), 0) AS DECIMAL(9,4)) AS variacion,
       SUM(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes ROWS UNBOUNDED PRECEDING)   AS ventas_acumuladas_usd
FROM mensual
ORDER BY codigo_cabina, mes;
