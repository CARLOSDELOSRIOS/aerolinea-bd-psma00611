/* =============================================================================
   Q12 · Anticipación de la compra y precio pagado
   Pregunta     : ¿Con cuánta anticipación compran los pasajeros y cuánto pagan según esa anticipación?
   Utilidad     : diseñar promociones de compra anticipada y estimar ventas futuras.
   Granularidad : una fila por tramo de anticipación (días entre la venta y la salida).
   Filtros      : tiquetes de vuelos ya operados entre @fecha_desde y @fecha_hasta (curva completa).
   Fórmulas     : participación = tiquetes del tramo / total (SUM() OVER ()); precio medio por cabina.
                  El precio depende de la tarifa vigente en la fecha de venta y del descuento; la
                  relación es descriptiva y no demuestra causalidad.
   Técnicas     : CTE, CASE, función de ventana sobre agregados, pivote por cabina.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT CASE WHEN dias_anticipacion < 7 THEN '1. 0-6 días'
                WHEN dias_anticipacion < 14 THEN '2. 7-13 días'
                WHEN dias_anticipacion < 30 THEN '3. 14-29 días'
                WHEN dias_anticipacion < 60 THEN '4. 30-59 días'
                ELSE '5. 60 días o más' END AS tramo,
           codigo_cabina, precio_final_usd, porcentaje_descuento
    FROM rpt.v_venta
    WHERE fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
)
SELECT tramo,
       COUNT(*)                                                                         AS tiquetes,
       CAST(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS DECIMAL(7,4))                     AS participacion,
       CAST(AVG(CASE WHEN codigo_cabina = 'ECO' THEN precio_final_usd END) AS DECIMAL(10,2)) AS precio_medio_eco_usd,
       CAST(AVG(CASE WHEN codigo_cabina = 'VIP' THEN precio_final_usd END) AS DECIMAL(10,2)) AS precio_medio_vip_usd,
       CAST(SUM(CASE WHEN porcentaje_descuento > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS penetracion_descuentos
FROM base
GROUP BY tramo
ORDER BY tramo;
