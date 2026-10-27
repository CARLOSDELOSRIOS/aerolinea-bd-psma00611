/* =============================================================================
   Q03 · Ventas, cobros y reembolsos por mes
   Pregunta     : ¿Cuánto se vendió, cuánto se cobró y cuánto se devolvió cada mes?
   Utilidad     : flujo de caja comercial; distingue el valor vendido del dinero recibido.
   Granularidad : una fila por mes calendario (UTC).
   Filtros      : eventos entre @fecha_desde y @fecha_hasta.
   Fórmulas     : ventas brutas = SUM(precio final) de los tiquetes creados en el mes (incluye los
                  que luego se cancelaron); ventas vigentes = las no canceladas;
                  cobros = SUM(pagos CONFIRMADOS) por fecha de confirmación;
                  reembolsos = SUM(reembolsos) por fecha de reembolso;
                  cobro neto = cobros - reembolsos.
                  Cada medida se agrega por SU PROPIA fecha en una CTE separada: unir pagos y
                  reembolsos fila a fila multiplicaría importes.
   Técnicas     : CTE múltiples, UNION, LEFT JOIN, agregaciones condicionales.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-12-31';   -- @param

WITH ventas AS (
    SELECT DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1) AS mes,
           COUNT(*)                                                         AS tiquetes_vendidos,
           SUM(precio_final_usd)                                            AS ventas_brutas_usd,
           SUM(CASE WHEN codigo_estado <> 'CANCELADO' THEN precio_final_usd ELSE 0 END) AS ventas_vigentes_usd
    FROM ven.tiquete
    WHERE CAST(creado_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1)
), cobros AS (
    SELECT DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1) AS mes,
           COUNT(*) AS pagos_confirmados, SUM(monto_usd) AS cobros_usd
    FROM ven.pago
    WHERE codigo_estado = 'CONFIRMADO' AND CAST(fecha_resolucion_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1)
), reembolsos AS (
    SELECT DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1) AS mes,
           SUM(monto_usd) AS reembolsos_usd
    FROM ven.reembolso
    WHERE CAST(fecha_reembolso_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1)
), meses AS (
    SELECT mes FROM ventas UNION SELECT mes FROM cobros UNION SELECT mes FROM reembolsos
)
SELECT m.mes,
       ISNULL(v.tiquetes_vendidos, 0)                          AS tiquetes_vendidos,
       ISNULL(v.ventas_brutas_usd, 0)                          AS ventas_brutas_usd,
       ISNULL(v.ventas_vigentes_usd, 0)                        AS ventas_vigentes_usd,
       ISNULL(c.pagos_confirmados, 0)                          AS pagos_confirmados,
       ISNULL(c.cobros_usd, 0)                                 AS cobros_usd,
       ISNULL(r.reembolsos_usd, 0)                             AS reembolsos_usd,
       ISNULL(c.cobros_usd, 0) - ISNULL(r.reembolsos_usd, 0)   AS cobro_neto_usd
FROM meses AS m
LEFT JOIN ventas     AS v ON v.mes = m.mes
LEFT JOIN cobros     AS c ON c.mes = m.mes
LEFT JOIN reembolsos AS r ON r.mes = m.mes
ORDER BY m.mes;
