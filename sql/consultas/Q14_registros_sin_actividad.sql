/* =============================================================================
   Q14 · Registros sin actividad (anti-joins)
   Pregunta     : ¿Qué clientes, rutas, aviones y descuentos no tienen actividad?
   Utilidad     : limpieza comercial, rutas en evaluación, flota de reserva y campañas sin uso.
   Granularidad : una fila por categoría.
   Filtros      : situación a la fecha de corte.
   Fórmula      : conteo de filas sin correspondencia (LEFT JOIN ... IS NULL / NOT EXISTS).
   Técnicas     : LEFT JOIN con IS NULL, NOT EXISTS, UNION ALL.
   ============================================================================= */
SELECT 'Clientes registrados sin compras' AS categoria, COUNT(*) AS cantidad
FROM ven.cliente AS cl
LEFT JOIN ven.compra AS c ON c.id_persona_comprador = cl.id_persona
WHERE c.id_compra IS NULL
UNION ALL
SELECT 'Rutas sin programación (en evaluación)', COUNT(*)
FROM ops.ruta AS r
WHERE NOT EXISTS (SELECT 1 FROM ops.programacion AS p WHERE p.id_ruta = r.id_ruta)
UNION ALL
SELECT 'Aviones sin vuelos asignados', COUNT(*)
FROM ops.avion AS a
LEFT JOIN ops.vuelo AS v ON v.id_avion = a.id_avion
WHERE v.id_vuelo IS NULL
UNION ALL
SELECT 'Descuentos nunca aplicados', COUNT(*)
FROM ven.descuento AS d
WHERE NOT EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_descuento = d.id_descuento)
UNION ALL
SELECT 'Empleados de cabina o vuelo sin asignaciones', COUNT(*)
FROM rh.empleado AS e
JOIN rh.cargo AS c ON c.codigo_cargo = e.codigo_cargo AND c.categoria_tripulacion IS NOT NULL
WHERE NOT EXISTS (SELECT 1 FROM ops.asignacion_tripulacion AS a WHERE a.id_empleado = e.id_empleado)
ORDER BY 1;   -- orden determinista del UNION ALL (por categoría)
