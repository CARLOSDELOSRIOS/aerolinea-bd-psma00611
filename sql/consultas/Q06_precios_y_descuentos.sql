/* =============================================================================
   Q06 · Precio medio y descuento efectivo por ruta y cabina
   Pregunta     : ¿Cuánto paga en promedio un pasajero y cuánto se resigna en descuentos?
   Utilidad     : evaluar política de precios y promociones por mercado.
   Granularidad : una fila por ruta y cabina.
   Filtros      : tiquetes vendidos entre @fecha_desde y @fecha_hasta (fecha de venta UTC), excluidos los vencidos sin pago.
   Fórmulas     : precio medio final = AVG(precio final); tasa de descuento efectiva =
                  SUM(monto descontado) / SUM(precio base) (ponderada por importe);
                  penetración = tiquetes con descuento / tiquetes.
   Técnicas     : GROUP BY, agregaciones condicionales, división protegida con NULLIF.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.ruta,
       v.codigo_cabina,
       COUNT(*)                                                                          AS tiquetes,
       CAST(AVG(v.precio_base_usd) AS DECIMAL(10,2))                                     AS precio_base_medio_usd,
       CAST(AVG(v.precio_final_usd) AS DECIMAL(10,2))                                    AS precio_final_medio_usd,
       CAST(SUM(v.monto_descuento_usd) / NULLIF(SUM(v.precio_base_usd), 0) AS DECIMAL(7,4)) AS tasa_descuento_efectiva,
       CAST(SUM(CASE WHEN v.porcentaje_descuento > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS penetracion_descuentos,
       MIN(v.precio_final_usd)                                                           AS precio_final_minimo_usd,
       MAX(v.precio_final_usd)                                                           AS precio_final_maximo_usd
FROM rpt.v_venta AS v
WHERE v.fecha_venta BETWEEN @fecha_desde AND @fecha_hasta
  AND NOT (v.codigo_estado = 'CANCELADO' AND v.codigo_motivo_cancelacion = 'VENCIMIENTO')
GROUP BY v.ruta, v.codigo_cabina
ORDER BY v.codigo_cabina, precio_final_medio_usd DESC;
