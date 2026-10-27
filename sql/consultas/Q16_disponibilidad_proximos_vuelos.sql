/* =============================================================================
   Q16 · Disponibilidad de los próximos vuelos
   Pregunta     : ¿Cuántas plazas quedan por vender en los vuelos de los próximos días y a qué precio?
   Utilidad     : consulta operativa de venta (CU-06) y alerta de vuelos con baja preventa.
   Granularidad : una fila por vuelo y cabina.
   Filtros      : vuelos PROGRAMADOS o DEMORADOS con salida en los @dias días posteriores a la fecha de corte;
                  @origen opcional (NULL = todos).
   Fórmulas     : disponibles = capacidad - plazas ocupadas; tarifa = la vigente en la fecha de corte.
   Técnicas     : OUTER APPLY con TOP (1), filtros temporales con parámetros, ISNULL.
   ============================================================================= */
DECLARE @dias INT = 3;                  -- @param
DECLARE @origen CHAR(3) = NULL;         -- @param
DECLARE @fecha_corte DATETIME2(0) = (SELECT CAST(valor AS DATETIME2(0)) FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS');

SELECT v.codigo_vuelo, v.ruta, v.salida_programada, o.codigo_cabina, o.estado_vuelo,
       o.capacidad, o.plazas_ocupadas, o.plazas_disponibles, o.factor_ocupacion_vendido,
       tf.precio_base_usd AS tarifa_vigente_usd
FROM rpt.v_ocupacion_vuelo_cabina AS o
JOIN rpt.v_vuelo AS v ON v.id_vuelo = o.id_vuelo
OUTER APPLY (SELECT TOP (1) t.precio_base_usd FROM ven.tarifa AS t
             WHERE t.id_ruta = v.id_ruta AND t.codigo_cabina = o.codigo_cabina
               AND CAST(@fecha_corte AS DATE) BETWEEN t.vigente_desde AND ISNULL(t.vigente_hasta, '99991231')) AS tf
WHERE o.estado_vuelo IN ('PROGRAMADO', 'DEMORADO')
  AND v.salida_programada_utc >= @fecha_corte
  AND v.salida_programada_utc <  DATEADD(DAY, @dias, @fecha_corte)
  AND (@origen IS NULL OR v.origen = @origen)
ORDER BY v.salida_programada_utc, v.codigo_vuelo, o.codigo_cabina;
