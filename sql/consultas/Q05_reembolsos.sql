/* =============================================================================
   Q05 · Cancelaciones con reembolso: motivo, regla y cabina
   Pregunta     : ¿Cuánto se devuelve y cuánto se retiene según la causa de la cancelación?
   Utilidad     : evaluar el costo de la política de cancelación y el efecto de la regla de 24 h.
   Granularidad : una fila por motivo, regla aplicada y cabina.
   Filtros      : tiquetes CANCELADOS.
   Fórmulas     : la regla y el porcentaje se recalculan con ven.fn_politica_reembolso (la misma función
                  que usa el procedimiento de cancelación); tasa de reembolso = reembolsado / cobrado
                  (NULL si no hubo cobro: distingue "sin dinero que devolver" de "0 % devuelto");
                  penalidad retenida = cobrado - reembolsado.
   Técnicas     : CTE, CROSS APPLY con función de tabla en línea, NULLIF, agregaciones.
   ============================================================================= */
WITH cancelados AS (
    SELECT f.id_tiquete, f.codigo_cabina, t.codigo_motivo_cancelacion, f.cobrado_usd, f.reembolsado_usd,
           f.penalidad_retenida_usd, p.regla_aplicada, p.porcentaje_reembolso
    FROM rpt.v_tiquete_financiero AS f
    JOIN ven.tiquete AS t ON t.id_tiquete = f.id_tiquete
    CROSS APPLY ven.fn_politica_reembolso(t.id_tiquete, t.codigo_motivo_cancelacion, t.fecha_cancelacion_utc) AS p
    WHERE f.codigo_estado = 'CANCELADO'
)
SELECT codigo_motivo_cancelacion                                       AS motivo,
       regla_aplicada                                                  AS regla,
       codigo_cabina,
       COUNT(*)                                                        AS tiquetes,
       SUM(CASE WHEN cobrado_usd = 0 THEN 1 ELSE 0 END)                AS sin_cobro,
       CAST(AVG(porcentaje_reembolso) AS DECIMAL(5,1))                 AS porcentaje_politica_medio,
       SUM(cobrado_usd)                                                AS cobrado_usd,
       SUM(reembolsado_usd)                                            AS reembolsado_usd,
       SUM(penalidad_retenida_usd)                                     AS penalidad_retenida_usd,
       CAST(SUM(reembolsado_usd) / NULLIF(SUM(cobrado_usd), 0) AS DECIMAL(7,4)) AS tasa_reembolso
FROM cancelados
GROUP BY codigo_motivo_cancelacion, regla_aplicada, codigo_cabina
ORDER BY motivo, regla, codigo_cabina;
