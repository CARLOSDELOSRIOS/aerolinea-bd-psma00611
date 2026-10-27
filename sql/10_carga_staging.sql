/* =============================================================================
   10_carga_staging.sql
   Propósito : área de carga (staging) y procedimiento que aplica los datos
               sintéticos generados por Python (src/aerolinea/generador.py).
   Diseño    :
     - Python genera filas deterministas (semilla fija) y las inserta en stg.*
       con inserción masiva. Las tablas stg no tienen restricciones.
     - stg.usp_aplicar_carga_sintetica mueve los datos al modelo siguiendo el
       MISMO ciclo de vida que la operación real: tiquetes RESERVADOS -> pagos
       -> EMITIDOS -> demoras/cancelaciones -> salidas y llegadas -> USADO /
       NO_PRESENTADO. Los triggers NO se desactivan: cada fila sintética pasa
       por las mismas validaciones que una venta real (precio, descuento,
       asiento, capacidad, transiciones, solapes, pagos y reembolsos).
     - Todo ocurre en una sola transacción: o se carga todo, o nada.
   Alternativa sin Python: cargar los CSV de data/sintetico en stg con
   BULK INSERT o el asistente de importación de SSMS y ejecutar el procedimiento.
   Reinicio  : idempotente.
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

IF OBJECT_ID(N'stg.vuelo_plan', N'U') IS NULL
CREATE TABLE stg.vuelo_plan (id_vuelo INT NOT NULL, id_avion SMALLINT NOT NULL);

IF OBJECT_ID(N'stg.tripulacion', N'U') IS NULL
CREATE TABLE stg.tripulacion (id_vuelo INT NOT NULL, id_empleado INT NOT NULL, rol_vuelo VARCHAR(15) NOT NULL);

IF OBJECT_ID(N'stg.vuelo_evento', N'U') IS NULL
CREATE TABLE stg.vuelo_evento (
    id_vuelo INT NOT NULL, estado_final VARCHAR(15) NOT NULL,
    salida_estimada_utc DATETIME2(0) NULL, salida_real_utc DATETIME2(0) NULL, llegada_real_utc DATETIME2(0) NULL,
    motivo_cancelacion NVARCHAR(200) NULL);

IF OBJECT_ID(N'stg.persona', N'U') IS NULL
CREATE TABLE stg.persona (
    id_persona INT NOT NULL, nombres NVARCHAR(60) NOT NULL, apellidos NVARCHAR(60) NOT NULL,
    fecha_nacimiento DATE NULL, genero CHAR(1) NULL, email_contacto VARCHAR(120) NULL, telefono VARCHAR(20) NULL,
    codigo_pais_nacionalidad CHAR(2) NULL, tipo_documento VARCHAR(10) NULL, numero_documento VARCHAR(20) NULL,
    codigo_pais_documento CHAR(2) NULL, creado_utc DATETIME2(0) NOT NULL);

IF OBJECT_ID(N'stg.cliente', N'U') IS NULL
CREATE TABLE stg.cliente (
    id_persona INT NOT NULL, numero_viajero CHAR(10) NOT NULL, email_acceso VARCHAR(120) NOT NULL,
    fecha_registro_utc DATETIME2(0) NOT NULL, nivel_lealtad VARCHAR(10) NOT NULL, acepta_marketing BIT NOT NULL,
    id_aeropuerto_preferido INT NULL);

IF OBJECT_ID(N'stg.compra', N'U') IS NULL
CREATE TABLE stg.compra (
    id_compra INT NOT NULL, codigo_reserva CHAR(6) NOT NULL, id_persona_comprador INT NOT NULL,
    id_localizacion_venta INT NOT NULL, id_empleado_vendedor INT NULL, fecha_compra_utc DATETIME2(0) NOT NULL,
    email_confirmacion VARCHAR(120) NULL);

IF OBJECT_ID(N'stg.tiquete', N'U') IS NULL
CREATE TABLE stg.tiquete (
    id_tiquete INT NOT NULL, numero_tiquete CHAR(13) NOT NULL, id_compra INT NOT NULL, id_vuelo INT NOT NULL,
    codigo_cabina CHAR(3) NOT NULL, id_persona_pasajero INT NOT NULL, codigo_asiento VARCHAR(4) NULL,
    id_tarifa INT NOT NULL, precio_base_usd DECIMAL(10,2) NOT NULL, id_descuento SMALLINT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL, fecha_limite_pago_utc DATETIME2(0) NOT NULL, creado_utc DATETIME2(0) NOT NULL,
    estado_final VARCHAR(15) NOT NULL, fecha_emision_utc DATETIME2(0) NULL, fecha_cancelacion_utc DATETIME2(0) NULL,
    codigo_motivo_cancelacion VARCHAR(15) NULL);

IF OBJECT_ID(N'stg.pago', N'U') IS NULL
CREATE TABLE stg.pago (
    id_pago INT NOT NULL, id_tiquete INT NOT NULL, codigo_metodo VARCHAR(12) NOT NULL, id_localizacion_cobro INT NOT NULL,
    monto_usd DECIMAL(10,2) NOT NULL, estado_inicial VARCHAR(15) NOT NULL, estado_final VARCHAR(15) NOT NULL,
    fecha_creacion_utc DATETIME2(0) NOT NULL, fecha_resolucion_utc DATETIME2(0) NULL, referencia_autorizacion VARCHAR(30) NULL,
    ultimos4_tarjeta CHAR(4) NULL, marca_tarjeta VARCHAR(12) NULL, motivo_rechazo NVARCHAR(100) NULL);

IF OBJECT_ID(N'stg.reembolso', N'U') IS NULL
CREATE TABLE stg.reembolso (
    id_reembolso INT NOT NULL, id_pago INT NOT NULL, monto_usd DECIMAL(10,2) NOT NULL, fecha_reembolso_utc DATETIME2(0) NOT NULL,
    codigo_motivo VARCHAR(15) NOT NULL, porcentaje_aplicado DECIMAL(5,2) NOT NULL, regla_aplicada VARCHAR(20) NOT NULL,
    referencia VARCHAR(30) NULL);
GO

CREATE OR ALTER PROCEDURE stg.usp_vaciar_staging
AS
BEGIN
    SET NOCOUNT ON;
    TRUNCATE TABLE stg.vuelo_plan;   TRUNCATE TABLE stg.tripulacion; TRUNCATE TABLE stg.vuelo_evento;
    TRUNCATE TABLE stg.persona;      TRUNCATE TABLE stg.cliente;     TRUNCATE TABLE stg.compra;
    TRUNCATE TABLE stg.tiquete;      TRUNCATE TABLE stg.pago;        TRUNCATE TABLE stg.reembolso;
END;
GO

CREATE OR ALTER PROCEDURE stg.usp_aplicar_carga_sintetica
    @fecha_corte_utc    DATETIME2(0),
    @descripcion        NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF EXISTS (SELECT 1 FROM ven.persona) OR EXISTS (SELECT 1 FROM ven.compra) OR EXISTS (SELECT 1 FROM ops.asignacion_tripulacion)
       OR EXISTS (SELECT 1 FROM ops.vuelo WHERE id_avion IS NOT NULL OR codigo_estado <> 'PROGRAMADO')
        THROW 50190, N'La carga sintética requiere tablas transaccionales vacías. Use 98_DESTRUCTIVO_reiniciar_datos.sql o una base nueva.', 1;

    BEGIN TRANSACTION;

    /* 1. Aviones e inventario (triggers: RN-09 solapes, RN-10 avión activo). */
    UPDATE v SET id_avion = s.id_avion
    FROM ops.vuelo AS v JOIN stg.vuelo_plan AS s ON s.id_vuelo = v.id_vuelo;
    EXEC ops.usp_sincronizar_inventario;

    /* 2. Tripulación (trigger: RN-33). */
    INSERT ops.asignacion_tripulacion (id_vuelo, id_empleado, rol_vuelo)
    SELECT id_vuelo, id_empleado, rol_vuelo FROM stg.tripulacion;

    /* 3. Personas, clientes y compras (identificadores deterministas del generador). */
    SET IDENTITY_INSERT ven.persona ON;
    INSERT ven.persona (id_persona, nombres, apellidos, fecha_nacimiento, genero, email_contacto, telefono,
                        codigo_pais_nacionalidad, tipo_documento, numero_documento, codigo_pais_documento, creado_utc)
    SELECT id_persona, nombres, apellidos, fecha_nacimiento, genero, email_contacto, telefono,
           codigo_pais_nacionalidad, tipo_documento, numero_documento, codigo_pais_documento, creado_utc
    FROM stg.persona ORDER BY id_persona;
    SET IDENTITY_INSERT ven.persona OFF;

    INSERT ven.cliente (id_persona, numero_viajero, email_acceso, fecha_registro_utc, nivel_lealtad, acepta_marketing, id_aeropuerto_preferido)
    SELECT id_persona, numero_viajero, email_acceso, fecha_registro_utc, nivel_lealtad, acepta_marketing, id_aeropuerto_preferido
    FROM stg.cliente;

    SET IDENTITY_INSERT ven.compra ON;
    INSERT ven.compra (id_compra, codigo_reserva, id_persona_comprador, id_localizacion_venta, id_empleado_vendedor, fecha_compra_utc, email_confirmacion)
    SELECT id_compra, codigo_reserva, id_persona_comprador, id_localizacion_venta, id_empleado_vendedor, fecha_compra_utc, email_confirmacion
    FROM stg.compra ORDER BY id_compra;
    SET IDENTITY_INSERT ven.compra OFF;

    /* 4. Tiquetes RESERVADOS (trigger: tarifa, descuento, asiento, pasajero, capacidad). */
    SET IDENTITY_INSERT ven.tiquete ON;
    INSERT ven.tiquete (id_tiquete, numero_tiquete, id_compra, id_vuelo, codigo_cabina, id_persona_pasajero, codigo_asiento,
                        id_tarifa, precio_base_usd, id_descuento, porcentaje_descuento, codigo_estado, fecha_limite_pago_utc, creado_utc)
    SELECT id_tiquete, numero_tiquete, id_compra, id_vuelo, codigo_cabina, id_persona_pasajero, codigo_asiento,
           id_tarifa, precio_base_usd, id_descuento, porcentaje_descuento, 'RESERVADO', fecha_limite_pago_utc, creado_utc
    FROM stg.tiquete ORDER BY id_tiquete;
    SET IDENTITY_INSERT ven.tiquete OFF;

    /* 5. Pagos con su estado inicial (trigger: RN-23, RN-25). */
    SET IDENTITY_INSERT ven.pago ON;
    INSERT ven.pago (id_pago, id_tiquete, codigo_metodo, id_localizacion_cobro, monto_usd, codigo_estado, fecha_creacion_utc,
                     fecha_resolucion_utc, referencia_autorizacion, ultimos4_tarjeta, marca_tarjeta, motivo_rechazo)
    SELECT id_pago, id_tiquete, codigo_metodo, id_localizacion_cobro, monto_usd, estado_inicial, fecha_creacion_utc,
           CASE WHEN estado_inicial = 'PENDIENTE' THEN NULL ELSE fecha_resolucion_utc END,
           referencia_autorizacion, ultimos4_tarjeta, marca_tarjeta, motivo_rechazo
    FROM stg.pago ORDER BY id_pago;
    SET IDENTITY_INSERT ven.pago OFF;

    /* 6. Emisión de los tiquetes pagados (trigger: RN-24). */
    UPDATE t SET codigo_estado = 'EMITIDO', fecha_emision_utc = s.fecha_emision_utc
    FROM ven.tiquete AS t JOIN stg.tiquete AS s ON s.id_tiquete = t.id_tiquete
    WHERE s.fecha_emision_utc IS NOT NULL;

    /* 7. Demoras y cancelaciones de vuelos. */
    UPDATE v SET codigo_estado = 'DEMORADO',
                 salida_estimada = (CAST(e.salida_estimada_utc AS DATETIMEOFFSET(0))) AT TIME ZONE lo.zona_horaria
    FROM ops.vuelo AS v
    JOIN stg.vuelo_evento AS e ON e.id_vuelo = v.id_vuelo
    JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
    JOIN ops.ruta AS r ON r.id_ruta = p.id_ruta
    JOIN ref.localizacion AS lo ON lo.id_localizacion = r.id_aeropuerto_origen
    WHERE e.salida_estimada_utc IS NOT NULL;

    UPDATE v SET codigo_estado = 'CANCELADO', motivo_cancelacion = e.motivo_cancelacion
    FROM ops.vuelo AS v JOIN stg.vuelo_evento AS e ON e.id_vuelo = v.id_vuelo
    WHERE e.estado_final = 'CANCELADO';

    /* 8. Cancelaciones de tiquetes, anulación de pagos pendientes y reembolsos (triggers: RN-28). */
    UPDATE t SET codigo_estado = 'CANCELADO', fecha_cancelacion_utc = s.fecha_cancelacion_utc,
                 codigo_motivo_cancelacion = s.codigo_motivo_cancelacion
    FROM ven.tiquete AS t JOIN stg.tiquete AS s ON s.id_tiquete = t.id_tiquete
    WHERE s.estado_final = 'CANCELADO';

    UPDATE p SET codigo_estado = 'ANULADO', fecha_resolucion_utc = s.fecha_resolucion_utc
    FROM ven.pago AS p JOIN stg.pago AS s ON s.id_pago = p.id_pago
    WHERE s.estado_inicial = 'PENDIENTE' AND s.estado_final = 'ANULADO';

    SET IDENTITY_INSERT ven.reembolso ON;
    INSERT ven.reembolso (id_reembolso, id_pago, monto_usd, fecha_reembolso_utc, codigo_motivo, porcentaje_aplicado, regla_aplicada, referencia)
    SELECT id_reembolso, id_pago, monto_usd, fecha_reembolso_utc, codigo_motivo, porcentaje_aplicado, regla_aplicada, referencia
    FROM stg.reembolso ORDER BY id_reembolso;
    SET IDENTITY_INSERT ven.reembolso OFF;

    /* 9. Salidas y llegadas (trigger: RN-35 tripulación completa, RN-06 desfases). */
    UPDATE v SET codigo_estado = 'EN_VUELO',
                 salida_real = (CAST(e.salida_real_utc AS DATETIMEOFFSET(0))) AT TIME ZONE lo.zona_horaria
    FROM ops.vuelo AS v
    JOIN stg.vuelo_evento AS e ON e.id_vuelo = v.id_vuelo
    JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
    JOIN ops.ruta AS r ON r.id_ruta = p.id_ruta
    JOIN ref.localizacion AS lo ON lo.id_localizacion = r.id_aeropuerto_origen
    WHERE e.estado_final IN ('EN_VUELO', 'ATERRIZADO');

    UPDATE v SET codigo_estado = 'ATERRIZADO',
                 llegada_real = (CAST(e.llegada_real_utc AS DATETIMEOFFSET(0))) AT TIME ZONE ld.zona_horaria
    FROM ops.vuelo AS v
    JOIN stg.vuelo_evento AS e ON e.id_vuelo = v.id_vuelo
    JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
    JOIN ops.ruta AS r ON r.id_ruta = p.id_ruta
    JOIN ref.localizacion AS ld ON ld.id_localizacion = r.id_aeropuerto_destino
    WHERE e.estado_final = 'ATERRIZADO';

    /* 10. Abordaje: USADO o NO_PRESENTADO. */
    UPDATE t SET codigo_estado = s.estado_final
    FROM ven.tiquete AS t JOIN stg.tiquete AS s ON s.id_tiquete = t.id_tiquete
    WHERE s.estado_final IN ('USADO', 'NO_PRESENTADO');

    /* 11. Secuencias por encima de los números ya usados. */
    DECLARE @siguiente BIGINT, @sql NVARCHAR(200);
    SELECT @siguiente = ISNULL(MAX(CAST(RIGHT(numero_tiquete, 10) AS BIGINT)), 0) + 1 FROM ven.tiquete;
    SET @sql = CONCAT(N'ALTER SEQUENCE ven.seq_numero_tiquete RESTART WITH ', @siguiente, N';');
    EXEC sys.sp_executesql @sql;
    SELECT @siguiente = ISNULL(MAX(CAST(RIGHT(numero_viajero, 8) AS BIGINT)), 0) + 1 FROM ven.cliente;
    SET @sql = CONCAT(N'ALTER SEQUENCE ven.seq_numero_viajero RESTART WITH ', @siguiente, N';');
    EXEC sys.sp_executesql @sql;

    /* 12. Fecha de corte de los datos y registro de la carga. */
    IF EXISTS (SELECT 1 FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS')
        UPDATE ref.parametro SET valor = CONVERT(VARCHAR(19), @fecha_corte_utc, 126) WHERE clave = 'FECHA_CORTE_DATOS';
    ELSE
        INSERT ref.parametro (clave, valor, tipo_dato, descripcion)
        VALUES ('FECHA_CORTE_DATOS', CONVERT(VARCHAR(19), @fecha_corte_utc, 126), 'DATETIME',
                N'Instante (UTC) al que corresponden los datos sintéticos; las consultas lo usan como "hoy"');
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('CARGA_SINTETICA', @descripcion);

    COMMIT TRANSACTION;
END;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '10_carga_staging')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('10_carga_staging', N'Staging y procedimiento de carga sintética');
GO
SET NOEXEC OFF;
GO
