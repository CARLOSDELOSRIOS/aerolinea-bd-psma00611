/* =============================================================================
   Q02 · Ocupación por ruta y cabina (con total por cabina)
   Pregunta     : ¿Qué rutas y cabinas aprovechan mejor la capacidad?
   Utilidad     : decidir frecuencias, tamaño de avión y asignación de asientos VIP por ruta.
   Granularidad : una fila por ruta dirigida y cabina, más una fila TOTAL por cabina (GROUPING SETS).
   Filtros      : vuelos ATERRIZADOS en el período; solo grupos con al menos @min_vuelos vuelos (HAVING).
   Fórmula      : factor ponderado = SUM(pasajeros volados) / SUM(asientos ofrecidos).
                  En la fila TOTAL se compara con el promedio simple de los factores por vuelo: difieren
                  porque las rutas usan aviones de distinta capacidad (un E175 no pesa lo mismo que un A321neo).
   Técnicas     : GROUP BY GROUPING SETS, GROUPING(), HAVING, agregaciones.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param
DECLARE @min_vuelos INT = 20;               -- @param

SELECT CASE WHEN GROUPING(o.ruta) = 1 THEN 'TOTAL' ELSE o.ruta END       AS ruta,
       o.codigo_cabina,
       COUNT(*)                                                           AS vuelos,
       SUM(o.capacidad)                                                   AS asientos_ofrecidos,
       SUM(o.usados)                                                      AS pasajeros_volados,
       CAST(SUM(o.usados) * 1.0 / SUM(o.capacidad) AS DECIMAL(7,4))       AS factor_ponderado,
       CAST(AVG(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS promedio_simple_factores,
       CAST(MIN(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS factor_minimo,
       CAST(MAX(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS factor_maximo,
       SUM(CASE WHEN o.plazas_ocupadas = o.capacidad THEN 1 ELSE 0 END)   AS vuelos_agotados_al_cierre
FROM rpt.v_ocupacion_vuelo_cabina AS o
WHERE o.estado_vuelo = 'ATERRIZADO'
  AND o.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
GROUP BY GROUPING SETS ((o.ruta, o.codigo_cabina), (o.codigo_cabina))
HAVING COUNT(*) >= @min_vuelos
ORDER BY o.codigo_cabina, GROUPING(o.ruta), factor_ponderado DESC;
