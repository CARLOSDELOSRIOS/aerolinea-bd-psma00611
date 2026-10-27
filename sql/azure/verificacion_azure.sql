/* =============================================================================
   azure/verificacion_azure.sql
   Propósito : evidencia de SOLO LECTURA de que la base del proyecto está
               desplegada y cargada en Azure SQL Database. Ejecútelo en SSMS
               conectado a la base AerolineaDB del servidor de Azure y guarde la
               salida (texto o captura) en evidence/azure/.
   Comparación: los conteos y sumas de control deben coincidir con los del
               entorno local cargado con la misma semilla (evidence/<entorno>/).
   ============================================================================= */
SET NOCOUNT ON;

-- 1. ¿Es realmente Azure SQL Database? (EngineEdition 5 = Azure SQL Database)
SELECT @@SERVERNAME                                        AS servidor,
       DB_NAME()                                           AS base_datos,
       CAST(SERVERPROPERTY('EngineEdition') AS int)        AS edicion_motor,
       CAST(SERVERPROPERTY('Edition') AS nvarchar(128))    AS edicion,
       CAST(DATABASEPROPERTYEX(DB_NAME(), 'Edition') AS nvarchar(128))          AS nivel,
       CAST(DATABASEPROPERTYEX(DB_NAME(), 'ServiceObjective') AS nvarchar(128)) AS objetivo_servicio,
       CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS version,
       SUSER_SNAME()                                       AS usuario_actual,
       SYSUTCDATETIME()                                    AS momento_utc;

-- 2. Conexión cifrada y método de autenticación de esta sesión
SELECT c.encrypt_option AS cifrado, c.auth_scheme AS esquema_autenticacion, c.net_transport AS protocolo,
       s.program_name AS programa
FROM sys.dm_exec_connections AS c
JOIN sys.dm_exec_sessions AS s ON s.session_id = c.session_id
WHERE c.session_id = @@SPID;

-- 3. Configuración de la base
SELECT name, compatibility_level, collation_name, is_read_committed_snapshot_on
FROM sys.databases WHERE name = DB_NAME();

-- 4. Scripts desplegados y carga registrada
SELECT script, descripcion, ejecutado_utc, usuario, version_motor
FROM adm.registro_despliegue ORDER BY id_registro;

-- 5. Objetos por tipo (deben coincidir con el entorno local)
SELECT s.name AS esquema, o.type_desc AS tipo, COUNT(*) AS objetos
FROM sys.objects AS o JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0 AND s.name IN (N'ref', N'ops', N'rh', N'ven', N'rpt', N'aud', N'adm', N'stg', N'tst')
GROUP BY s.name, o.type_desc
ORDER BY s.name, o.type_desc;

-- 6. Filas por tabla
SELECT s.name + N'.' + t.name AS tabla, SUM(p.rows) AS filas
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name IN (N'ref', N'ops', N'rh', N'ven', N'aud')
GROUP BY s.name, t.name
ORDER BY tabla;

-- 7. Sumas de control de negocio (mismo resultado esperado que en local)
SELECT (SELECT COUNT(*) FROM ven.tiquete)                                         AS tiquetes,
       (SELECT SUM(precio_final_usd) FROM ven.tiquete)                            AS suma_precio_final_usd,
       (SELECT SUM(monto_usd) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO')   AS suma_cobros_usd,
       (SELECT SUM(monto_usd) FROM ven.reembolso)                                 AS suma_reembolsos_usd,
       (SELECT CHECKSUM_AGG(CHECKSUM(id_tiquete, numero_tiquete, codigo_estado, precio_final_usd)) FROM ven.tiquete) AS checksum_tiquetes,
       (SELECT CHECKSUM_AGG(CHECKSUM(id_pago, codigo_estado, monto_usd)) FROM ven.pago)                              AS checksum_pagos;

-- 8. Controles de integridad: todos deben ser 0
SELECT (SELECT COUNT(*) FROM rpt.v_conciliacion_inventario WHERE diferencia <> 0)              AS inventario_descuadrado,
       (SELECT COUNT(*) FROM rpt.v_tiquete_financiero WHERE cobrado_usd > precio_final_usd)     AS tiquetes_sobrecobrados,
       (SELECT COUNT(*) FROM ops.vuelo_cabina WHERE plazas_ocupadas > capacidad)                 AS cabinas_sobrevendidas;

-- 9. Zonas horarias disponibles en el servicio
SELECT name, current_utc_offset, is_currently_dst
FROM sys.time_zone_info
WHERE name IN (N'Eastern Standard Time', N'Central Standard Time', N'Mountain Standard Time',
               N'US Mountain Standard Time', N'Pacific Standard Time', N'Hawaiian Standard Time')
ORDER BY name;
