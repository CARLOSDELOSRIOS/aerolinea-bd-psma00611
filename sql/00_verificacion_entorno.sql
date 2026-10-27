/* =============================================================================
   00_verificacion_entorno.sql
   Propósito : diagnóstico de solo lectura del motor y de los permisos del
               usuario conectado. No crea ni modifica objetos.
   Dónde     : SSMS, conectado a la instancia (cualquier base, p. ej. master).
   Resultado : copie la salida en evidence/laptop_windows/ (texto o captura).
   ============================================================================= */
SET NOCOUNT ON;

-- 1. Identificación del servidor (consulta solicitada en el enunciado del encargo)
SELECT
    @@SERVERNAME                                   AS servidor,
    SERVERPROPERTY('Edition')                      AS edicion,
    SERVERPROPERTY('ProductVersion')               AS version,
    SUSER_SNAME()                                  AS usuario_actual;

-- 2. Detalle del motor
SELECT
    SERVERPROPERTY('ProductMajorVersion')          AS version_mayor,       -- 13=2016, 14=2017, 15=2019, 16=2022, 17=2025
    SERVERPROPERTY('ProductLevel')                 AS nivel,               -- RTM, SPn
    SERVERPROPERTY('ProductUpdateLevel')           AS actualizacion_cu,
    SERVERPROPERTY('EngineEdition')                AS edicion_motor,       -- 2=Standard, 3=Enterprise/Developer, 4=Express, 5=Azure SQL Database
    SERVERPROPERTY('InstanceName')                 AS instancia,           -- NULL = instancia predeterminada (MSSQLSERVER)
    SERVERPROPERTY('Collation')                    AS intercalacion_servidor,
    SERVERPROPERTY('IsIntegratedSecurityOnly')     AS solo_autenticacion_windows,
    @@VERSION                                      AS version_completa;

-- 3. Conexión actual: protocolo, cifrado y esquema de autenticación
SELECT
    c.net_transport                                AS protocolo,           -- Shared memory, TCP, Named pipe
    c.encrypt_option                               AS cifrado,             -- TRUE/FALSE
    c.auth_scheme                                  AS esquema_autenticacion, -- NTLM/KERBEROS = Windows; SQL = inicio de sesión SQL
    c.client_net_address                           AS direccion_cliente,
    s.program_name                                 AS programa
FROM sys.dm_exec_connections AS c
JOIN sys.dm_exec_sessions    AS s ON s.session_id = c.session_id
WHERE c.session_id = @@SPID;

-- 4. Permisos del usuario: ¿puede crear la base de datos del proyecto?
SELECT
    IS_SRVROLEMEMBER('sysadmin')                   AS es_sysadmin,
    IS_SRVROLEMEMBER('dbcreator')                  AS es_dbcreator,
    HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE ANY DATABASE') AS puede_crear_bd,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE')   AS puede_ver_estado;

-- 5. Zonas horarias que usa el proyecto (deben devolver 6 filas)
SELECT name, current_utc_offset, is_currently_dst
FROM sys.time_zone_info
WHERE name IN (N'Eastern Standard Time', N'Central Standard Time', N'Mountain Standard Time',
               N'US Mountain Standard Time', N'Pacific Standard Time', N'Hawaiian Standard Time')
ORDER BY name;

-- 6. ¿Existe ya la base del proyecto?
SELECT name, compatibility_level, collation_name, is_read_committed_snapshot_on, state_desc
FROM sys.databases
WHERE name = N'AerolineaDB';

-- 7. Requisito mínimo del proyecto: SQL Server 2016 SP1 (13.0.4001) o superior
SELECT CASE
           WHEN CAST(SERVERPROPERTY('EngineEdition') AS int) = 5 THEN N'Azure SQL Database: compatible'
           WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS int) > 13 THEN N'Compatible'
           WHEN CAST(SERVERPROPERTY('ProductMajorVersion') AS int) = 13
                AND CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(20)), 2) AS int) >= 4001
                THEN N'Compatible (2016 SP1 o superior)'
           ELSE N'NO compatible: se requiere SQL Server 2016 SP1 o superior'
       END AS compatibilidad_proyecto;
