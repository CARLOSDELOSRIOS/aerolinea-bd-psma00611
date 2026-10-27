/* =============================================================================
   Q20 · Uso y costo de los descuentos
   Pregunta     : ¿Qué descuentos se usan, cuánto cuestan y a quién benefician?
   Utilidad     : evaluar campañas y la política de un descuento por tiquete.
   Granularidad : una fila por código de descuento (incluye los no usados).
   Filtros      : tiquetes no cancelados.
   Fórmulas     : costo = SUM(monto descontado); costo relativo = costo / SUM(precio base de esos tiquetes);
                  participación de registrados = tiquetes de compradores registrados / tiquetes con el código.
   Técnicas     : LEFT JOIN desde el catálogo (muestra códigos sin uso con 0), agregaciones, ISNULL.
   ============================================================================= */
SELECT d.codigo_descuento,
       d.porcentaje,
       d.codigo_cabina,
       d.solo_clientes_registrados,
       COUNT(v.id_tiquete)                                                             AS tiquetes,
       ISNULL(SUM(v.monto_descuento_usd), 0)                                           AS costo_descuento_usd,
       CAST(SUM(v.monto_descuento_usd) / NULLIF(SUM(v.precio_base_usd), 0) AS DECIMAL(7,4)) AS costo_relativo,
       CAST(SUM(v.comprador_registrado) * 1.0 / NULLIF(COUNT(v.id_tiquete), 0) AS DECIMAL(7,4)) AS participacion_registrados
FROM ven.descuento AS d
LEFT JOIN rpt.v_venta AS v ON v.codigo_descuento = d.codigo_descuento AND v.codigo_estado <> 'CANCELADO'
GROUP BY d.codigo_descuento, d.porcentaje, d.codigo_cabina, d.solo_clientes_registrados
ORDER BY tiquetes DESC, d.codigo_descuento;
