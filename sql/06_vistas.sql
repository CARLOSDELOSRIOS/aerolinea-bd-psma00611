/* =============================================================================
   06_vistas.sql
   Propósito : vistas del esquema rpt para consulta y análisis. Encapsulan las
               uniones frecuentes y las fórmulas de negocio para que todas las
               consultas usen las mismas definiciones.
   Reglas de cálculo:
     - Se agregan pagos y reembolsos por tiquete ANTES de unirlos, para no
       multiplicar importes (un tiquete con 2 pagos y 1 reembolso no debe
       duplicar el reembolso).
     - Cobro = pagos en estado CONFIRMADO. Venta = precio final del tiquete.
       Reembolso = salida de dinero. Son magnitudes distintas.
     - Un comprador o pasajero es "registrado" si su cuenta existía en el
       momento de la venta (fecha_registro_utc <= venta).
   Seguridad : el rol de analista solo tiene SELECT sobre rpt (ver 08); las
               vistas no exponen salarios ni datos de pago sensibles.
   Depende de: 05_funciones_y_triggers.sql
   Reinicio  : idempotente (CREATE OR ALTER).
   ============================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script.', 16, 1);
    SET NOEXEC ON;
END
GO

/* Detalle de vuelos con ruta, horarios locales y UTC, demoras y avión. */
CREATE OR ALTER VIEW rpt.v_vuelo
AS
SELECT v.id_vuelo,
       CONCAT('XX', p.numero_vuelo)                                        AS codigo_vuelo,
       p.numero_vuelo,
       p.id_programacion,
       v.fecha_salida_local,
       DATEDIFF(DAY, CAST('19000101' AS DATE), v.fecha_salida_local) % 7 + 1 AS dia_semana_iso,
       r.id_ruta,
       ao.codigo_iata                                                      AS origen,
       ad.codigo_iata                                                      AS destino,
       CONCAT(ao.codigo_iata, '-', ad.codigo_iata)                         AS ruta,
       r.distancia_millas,
       v.salida_programada,
       v.llegada_programada,
       CONVERT(DATETIME2(0), SWITCHOFFSET(v.salida_programada, '+00:00'))  AS salida_programada_utc,
       CONVERT(DATETIME2(0), SWITCHOFFSET(v.llegada_programada, '+00:00')) AS llegada_programada_utc,
       DATEPART(HOUR, v.salida_programada)                                 AS hora_salida_local,
       DATEDIFF(MINUTE, v.salida_programada, v.llegada_programada)         AS duracion_programada_min,
       CASE WHEN CAST(v.llegada_programada AS DATE) > v.fecha_salida_local THEN 1 ELSE 0 END AS llega_dia_siguiente,
       v.salida_estimada,
       v.salida_real,
       v.llegada_real,
       DATEDIFF(MINUTE, v.salida_programada, v.salida_real)                AS demora_salida_min,
       DATEDIFF(MINUTE, v.llegada_programada, v.llegada_real)              AS demora_llegada_min,
       v.codigo_estado,
       v.id_avion,
       a.matricula,
       m.fabricante,
       m.modelo,
       cfg.codigo_configuracion
FROM ops.vuelo                    AS v
JOIN ops.programacion             AS p   ON p.id_programacion = v.id_programacion
JOIN ops.ruta                     AS r   ON r.id_ruta = p.id_ruta
JOIN ref.aeropuerto               AS ao  ON ao.id_localizacion = r.id_aeropuerto_origen
JOIN ref.aeropuerto               AS ad  ON ad.id_localizacion = r.id_aeropuerto_destino
LEFT JOIN ops.avion               AS a   ON a.id_avion = v.id_avion
LEFT JOIN ops.configuracion_asientos AS cfg ON cfg.id_configuracion = a.id_configuracion
LEFT JOIN ref.modelo_avion        AS m   ON m.id_modelo = cfg.id_modelo;
GO

/* Ocupación por vuelo y cabina. Denominador: capacidad de la cabina del avión asignado. */
CREATE OR ALTER VIEW rpt.v_ocupacion_vuelo_cabina
AS
SELECT vc.id_vuelo,
       vc.codigo_cabina,
       v.fecha_salida_local,
       v.codigo_estado                                AS estado_vuelo,
       v.id_ruta,
       v.ruta,
       v.codigo_vuelo,
       vc.capacidad,
       vc.plazas_ocupadas,
       vc.capacidad - vc.plazas_ocupadas              AS plazas_disponibles,
       ISNULL(t.tiquetes_activos, 0)                  AS tiquetes_activos,
       ISNULL(t.reservados, 0)                        AS reservados,
       ISNULL(t.emitidos, 0)                          AS emitidos,
       ISNULL(t.usados, 0)                            AS usados,
       ISNULL(t.no_presentados, 0)                    AS no_presentados,
       ISNULL(t.cancelados, 0)                        AS cancelados,
       CAST(vc.plazas_ocupadas * 1.0 / vc.capacidad AS DECIMAL(7,4)) AS factor_ocupacion_vendido,
       CASE WHEN v.codigo_estado IN ('EN_VUELO', 'ATERRIZADO')
            THEN CAST(ISNULL(t.usados, 0) * 1.0 / vc.capacidad AS DECIMAL(7,4)) END AS factor_ocupacion_volado
FROM ops.vuelo_cabina AS vc
JOIN rpt.v_vuelo      AS v ON v.id_vuelo = vc.id_vuelo
LEFT JOIN (
    SELECT id_vuelo, codigo_cabina,
           SUM(CASE WHEN codigo_estado <> 'CANCELADO' THEN 1 ELSE 0 END)     AS tiquetes_activos,
           SUM(CASE WHEN codigo_estado = 'RESERVADO' THEN 1 ELSE 0 END)      AS reservados,
           SUM(CASE WHEN codigo_estado = 'EMITIDO' THEN 1 ELSE 0 END)        AS emitidos,
           SUM(CASE WHEN codigo_estado = 'USADO' THEN 1 ELSE 0 END)          AS usados,
           SUM(CASE WHEN codigo_estado = 'NO_PRESENTADO' THEN 1 ELSE 0 END)  AS no_presentados,
           SUM(CASE WHEN codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END)      AS cancelados
    FROM ven.tiquete
    GROUP BY id_vuelo, codigo_cabina
) AS t ON t.id_vuelo = vc.id_vuelo AND t.codigo_cabina = vc.codigo_cabina;
GO

/* Situación financiera por tiquete, con pagos y reembolsos agregados por separado. */
CREATE OR ALTER VIEW rpt.v_tiquete_financiero
AS
SELECT t.id_tiquete,
       t.numero_tiquete,
       t.id_compra,
       t.id_vuelo,
       t.codigo_cabina,
       t.codigo_estado,
       t.creado_utc                                                AS fecha_venta_utc,
       t.precio_base_usd,
       t.porcentaje_descuento,
       t.monto_descuento_usd,
       t.precio_final_usd,
       ISNULL(pg.cobrado_usd, 0)                                   AS cobrado_usd,
       ISNULL(pg.pagos_confirmados, 0)                             AS pagos_confirmados,
       ISNULL(pg.pagos_fallidos, 0)                                AS pagos_fallidos,
       ISNULL(pg.pendiente_confirmacion_usd, 0)                    AS pendiente_confirmacion_usd,
       ISNULL(rb.reembolsado_usd, 0)                               AS reembolsado_usd,
       ISNULL(pg.cobrado_usd, 0) - ISNULL(rb.reembolsado_usd, 0)   AS cobro_neto_usd,
       CASE WHEN t.codigo_estado = 'RESERVADO'
            THEN t.precio_final_usd - ISNULL(pg.cobrado_usd, 0) ELSE 0 END AS saldo_pendiente_usd,
       CASE WHEN t.codigo_estado = 'CANCELADO'
            THEN ISNULL(pg.cobrado_usd, 0) - ISNULL(rb.reembolsado_usd, 0) ELSE 0 END AS penalidad_retenida_usd
FROM ven.tiquete AS t
LEFT JOIN (
    SELECT id_tiquete,
           SUM(CASE WHEN codigo_estado = 'CONFIRMADO' THEN monto_usd ELSE 0 END) AS cobrado_usd,
           SUM(CASE WHEN codigo_estado = 'CONFIRMADO' THEN 1 ELSE 0 END)         AS pagos_confirmados,
           SUM(CASE WHEN codigo_estado = 'FALLIDO' THEN 1 ELSE 0 END)            AS pagos_fallidos,
           SUM(CASE WHEN codigo_estado = 'PENDIENTE' THEN monto_usd ELSE 0 END)  AS pendiente_confirmacion_usd
    FROM ven.pago
    GROUP BY id_tiquete
) AS pg ON pg.id_tiquete = t.id_tiquete
LEFT JOIN (
    SELECT p.id_tiquete, SUM(r.monto_usd) AS reembolsado_usd
    FROM ven.reembolso AS r
    JOIN ven.pago      AS p ON p.id_pago = r.id_pago
    GROUP BY p.id_tiquete
) AS rb ON rb.id_tiquete = t.id_tiquete;
GO

/* Dimensiones comerciales de cada venta (una fila por tiquete). */
CREATE OR ALTER VIEW rpt.v_venta
AS
SELECT t.id_tiquete,
       t.numero_tiquete,
       c.id_compra,
       c.codigo_reserva,
       t.creado_utc                                     AS fecha_venta_utc,
       CAST(t.creado_utc AS DATE)                       AS fecha_venta,
       l.codigo_localizacion,
       l.nombre                                         AS localizacion,
       l.tipo_localizacion,
       CASE WHEN l.tipo_localizacion = 'WEB' THEN 'WEB' ELSE 'FISICO' END AS canal,
       c.id_persona_comprador,
       CASE WHEN cc.id_persona IS NOT NULL AND cc.fecha_registro_utc <= t.creado_utc THEN 1 ELSE 0 END AS comprador_registrado,
       t.id_persona_pasajero,
       CASE WHEN cp.id_persona IS NOT NULL AND cp.fecha_registro_utc <= t.creado_utc THEN 1 ELSE 0 END AS pasajero_registrado,
       CASE WHEN t.id_persona_pasajero = c.id_persona_comprador THEN 1 ELSE 0 END AS comprador_es_pasajero,
       t.id_vuelo,
       v.codigo_vuelo,
       v.fecha_salida_local,
       v.id_ruta,
       v.ruta,
       t.codigo_cabina,
       t.codigo_estado,
       t.codigo_motivo_cancelacion,
       t.precio_base_usd,
       t.porcentaje_descuento,
       t.monto_descuento_usd,
       t.precio_final_usd,
       ds.codigo_descuento,
       DATEDIFF(DAY, CAST(t.creado_utc AS DATE), v.fecha_salida_local) AS dias_anticipacion
FROM ven.tiquete          AS t
JOIN ven.compra           AS c  ON c.id_compra = t.id_compra
JOIN ref.localizacion     AS l  ON l.id_localizacion = c.id_localizacion_venta
JOIN rpt.v_vuelo          AS v  ON v.id_vuelo = t.id_vuelo
LEFT JOIN ven.cliente     AS cc ON cc.id_persona = c.id_persona_comprador
LEFT JOIN ven.cliente     AS cp ON cp.id_persona = t.id_persona_pasajero
LEFT JOIN ven.descuento   AS ds ON ds.id_descuento = t.id_descuento;
GO

/* Utilización de flota por avión y fecha operativa (vuelos no cancelados). */
CREATE OR ALTER VIEW rpt.v_utilizacion_avion_dia
AS
SELECT a.id_avion,
       a.matricula,
       m.modelo,
       v.fecha_salida_local,
       COUNT(*)                                                                    AS vuelos,
       SUM(DATEDIFF(MINUTE, v.salida_programada, v.llegada_programada))            AS minutos_bloque_programados,
       SUM(CASE WHEN v.codigo_estado = 'ATERRIZADO'
                THEN DATEDIFF(MINUTE, v.salida_real, v.llegada_real) END)          AS minutos_bloque_reales
FROM ops.vuelo                    AS v
JOIN ops.avion                    AS a   ON a.id_avion = v.id_avion
JOIN ops.configuracion_asientos   AS cfg ON cfg.id_configuracion = a.id_configuracion
JOIN ref.modelo_avion             AS m   ON m.id_modelo = cfg.id_modelo
WHERE v.codigo_estado <> 'CANCELADO'
GROUP BY a.id_avion, a.matricula, m.modelo, v.fecha_salida_local;
GO

/* RN-40: conciliación del inventario controlado contra los tiquetes que ocupan plaza. */
CREATE OR ALTER VIEW rpt.v_conciliacion_inventario
AS
SELECT vc.id_vuelo,
       vc.codigo_cabina,
       vc.capacidad,
       vc.plazas_ocupadas,
       ISNULL(t.ocupan, 0)                        AS tiquetes_que_ocupan,
       vc.plazas_ocupadas - ISNULL(t.ocupan, 0)   AS diferencia
FROM ops.vuelo_cabina AS vc
LEFT JOIN (
    SELECT t.id_vuelo, t.codigo_cabina, COUNT(*) AS ocupan
    FROM ven.tiquete AS t
    JOIN ref.estado_tiquete AS e ON e.codigo_estado = t.codigo_estado
    WHERE e.ocupa_inventario = 1
    GROUP BY t.id_vuelo, t.codigo_cabina
) AS t ON t.id_vuelo = vc.id_vuelo AND t.codigo_cabina = vc.codigo_cabina;
GO

/* Programación con los días operados en columnas (compatible con SQL Server 2016). */
CREATE OR ALTER VIEW rpt.v_programacion
AS
SELECT p.id_programacion,
       CONCAT('XX', p.numero_vuelo) AS codigo_vuelo,
       CONCAT(ao.codigo_iata, '-', ad.codigo_iata) AS ruta,
       p.hora_salida_local,
       p.duracion_programada_min,
       p.vigente_desde,
       p.vigente_hasta,
       p.activa,
       MAX(CASE WHEN d.dia_semana = 1 THEN 1 ELSE 0 END) AS lun,
       MAX(CASE WHEN d.dia_semana = 2 THEN 1 ELSE 0 END) AS mar,
       MAX(CASE WHEN d.dia_semana = 3 THEN 1 ELSE 0 END) AS mie,
       MAX(CASE WHEN d.dia_semana = 4 THEN 1 ELSE 0 END) AS jue,
       MAX(CASE WHEN d.dia_semana = 5 THEN 1 ELSE 0 END) AS vie,
       MAX(CASE WHEN d.dia_semana = 6 THEN 1 ELSE 0 END) AS sab,
       MAX(CASE WHEN d.dia_semana = 7 THEN 1 ELSE 0 END) AS dom,
       COUNT(d.dia_semana) AS dias_por_semana
FROM ops.programacion          AS p
JOIN ops.ruta                  AS r  ON r.id_ruta = p.id_ruta
JOIN ref.aeropuerto            AS ao ON ao.id_localizacion = r.id_aeropuerto_origen
JOIN ref.aeropuerto            AS ad ON ad.id_localizacion = r.id_aeropuerto_destino
LEFT JOIN ops.programacion_dia AS d  ON d.id_programacion = p.id_programacion
GROUP BY p.id_programacion, p.numero_vuelo, ao.codigo_iata, ad.codigo_iata, p.hora_salida_local,
         p.duracion_programada_min, p.vigente_desde, p.vigente_hasta, p.activa;
GO

/* Empleados sin datos confidenciales (sin salario) para usuarios de reportes. */
CREATE OR ALTER VIEW rpt.v_empleado
AS
SELECT e.id_empleado,
       e.numero_empleado,
       CONCAT(e.nombres, N' ', e.apellidos) AS nombre_completo,
       e.codigo_cargo,
       c.nombre                    AS cargo,
       c.categoria_tripulacion,
       d.nombre                    AS departamento,
       l.codigo_localizacion       AS base,
       e.fecha_contratacion,
       e.fecha_terminacion,
       CASE WHEN e.fecha_terminacion IS NULL THEN 1 ELSE 0 END AS activo
FROM rh.empleado        AS e
JOIN rh.cargo           AS c ON c.codigo_cargo = e.codigo_cargo
JOIN rh.departamento    AS d ON d.codigo_departamento = c.codigo_departamento
JOIN ref.localizacion   AS l ON l.id_localizacion = e.id_localizacion_base;
GO

/* Tripulación asignada por vuelo, con duración para el cálculo de horas. */
CREATE OR ALTER VIEW rpt.v_tripulacion_vuelo
AS
SELECT a.id_vuelo,
       v.codigo_vuelo,
       v.fecha_salida_local,
       v.ruta,
       v.codigo_estado AS estado_vuelo,
       a.id_empleado,
       e.numero_empleado,
       e.nombre_completo,
       a.rol_vuelo,
       v.duracion_programada_min,
       CASE WHEN v.codigo_estado = 'ATERRIZADO' THEN DATEDIFF(MINUTE, v.salida_real, v.llegada_real) END AS minutos_reales
FROM ops.asignacion_tripulacion AS a
JOIN rpt.v_vuelo                AS v ON v.id_vuelo = a.id_vuelo
JOIN rpt.v_empleado             AS e ON e.id_empleado = a.id_empleado;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '06_vistas')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('06_vistas', N'Vistas de reporte');
GO
SET NOEXEC OFF;
GO
