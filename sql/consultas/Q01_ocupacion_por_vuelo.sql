/* =============================================================================
   Q01 · Ocupación por vuelo operado
   Pregunta     : ¿Qué tan llenos salieron los vuelos y cómo se ubica cada uno dentro de su ruta?
   Utilidad     : detectar vuelos con baja ocupación (candidatos a cambio de equipo u horario) y saturados.
   Granularidad : una fila por vuelo ATERRIZADO.
   Filtros      : fecha local de salida entre @fecha_desde y @fecha_hasta.
   Fórmula      : factor de ocupación = pasajeros volados (tiquetes USADO) / asientos ofrecidos del avión.
                  Los no presentados ocupan plaza vendida pero no cuentan como volados.
   Técnicas     : JOIN con vistas, GROUP BY, SUM, RANK() OVER (PARTITION BY ruta).
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH por_vuelo AS (
    SELECT v.id_vuelo, v.codigo_vuelo, v.ruta, v.fecha_salida_local, v.matricula, v.modelo,
           SUM(o.capacidad)        AS asientos_ofrecidos,
           SUM(o.plazas_ocupadas)  AS plazas_vendidas,
           SUM(o.usados)           AS pasajeros_volados,
           SUM(o.no_presentados)   AS no_presentados
    FROM rpt.v_vuelo AS v
    JOIN rpt.v_ocupacion_vuelo_cabina AS o ON o.id_vuelo = v.id_vuelo
    WHERE v.codigo_estado = 'ATERRIZADO'
      AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY v.id_vuelo, v.codigo_vuelo, v.ruta, v.fecha_salida_local, v.matricula, v.modelo
)
SELECT id_vuelo, codigo_vuelo, ruta, fecha_salida_local, matricula, modelo,
       asientos_ofrecidos, plazas_vendidas, pasajeros_volados, no_presentados,
       CAST(pasajeros_volados * 1.0 / asientos_ofrecidos AS DECIMAL(7,4)) AS factor_ocupacion,
       RANK() OVER (PARTITION BY ruta ORDER BY pasajeros_volados * 1.0 / asientos_ofrecidos DESC) AS rango_en_ruta
FROM por_vuelo
ORDER BY ruta, fecha_salida_local, codigo_vuelo;
