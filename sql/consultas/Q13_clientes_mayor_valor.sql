/* =============================================================================
   Q13 · Clientes registrados de mayor valor
   Pregunta     : ¿Qué clientes registrados generan más cobro neto?
   Utilidad     : segmentación para fidelización (niveles de lealtad, beneficios).
   Granularidad : una fila por cliente (los @top primeros).
   Filtros      : compras realizadas como comprador registrado.
   Fórmulas     : cobro neto por cliente = SUM(pagos confirmados - reembolsos) de sus tiquetes,
                  calculado desde rpt.v_tiquete_financiero (ya agregado por tiquete, sin duplicar).
   Técnicas     : CTE, JOIN, DENSE_RANK(), TOP con parámetro.
   ============================================================================= */
DECLARE @top INT = 10;   -- @param

WITH por_cliente AS (
    SELECT c.id_persona_comprador AS id_persona,
           COUNT(DISTINCT c.id_compra) AS compras,
           COUNT(*)                    AS tiquetes,
           SUM(f.cobro_neto_usd)       AS cobro_neto_usd
    FROM ven.compra AS c
    JOIN ven.cliente AS cl ON cl.id_persona = c.id_persona_comprador AND cl.fecha_registro_utc <= c.fecha_compra_utc
    JOIN rpt.v_tiquete_financiero AS f ON f.id_compra = c.id_compra
    GROUP BY c.id_persona_comprador
)
SELECT TOP (@top)
       DENSE_RANK() OVER (ORDER BY p.cobro_neto_usd DESC) AS rango,
       cl.numero_viajero,
       cl.nivel_lealtad,
       p.compras,
       p.tiquetes,
       p.cobro_neto_usd,
       CAST(p.cobro_neto_usd / p.tiquetes AS DECIMAL(10,2)) AS cobro_neto_por_tiquete_usd
FROM por_cliente AS p
JOIN ven.cliente AS cl ON cl.id_persona = p.id_persona
ORDER BY rango, cl.numero_viajero;
