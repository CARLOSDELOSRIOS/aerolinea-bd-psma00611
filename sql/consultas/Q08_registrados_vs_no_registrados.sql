/* =============================================================================
   Q08 · Compradores y pasajeros registrados frente a no registrados
   Pregunta     : ¿Qué parte del negocio proviene de clientes con cuenta y cómo se comportan?
   Utilidad     : justificar inversión en el programa de clientes y medir la compra sin registro.
   Granularidad : una fila por condición del comprador (registrado o no en el momento de la compra).
   Filtros      : tiquetes vendidos hasta la fecha de corte.
   Fórmulas     : registrado = existía cuenta (ven.cliente) con fecha de registro <= fecha de venta
                  (LEFT JOIN: sin fila en cliente => no registrado); tiquetes por compra = tiquetes / compras.
   Técnicas     : LEFT JOIN (en la vista rpt.v_venta), CASE, COUNT DISTINCT, agregaciones.
   ============================================================================= */
SELECT CASE WHEN v.comprador_registrado = 1 THEN 'Registrado' ELSE 'No registrado' END     AS comprador,
       COUNT(DISTINCT v.id_compra)                                                           AS compras,
       COUNT(DISTINCT v.id_persona_comprador)                                                AS compradores_distintos,
       COUNT(*)                                                                              AS tiquetes,
       CAST(COUNT(*) * 1.0 / COUNT(DISTINCT v.id_compra) AS DECIMAL(6,2))                    AS tiquetes_por_compra,
       SUM(CASE WHEN v.pasajero_registrado = 1 THEN 1 ELSE 0 END)                            AS pasajeros_registrados,
       SUM(v.precio_final_usd)                                                               AS ventas_brutas_usd,
       CAST(AVG(v.precio_final_usd) AS DECIMAL(10,2))                                        AS precio_medio_usd,
       CAST(SUM(CASE WHEN v.codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_cancelacion,
       CAST(SUM(CASE WHEN v.canal = 'WEB' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS proporcion_web
FROM rpt.v_venta AS v
GROUP BY CASE WHEN v.comprador_registrado = 1 THEN 'Registrado' ELSE 'No registrado' END
ORDER BY comprador DESC;
