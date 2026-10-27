/* =============================================================================
   Q18 · Carga de vuelo de la tripulación en 672 horas consecutivas
   Pregunta     : ¿Cómo se reparte la carga de vuelo y algún piloto excede el límite acumulado?
   Utilidad     : planificación de personal y control de cumplimiento; control de la regla RN-35.
   Granularidad : una fila por rol de vuelo.
   Filtros      : vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta
                  (28 días = 672 horas, la ventana del límite de 14 CFR 117.23(b)(1)).
   Fórmulas     : horas por tripulante = minutos de bloque programados / 60 (cota superior del tiempo de
                  vuelo); pilotos sobre el límite = pilotos con más de 100 h en la ventana;
                  vuelos operados sin dos pilotos (debe ser 0: lo impide el trigger de vuelo).
                  El límite se aplica a pilotos; para tripulantes de cabina es solo referencia.
   Técnicas     : CTE, agregaciones, agregación condicional, subconsulta escalar de control.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-10-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-28';   -- @param

WITH por_tripulante AS (
    SELECT t.rol_vuelo, t.id_empleado, COUNT(*) AS vuelos, SUM(t.duracion_programada_min) / 60.0 AS horas
    FROM rpt.v_tripulacion_vuelo AS t
    WHERE t.estado_vuelo <> 'CANCELADO' AND t.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY t.rol_vuelo, t.id_empleado
)
SELECT rol_vuelo,
       COUNT(*)                                                         AS tripulantes,
       SUM(vuelos)                                                      AS asignaciones,
       CAST(MIN(horas) AS DECIMAL(7,1))                                 AS horas_minimas,
       CAST(AVG(horas) AS DECIMAL(7,1))                                 AS horas_promedio,
       CAST(MAX(horas) AS DECIMAL(7,1))                                 AS horas_maximas,
       SUM(CASE WHEN rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL') AND horas > 100 THEN 1 ELSE 0 END) AS pilotos_sobre_100h,
       (SELECT COUNT(*) FROM ops.vuelo AS v
        WHERE v.codigo_estado IN ('EN_VUELO', 'ATERRIZADO') AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
          AND (SELECT COUNT(*) FROM ops.asignacion_tripulacion AS a
               WHERE a.id_vuelo = v.id_vuelo AND a.rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL')) < 2) AS vuelos_operados_sin_pilotos
FROM por_tripulante
GROUP BY rol_vuelo
ORDER BY rol_vuelo;
