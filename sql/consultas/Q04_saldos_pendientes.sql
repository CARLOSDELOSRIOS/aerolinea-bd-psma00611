/* =============================================================================
   Q04 · Saldos pendientes de reservas a la fecha de corte
   Pregunta     : ¿Cuánto dinero está comprometido en reservas aún no pagadas y cuándo vencen?
   Utilidad     : gestión de cobranza y previsión de plazas que pueden liberarse por vencimiento.
   Granularidad : una fila por situación de pago y plazo restante.
   Filtros      : tiquetes en estado RESERVADO (las cancelaciones y emisiones no tienen saldo).
   Fórmula      : saldo pendiente = precio final - pagos confirmados; horas al vencimiento =
                  límite de pago - fecha de corte de los datos (ref.parametro FECHA_CORTE_DATOS).
   Técnicas     : JOIN con vista financiera (pagos ya agregados por tiquete), CASE, GROUP BY.
   ============================================================================= */
DECLARE @fecha_corte DATETIME2(0) = (SELECT CAST(valor AS DATETIME2(0)) FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS');

WITH reservas AS (
    SELECT f.id_tiquete, f.precio_final_usd, f.cobrado_usd, f.saldo_pendiente_usd, f.pendiente_confirmacion_usd,
           DATEDIFF(HOUR, @fecha_corte, t.fecha_limite_pago_utc) AS horas_al_vencimiento
    FROM rpt.v_tiquete_financiero AS f
    JOIN ven.tiquete AS t ON t.id_tiquete = f.id_tiquete
    WHERE f.codigo_estado = 'RESERVADO'
)
SELECT CASE WHEN cobrado_usd = 0 AND pendiente_confirmacion_usd = 0 THEN '1. Sin pagos'
            WHEN cobrado_usd = 0 THEN '2. Pago en espera de confirmación'
            ELSE '3. Pago parcial' END                                  AS situacion,
       CASE WHEN horas_al_vencimiento < 24 THEN 'a. vence en menos de 24 h'
            WHEN horas_al_vencimiento < 48 THEN 'b. vence en 24-48 h'
            ELSE 'c. vence en 48 h o más' END                           AS plazo,
       COUNT(*)                                                         AS tiquetes,
       SUM(precio_final_usd)                                            AS valor_reservado_usd,
       SUM(cobrado_usd)                                                 AS abonado_usd,
       SUM(saldo_pendiente_usd)                                         AS saldo_pendiente_usd
FROM reservas
GROUP BY CASE WHEN cobrado_usd = 0 AND pendiente_confirmacion_usd = 0 THEN '1. Sin pagos'
              WHEN cobrado_usd = 0 THEN '2. Pago en espera de confirmación'
              ELSE '3. Pago parcial' END,
         CASE WHEN horas_al_vencimiento < 24 THEN 'a. vence en menos de 24 h'
              WHEN horas_al_vencimiento < 48 THEN 'b. vence en 24-48 h'
              ELSE 'c. vence en 48 h o más' END
ORDER BY situacion, plazo;
