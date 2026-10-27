/* =============================================================================
   Q07 · Ventas por canal y punto de venta
   Pregunta     : ¿Qué peso tienen los canales web y físico y cada punto de venta?
   Utilidad     : dimensionar mostradores, oficinas y canales digitales.
   Granularidad : una fila por canal y localización de venta.
   Filtros      : tiquetes no cancelados vendidos entre @fecha_desde y @fecha_hasta.
   Fórmulas     : participación = ventas del punto / ventas totales (SUM() OVER ()).
                  participación en el canal = ventas del punto / ventas del canal (SUM() OVER (PARTITION BY canal)).
   Técnicas     : GROUP BY, funciones de ventana sobre agregados.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.canal,
       v.tipo_localizacion,
       v.codigo_localizacion,
       COUNT(DISTINCT v.id_compra)                                                    AS compras,
       COUNT(*)                                                                       AS tiquetes,
       SUM(v.precio_final_usd)                                                        AS ventas_usd,
       CAST(SUM(v.precio_final_usd) * 1.0 / SUM(SUM(v.precio_final_usd)) OVER () AS DECIMAL(7,4)) AS participacion_total,
       CAST(SUM(v.precio_final_usd) * 1.0 / SUM(SUM(v.precio_final_usd)) OVER (PARTITION BY v.canal) AS DECIMAL(7,4)) AS participacion_en_canal
FROM rpt.v_venta AS v
WHERE v.fecha_venta BETWEEN @fecha_desde AND @fecha_hasta
  AND v.codigo_estado <> 'CANCELADO'
GROUP BY v.canal, v.tipo_localizacion, v.codigo_localizacion
ORDER BY v.canal, ventas_usd DESC;
