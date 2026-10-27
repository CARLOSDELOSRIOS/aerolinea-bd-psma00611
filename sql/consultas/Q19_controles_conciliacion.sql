/* =============================================================================
   Q19 · Controles de integridad y conciliación
   Pregunta     : ¿Los datos son internamente coherentes?
   Utilidad     : auditoría; cada fila debe devolver 0 diferencias.
   Granularidad : una fila por control.
   Filtros      : ninguno; se revisa toda la base (todos los vuelos, tiquetes,
                  pagos y reembolsos cargados).
   Fórmulas     : identidad de conciliación (todo el período):
                  cobros - reembolsos = precio final de tiquetes emitidos/usados/no presentados
                                       + abonos de reservas vigentes + penalidades retenidas.
   Técnicas     : UNION ALL de subconsultas con ORDER BY final (orden determinista), agregaciones con pre-agregación (sin abanico de importes).
   ============================================================================= */
SELECT 'Inventario distinto de tiquetes que ocupan plaza' AS control,
       COUNT(*) AS filas_con_diferencia, CAST(NULL AS DECIMAL(14,2)) AS diferencia_usd
FROM rpt.v_conciliacion_inventario WHERE diferencia <> 0
UNION ALL
SELECT 'Plazas ocupadas por encima de la capacidad', COUNT(*), NULL
FROM ops.vuelo_cabina WHERE plazas_ocupadas > capacidad
UNION ALL
SELECT 'Asientos duplicados en tiquetes activos', COUNT(*), NULL
FROM (SELECT t.id_vuelo, t.codigo_asiento FROM ven.tiquete AS t
      JOIN ref.estado_tiquete AS e ON e.codigo_estado = t.codigo_estado AND e.ocupa_inventario = 1
      WHERE t.codigo_asiento IS NOT NULL
      GROUP BY t.id_vuelo, t.codigo_asiento HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'Cobros confirmados mayores que el precio final', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE cobrado_usd > precio_final_usd
UNION ALL
SELECT 'Reembolsos mayores que lo cobrado', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE reembolsado_usd > cobrado_usd
UNION ALL
SELECT 'Tiquetes emitidos, usados o no presentados sin pago total', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') AND cobrado_usd <> precio_final_usd
UNION ALL
SELECT 'Tiquetes con precio base distinto de su tarifa', COUNT(*), NULL
FROM ven.tiquete AS t JOIN ven.tarifa AS tf ON tf.id_tarifa = t.id_tarifa WHERE t.precio_base_usd <> tf.precio_base_usd
UNION ALL
SELECT 'Vuelos operados con reservas sin pagar', COUNT(DISTINCT t.id_vuelo), NULL
FROM ven.tiquete AS t JOIN ops.vuelo AS v ON v.id_vuelo = t.id_vuelo
WHERE v.codigo_estado IN ('EN_VUELO', 'ATERRIZADO') AND t.codigo_estado = 'RESERVADO'
UNION ALL
SELECT 'Identidad de conciliación de caja (USD)', CASE WHEN x.diferencia = 0 THEN 0 ELSE 1 END, x.diferencia
FROM (SELECT (SELECT SUM(monto_usd) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO')
           - (SELECT ISNULL(SUM(monto_usd), 0) FROM ven.reembolso)
           - (SELECT SUM(CASE WHEN codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') THEN precio_final_usd
                              WHEN codigo_estado = 'RESERVADO' THEN cobrado_usd
                              ELSE penalidad_retenida_usd END)
              FROM rpt.v_tiquete_financiero) AS diferencia) AS x
ORDER BY control;   -- sin ORDER BY, el orden de las filas de un UNION ALL no está garantizado
