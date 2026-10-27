/* =============================================================================
   07_procedimientos.sql
   Propósito : procedimientos almacenados de las operaciones críticas.
   Patrón común:
     - SET XACT_ABORT ON: cualquier error deja la transacción no confirmable y
       se revierte por completo (no hay operaciones a medias).
     - TRY/CATCH + THROW (SQL Server 2012+ y Azure SQL Database).
     - Transacción propia solo si no hay una abierta (@@TRANCOUNT = 0): así los
       procedimientos pueden anidarse y probarse dentro de transacciones que
       luego se revierten.
     - Errores de negocio 501xx con mensaje legible; los errores del motor que
       violan reglas (2601 índice único, 547 CHECK) se traducen a mensajes de
       negocio.
     - Parámetros OUTPUT para devolver identificadores. Desde Python se leen con
       el patrón "DECLARE @x ...; EXEC ... @x = @x OUTPUT; SELECT @x".
   Concurrencia (resumen; detalle en docs/03_arquitectura/concurrencia.md):
     - Venta: la fila ops.vuelo_cabina actúa como semáforo; el trigger la
       actualiza con bloqueo de fila y la restricción CHECK impide superar la
       capacidad. El índice único filtrado impide asientos duplicados.
     - Pago y cancelación: bloqueo UPDLOCK de la fila del tiquete antes de leer
       saldos, para serializar operaciones sobre el mismo tiquete.
   Depende de: 06_vistas.sql
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

/* =============================================================== PERSONAS === */
CREATE OR ALTER PROCEDURE ven.usp_registrar_persona
    @nombres                    NVARCHAR(60),
    @apellidos                  NVARCHAR(60),
    @fecha_nacimiento           DATE          = NULL,
    @genero                     CHAR(1)       = NULL,
    @email_contacto             VARCHAR(120)  = NULL,
    @telefono                   VARCHAR(20)   = NULL,
    @codigo_pais_nacionalidad   CHAR(2)       = NULL,
    @tipo_documento             VARCHAR(10)   = NULL,
    @numero_documento           VARCHAR(20)   = NULL,
    @codigo_pais_documento      CHAR(2)       = NULL,
    @id_persona                 INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NULLIF(LTRIM(RTRIM(@nombres)), N'') IS NULL OR NULLIF(LTRIM(RTRIM(@apellidos)), N'') IS NULL
        THROW 50101, N'Nombres y apellidos son obligatorios.', 1;

    INSERT ven.persona (nombres, apellidos, fecha_nacimiento, genero, email_contacto, telefono,
                        codigo_pais_nacionalidad, tipo_documento, numero_documento, codigo_pais_documento)
    VALUES (LTRIM(RTRIM(@nombres)), LTRIM(RTRIM(@apellidos)), @fecha_nacimiento, @genero, LOWER(@email_contacto), @telefono,
            @codigo_pais_nacionalidad, @tipo_documento, @numero_documento, @codigo_pais_documento);
    SET @id_persona = CAST(SCOPE_IDENTITY() AS INT);
END;
GO

CREATE OR ALTER PROCEDURE ven.usp_registrar_cliente
    @id_persona                 INT,
    @email_acceso               VARCHAR(120),
    @acepta_marketing           BIT           = 0,
    @id_aeropuerto_preferido    INT           = NULL,
    @numero_viajero             CHAR(10)      = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM ven.persona WHERE id_persona = @id_persona)
        THROW 50102, N'La persona no existe.', 1;
    IF EXISTS (SELECT 1 FROM ven.cliente WHERE id_persona = @id_persona)
        THROW 50103, N'La persona ya tiene una cuenta de cliente.', 1;

    DECLARE @serie INT = NEXT VALUE FOR ven.seq_numero_viajero;
    SET @numero_viajero = CONCAT('VF', RIGHT(CONCAT('00000000', @serie), 8));
    BEGIN TRY
        INSERT ven.cliente (id_persona, numero_viajero, email_acceso, acepta_marketing, id_aeropuerto_preferido)
        VALUES (@id_persona, @numero_viajero, LOWER(@email_acceso), @acepta_marketing, @id_aeropuerto_preferido);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627) AND ERROR_MESSAGE() LIKE N'%uq_cliente_email_acceso%'
            THROW 50104, N'El correo de acceso ya está registrado por otro cliente.', 1;
        THROW;
    END CATCH;
END;
GO

/* ========================================================== DISPONIBILIDAD === */
/* CU-06: vuelos entre dos aeropuertos en una fecha local, con plazas y tarifa vigente. */
CREATE OR ALTER PROCEDURE ven.usp_consultar_disponibilidad
    @origen         CHAR(3),
    @destino        CHAR(3),
    @fecha_salida   DATE,
    @fecha_venta_utc DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @fecha_venta_utc = ISNULL(@fecha_venta_utc, SYSUTCDATETIME());
    SELECT o.id_vuelo, o.codigo_vuelo, o.ruta, v.salida_programada, v.llegada_programada, o.codigo_cabina,
           o.capacidad, o.plazas_disponibles, tf.id_tarifa, tf.precio_base_usd
    FROM rpt.v_ocupacion_vuelo_cabina AS o
    JOIN rpt.v_vuelo AS v ON v.id_vuelo = o.id_vuelo
    OUTER APPLY (SELECT TOP (1) t.id_tarifa, t.precio_base_usd
                 FROM ven.tarifa AS t
                 WHERE t.id_ruta = o.id_ruta AND t.codigo_cabina = o.codigo_cabina
                   AND CAST(@fecha_venta_utc AS DATE) BETWEEN t.vigente_desde AND ISNULL(t.vigente_hasta, '99991231')) AS tf
    WHERE v.origen = @origen AND v.destino = @destino AND o.fecha_salida_local = @fecha_salida
      AND o.estado_vuelo IN ('PROGRAMADO', 'DEMORADO')
    ORDER BY v.salida_programada, o.codigo_cabina;
END;
GO

/* ================================================================= VENTA ==== */
/* CU-07: emite (reserva) un tiquete con la tarifa vigente y un descuento opcional.
   El tiquete nace RESERVADO; pasa a EMITIDO cuando los pagos confirmados cubren
   el precio final (ven.usp_registrar_pago). */
CREATE OR ALTER PROCEDURE ven.usp_emitir_tiquete
    @id_vuelo               INT,
    @codigo_cabina          CHAR(3),
    @id_persona_pasajero    INT,
    @id_persona_comprador   INT,
    @id_localizacion_venta  INT,
    @id_empleado_vendedor   INT           = NULL,
    @codigo_descuento       VARCHAR(20)   = NULL,
    @codigo_asiento         VARCHAR(4)    = NULL,
    @fecha_venta_utc        DATETIME2(0)  = NULL,
    @id_compra              INT           = NULL OUTPUT,   -- entrada opcional: agrega el tiquete a una compra existente
    @id_tiquete             INT           = NULL OUTPUT,
    @numero_tiquete         CHAR(13)      = NULL OUTPUT,
    @codigo_reserva         CHAR(6)       = NULL OUTPUT,
    @precio_final_usd       DECIMAL(10,2) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @ahora DATETIME2(0) = SYSUTCDATETIME();
    SET @fecha_venta_utc = ISNULL(@fecha_venta_utc, @ahora);
    IF @fecha_venta_utc > DATEADD(MINUTE, 5, @ahora)
        THROW 50110, N'La fecha de venta no puede estar en el futuro.', 1;

    DECLARE @id_ruta SMALLINT, @salida_utc DATETIME2(0), @estado_vuelo VARCHAR(15), @fecha_vuelo DATE;
    SELECT @id_ruta = p.id_ruta,
           @salida_utc = CONVERT(DATETIME2(0), SWITCHOFFSET(v.salida_programada, '+00:00')),
           @estado_vuelo = v.codigo_estado,
           @fecha_vuelo = v.fecha_salida_local
    FROM ops.vuelo AS v JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
    WHERE v.id_vuelo = @id_vuelo;

    IF @id_ruta IS NULL
        THROW 50111, N'El vuelo no existe.', 1;
    IF @estado_vuelo NOT IN ('PROGRAMADO', 'DEMORADO') OR @fecha_venta_utc >= @salida_utc
        THROW 50112, N'El vuelo no está abierto a la venta.', 1;
    IF NOT EXISTS (SELECT 1 FROM ops.vuelo_cabina WHERE id_vuelo = @id_vuelo AND codigo_cabina = @codigo_cabina)
        THROW 50113, N'La cabina no existe en este vuelo o el vuelo aún no tiene avión asignado.', 1;

    -- Tarifa vigente en la fecha de venta (SUP-04).
    DECLARE @id_tarifa INT, @precio_base DECIMAL(10,2);
    SELECT @id_tarifa = id_tarifa, @precio_base = precio_base_usd
    FROM ven.tarifa
    WHERE id_ruta = @id_ruta AND codigo_cabina = @codigo_cabina
      AND CAST(@fecha_venta_utc AS DATE) BETWEEN vigente_desde AND ISNULL(vigente_hasta, '99991231');
    IF @id_tarifa IS NULL
        THROW 50114, N'No hay tarifa vigente para la ruta y la cabina en la fecha de venta.', 1;

    -- Descuento opcional (SUP-05: uno como máximo).
    DECLARE @id_descuento SMALLINT = NULL, @porcentaje DECIMAL(5,2) = 0;
    IF @codigo_descuento IS NOT NULL
    BEGIN
        SELECT @id_descuento = d.id_descuento, @porcentaje = d.porcentaje
        FROM ven.descuento AS d
        WHERE d.codigo_descuento = @codigo_descuento AND d.activo = 1
          AND CAST(@fecha_venta_utc AS DATE) BETWEEN d.vigente_desde AND d.vigente_hasta
          AND (d.codigo_cabina IS NULL OR d.codigo_cabina = @codigo_cabina)
          AND (d.dias_anticipacion_min IS NULL
               OR DATEDIFF(DAY, CAST(@fecha_venta_utc AS DATE), @fecha_vuelo) >= d.dias_anticipacion_min)
          AND (d.solo_clientes_registrados = 0
               OR EXISTS (SELECT 1 FROM ven.cliente AS c
                          WHERE c.id_persona = @id_persona_comprador AND c.fecha_registro_utc <= @fecha_venta_utc
                            AND c.estado_cuenta = 'ACTIVA'));
        IF @id_descuento IS NULL
            THROW 50115, N'El código de descuento no existe o no es aplicable a esta venta.', 1;
    END;

    -- Plazo de pago (SUP-07): mínimo entre la venta + HORAS_LIMITE_PAGO y el cierre de ventas antes de la salida.
    DECLARE @horas_limite INT = ISNULL((SELECT CAST(valor AS INT) FROM ref.parametro WHERE clave = 'HORAS_LIMITE_PAGO'), 72);
    DECLARE @horas_cierre INT = ISNULL((SELECT CAST(valor AS INT) FROM ref.parametro WHERE clave = 'HORAS_CIERRE_VENTA'), 3);
    DECLARE @limite_pago DATETIME2(0) = DATEADD(HOUR, @horas_limite, @fecha_venta_utc);
    IF @limite_pago > DATEADD(HOUR, -@horas_cierre, @salida_utc)
        SET @limite_pago = DATEADD(HOUR, -@horas_cierre, @salida_utc);
    IF @limite_pago <= @fecha_venta_utc
        THROW 50119, N'Las ventas de este vuelo ya cerraron (cierre antes de la salida).', 1;

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        IF @id_compra IS NULL
        BEGIN
            -- Localizador aleatorio de 6 caracteres sin 0/O ni 1/I (32^6 combinaciones).
            DECLARE @alfabeto CHAR(32) = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', @bytes BINARY(6), @intentos INT = 0;
            WHILE 1 = 1
            BEGIN
                SET @bytes = CRYPT_GEN_RANDOM(6);
                SET @codigo_reserva = CONCAT(
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 1, 1) AS INT) % 32 + 1, 1),
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 2, 1) AS INT) % 32 + 1, 1),
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 3, 1) AS INT) % 32 + 1, 1),
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 4, 1) AS INT) % 32 + 1, 1),
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 5, 1) AS INT) % 32 + 1, 1),
                    SUBSTRING(@alfabeto, CAST(SUBSTRING(@bytes, 6, 1) AS INT) % 32 + 1, 1));
                IF NOT EXISTS (SELECT 1 FROM ven.compra WITH (UPDLOCK, HOLDLOCK) WHERE codigo_reserva = @codigo_reserva) BREAK;
                SET @intentos += 1;
                IF @intentos >= 10 THROW 50116, N'No se pudo generar un localizador único.', 1;
            END;

            INSERT ven.compra (codigo_reserva, id_persona_comprador, id_localizacion_venta, id_empleado_vendedor,
                               fecha_compra_utc, email_confirmacion)
            SELECT @codigo_reserva, p.id_persona, @id_localizacion_venta, @id_empleado_vendedor, @fecha_venta_utc, p.email_contacto
            FROM ven.persona AS p WHERE p.id_persona = @id_persona_comprador;
            IF @@ROWCOUNT = 0 THROW 50117, N'El comprador no existe.', 1;
            SET @id_compra = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            SET @codigo_reserva = NULL;
            SELECT @codigo_reserva = codigo_reserva
            FROM ven.compra WITH (UPDLOCK)
            WHERE id_compra = @id_compra AND id_persona_comprador = @id_persona_comprador
              AND fecha_compra_utc <= @fecha_venta_utc;
            IF @codigo_reserva IS NULL
                THROW 50118, N'La compra no existe, pertenece a otro comprador o es posterior a la venta.', 1;
        END;

        DECLARE @serie BIGINT = NEXT VALUE FOR ven.seq_numero_tiquete;
        SET @numero_tiquete = CONCAT('000', RIGHT(CONCAT('0000000000', @serie), 10));

        -- El trigger ven.trg_tiquete_reglas valida tarifa, descuento, asiento y descuenta inventario con bloqueo.
        INSERT ven.tiquete (numero_tiquete, id_compra, id_vuelo, codigo_cabina, id_persona_pasajero, codigo_asiento,
                            id_tarifa, precio_base_usd, id_descuento, porcentaje_descuento, codigo_estado,
                            fecha_limite_pago_utc, creado_utc)
        VALUES (@numero_tiquete, @id_compra, @id_vuelo, @codigo_cabina, @id_persona_pasajero, @codigo_asiento,
                @id_tarifa, @precio_base, @id_descuento, @porcentaje, 'RESERVADO',
                @limite_pago, @fecha_venta_utc);
        SET @id_tiquete = CAST(SCOPE_IDENTITY() AS INT);
        SELECT @precio_final_usd = precio_final_usd FROM ven.tiquete WHERE id_tiquete = @id_tiquete;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @numero INT = ERROR_NUMBER(), @mensaje NVARCHAR(2048) = ERROR_MESSAGE();
        IF @numero IN (2601, 2627) AND @mensaje LIKE N'%ux_tiquete_vuelo_asiento%'
            THROW 50120, N'RN-12: el asiento ya está ocupado en este vuelo.', 1;
        IF @numero IN (2601, 2627) AND @mensaje LIKE N'%ux_tiquete_vuelo_pasajero%'
            THROW 50121, N'RN-14: el pasajero ya tiene un tiquete activo en este vuelo.', 1;
        IF @numero = 547 AND @mensaje LIKE N'%ck_vuelo_cabina_capacidad%'
            THROW 50020, N'RN-11: sin disponibilidad en la cabina solicitada.', 1;
        THROW;
    END CATCH;
END;
GO

/* CU-08: asigna un asiento elegido o el primero libre de la cabina. */
CREATE OR ALTER PROCEDURE ven.usp_asignar_asiento
    @id_tiquete         INT,
    @codigo_asiento     VARCHAR(4) = NULL,
    @asiento_asignado   VARCHAR(4) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @intento INT = 0, @id_vuelo INT, @cabina CHAR(3), @estado VARCHAR(15);

    WHILE 1 = 1
    BEGIN
        BEGIN TRY
            IF @tran_propia = 1 BEGIN TRANSACTION;
            SELECT @id_vuelo = id_vuelo, @cabina = codigo_cabina, @estado = codigo_estado
            FROM ven.tiquete WITH (UPDLOCK, ROWLOCK) WHERE id_tiquete = @id_tiquete;
            IF @id_vuelo IS NULL THROW 50122, N'El tiquete no existe.', 1;
            IF @estado NOT IN ('RESERVADO', 'EMITIDO') THROW 50123, N'Solo se asignan asientos a tiquetes reservados o emitidos.', 1;

            SET @asiento_asignado = @codigo_asiento;
            IF @asiento_asignado IS NULL
            BEGIN
                -- Selección automática: se bloquea la fila de inventario del vuelo y cabina (el mismo semáforo
                -- que usa la venta) para que dos sesiones no elijan a la vez el mismo "primer asiento libre".
                -- Sin este bloqueo, con alta concurrencia todas eligen el mismo asiento y solo una gana por ronda.
                DECLARE @semaforo SMALLINT;
                SELECT @semaforo = capacidad FROM ops.vuelo_cabina WITH (UPDLOCK, ROWLOCK)
                WHERE id_vuelo = @id_vuelo AND codigo_cabina = @cabina;
                SELECT TOP (1) @asiento_asignado = s.codigo_asiento
                FROM ops.vuelo AS v
                JOIN ops.avion AS a ON a.id_avion = v.id_avion
                JOIN ops.asiento_configuracion AS s ON s.id_configuracion = a.id_configuracion AND s.codigo_cabina = @cabina
                WHERE v.id_vuelo = @id_vuelo
                  AND NOT EXISTS (SELECT 1 FROM ven.tiquete AS t
                                  WHERE t.id_vuelo = @id_vuelo AND t.codigo_asiento = s.codigo_asiento
                                    AND t.codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO'))
                ORDER BY s.fila, s.letra;
            END;
            IF @asiento_asignado IS NULL THROW 50124, N'No quedan asientos libres en la cabina.', 1;

            UPDATE ven.tiquete SET codigo_asiento = @asiento_asignado WHERE id_tiquete = @id_tiquete;
            IF @tran_propia = 1 COMMIT TRANSACTION;
            BREAK;
        END TRY
        BEGIN CATCH
            IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            -- Red de seguridad: si aun así hubiera conflicto (p. ej., una venta con asiento explícito), se reintenta.
            IF ERROR_NUMBER() IN (2601, 2627) AND @codigo_asiento IS NULL AND @tran_propia = 1 AND @intento < 5
            BEGIN
                SET @intento += 1;
                CONTINUE;
            END;
            IF ERROR_NUMBER() IN (2601, 2627)
                THROW 50120, N'RN-12: el asiento ya está ocupado en este vuelo.', 1;
            THROW;
        END CATCH;
    END;
END;
GO

/* ================================================================= PAGOS ==== */
/* CU-09: registra un pago total o parcial con el resultado de la pasarela.
   Si los pagos confirmados cubren el precio final, el tiquete pasa a EMITIDO. */
CREATE OR ALTER PROCEDURE ven.usp_registrar_pago
    @id_tiquete                 INT,
    @codigo_metodo              VARCHAR(12),
    @monto_usd                  DECIMAL(10,2),
    @id_localizacion_cobro      INT,
    @resultado                  VARCHAR(15)   = 'CONFIRMADO',   -- CONFIRMADO, FALLIDO o PENDIENTE
    @referencia_autorizacion    VARCHAR(30)   = NULL,
    @ultimos4_tarjeta           CHAR(4)       = NULL,
    @marca_tarjeta              VARCHAR(12)   = NULL,
    @motivo_rechazo             NVARCHAR(100) = NULL,
    @fecha_pago_utc             DATETIME2(0)  = NULL,
    @id_pago                    INT           = NULL OUTPUT,
    @saldo_pendiente_usd        DECIMAL(10,2) = NULL OUTPUT,
    @estado_tiquete             VARCHAR(15)   = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @fecha_pago_utc = ISNULL(@fecha_pago_utc, SYSUTCDATETIME());
    IF @resultado NOT IN ('CONFIRMADO', 'FALLIDO', 'PENDIENTE')
        THROW 50130, N'El resultado del pago debe ser CONFIRMADO, FALLIDO o PENDIENTE.', 1;
    IF @monto_usd IS NULL OR @monto_usd <= 0
        THROW 50131, N'El monto del pago debe ser mayor que cero.', 1;
    IF @resultado = 'CONFIRMADO' AND @referencia_autorizacion IS NULL
        SET @referencia_autorizacion = CONCAT('AUT', RIGHT(CONVERT(VARCHAR(20), CRYPT_GEN_RANDOM(5), 2), 10));
    IF @resultado = 'FALLIDO' AND @motivo_rechazo IS NULL
        SET @motivo_rechazo = N'Rechazado por la entidad emisora';

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @estado VARCHAR(15), @precio DECIMAL(10,2), @limite DATETIME2(0), @cobrado DECIMAL(12,2), @pendiente DECIMAL(12,2);
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        -- Bloqueo de la fila del tiquete: serializa pagos concurrentes del mismo tiquete.
        SELECT @estado = codigo_estado, @precio = precio_final_usd, @limite = fecha_limite_pago_utc
        FROM ven.tiquete WITH (UPDLOCK, ROWLOCK)
        WHERE id_tiquete = @id_tiquete;

        IF @estado IS NULL THROW 50132, N'El tiquete no existe.', 1;
        IF @estado <> 'RESERVADO' THROW 50133, N'El tiquete no tiene saldo pendiente (no está en estado RESERVADO).', 1;
        IF @fecha_pago_utc > @limite THROW 50134, N'La reserva venció; el pago no se acepta.', 1;

        SELECT @cobrado   = ISNULL(SUM(CASE WHEN codigo_estado = 'CONFIRMADO' THEN monto_usd ELSE 0 END), 0),
               @pendiente = ISNULL(SUM(CASE WHEN codigo_estado = 'PENDIENTE'  THEN monto_usd ELSE 0 END), 0)
        FROM ven.pago WHERE id_tiquete = @id_tiquete;

        IF @resultado <> 'FALLIDO' AND @monto_usd > @precio - @cobrado - @pendiente
        BEGIN
            DECLARE @msg NVARCHAR(400) = CONCAT(N'RN-37: el monto (', @monto_usd, N' USD) supera el saldo disponible para pagar (',
                                                @precio - @cobrado - @pendiente, N' USD).');
            THROW 50135, @msg, 1;
        END;

        INSERT ven.pago (id_tiquete, codigo_metodo, id_localizacion_cobro, monto_usd, codigo_estado, fecha_creacion_utc,
                         fecha_resolucion_utc, referencia_autorizacion, ultimos4_tarjeta, marca_tarjeta, motivo_rechazo)
        VALUES (@id_tiquete, @codigo_metodo, @id_localizacion_cobro, @monto_usd, @resultado, @fecha_pago_utc,
                CASE WHEN @resultado = 'PENDIENTE' THEN NULL ELSE @fecha_pago_utc END,
                CASE WHEN @resultado = 'FALLIDO' THEN NULL ELSE @referencia_autorizacion END,
                @ultimos4_tarjeta, @marca_tarjeta,
                CASE WHEN @resultado = 'FALLIDO' THEN @motivo_rechazo END);
        SET @id_pago = CAST(SCOPE_IDENTITY() AS INT);

        IF @resultado = 'CONFIRMADO' AND @cobrado + @monto_usd = @precio
            UPDATE ven.tiquete SET codigo_estado = 'EMITIDO', fecha_emision_utc = @fecha_pago_utc WHERE id_tiquete = @id_tiquete;

        SELECT @saldo_pendiente_usd = saldo_pendiente_usd, @estado_tiquete = codigo_estado
        FROM rpt.v_tiquete_financiero WHERE id_tiquete = @id_tiquete;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Resuelve un pago PENDIENTE (respuesta asíncrona de la pasarela). */
CREATE OR ALTER PROCEDURE ven.usp_resolver_pago
    @id_pago                    INT,
    @resultado                  VARCHAR(15),        -- CONFIRMADO, FALLIDO o ANULADO
    @referencia_autorizacion    VARCHAR(30)   = NULL,
    @motivo_rechazo             NVARCHAR(100) = NULL,
    @fecha_resolucion_utc       DATETIME2(0)  = NULL,
    @estado_tiquete             VARCHAR(15)   = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @fecha_resolucion_utc = ISNULL(@fecha_resolucion_utc, SYSUTCDATETIME());
    IF @resultado NOT IN ('CONFIRMADO', 'FALLIDO', 'ANULADO')
        THROW 50136, N'El resultado debe ser CONFIRMADO, FALLIDO o ANULADO.', 1;

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @id_tiquete INT, @precio DECIMAL(10,2), @cobrado DECIMAL(12,2);
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;
        SELECT @id_tiquete = id_tiquete FROM ven.pago WHERE id_pago = @id_pago;
        IF @id_tiquete IS NULL THROW 50137, N'El pago no existe.', 1;
        SELECT @precio = precio_final_usd FROM ven.tiquete WITH (UPDLOCK, ROWLOCK) WHERE id_tiquete = @id_tiquete;

        UPDATE ven.pago
           SET codigo_estado = @resultado,
               fecha_resolucion_utc = @fecha_resolucion_utc,
               referencia_autorizacion = CASE WHEN @resultado = 'CONFIRMADO'
                                              THEN ISNULL(@referencia_autorizacion, CONCAT('AUT', RIGHT(CONVERT(VARCHAR(20), CRYPT_GEN_RANDOM(5), 2), 10)))
                                              ELSE referencia_autorizacion END,
               motivo_rechazo = CASE WHEN @resultado = 'FALLIDO' THEN ISNULL(@motivo_rechazo, N'Rechazado por la entidad emisora') END
         WHERE id_pago = @id_pago;   -- el trigger valida la transición PENDIENTE -> resultado

        SELECT @cobrado = ISNULL(SUM(monto_usd), 0) FROM ven.pago WHERE id_tiquete = @id_tiquete AND codigo_estado = 'CONFIRMADO';
        IF @resultado = 'CONFIRMADO' AND @cobrado = @precio
            UPDATE ven.tiquete SET codigo_estado = 'EMITIDO', fecha_emision_utc = @fecha_resolucion_utc
             WHERE id_tiquete = @id_tiquete AND codigo_estado = 'RESERVADO';
        SELECT @estado_tiquete = codigo_estado FROM ven.tiquete WHERE id_tiquete = @id_tiquete;
        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ========================================================== CANCELACIÓN ==== */
/* CU-10: cancela un tiquete, libera la plaza y reembolsa según la política.
   El reembolso se distribuye sobre los pagos confirmados, del más reciente al
   más antiguo; lo no reembolsado es la penalidad retenida. */
CREATE OR ALTER PROCEDURE ven.usp_cancelar_tiquete
    @id_tiquete             INT,
    @codigo_motivo          VARCHAR(15)   = 'VOLUNTARIA',
    @fecha_cancelacion_utc  DATETIME2(0)  = NULL,
    @monto_reembolsado_usd  DECIMAL(10,2) = NULL OUTPUT,
    @monto_retenido_usd     DECIMAL(10,2) = NULL OUTPUT,
    @regla_aplicada         VARCHAR(20)   = NULL OUTPUT,
    @porcentaje_reembolso   DECIMAL(5,2)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @fecha_cancelacion_utc = ISNULL(@fecha_cancelacion_utc, SYSUTCDATETIME());
    IF NOT EXISTS (SELECT 1 FROM ref.motivo_cancelacion WHERE codigo_motivo = @codigo_motivo)
        THROW 50140, N'El motivo de cancelación no existe.', 1;

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @estado VARCHAR(15), @cobrado DECIMAL(12,2);
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        SELECT @estado = codigo_estado FROM ven.tiquete WITH (UPDLOCK, ROWLOCK) WHERE id_tiquete = @id_tiquete;
        IF @estado IS NULL THROW 50141, N'El tiquete no existe.', 1;
        IF @estado NOT IN ('RESERVADO', 'EMITIDO')
            THROW 50142, N'Solo se cancelan tiquetes en estado RESERVADO o EMITIDO.', 1;

        SELECT @porcentaje_reembolso = porcentaje_reembolso, @regla_aplicada = regla_aplicada
        FROM ven.fn_politica_reembolso(@id_tiquete, @codigo_motivo, @fecha_cancelacion_utc);
        IF @porcentaje_reembolso IS NULL
            THROW 50143, N'No hay política de reembolso aplicable: el vuelo ya salió o la fecha de cancelación es posterior a la salida.', 1;

        SELECT @cobrado = ISNULL(SUM(monto_usd), 0) FROM ven.pago WHERE id_tiquete = @id_tiquete AND codigo_estado = 'CONFIRMADO';
        SET @monto_reembolsado_usd = CAST(ROUND(@cobrado * @porcentaje_reembolso / 100.0, 2) AS DECIMAL(10,2));
        SET @monto_retenido_usd = @cobrado - @monto_reembolsado_usd;

        -- El trigger libera la plaza (inventario) y el asiento deja de contar en el índice único filtrado.
        UPDATE ven.tiquete
           SET codigo_estado = 'CANCELADO', fecha_cancelacion_utc = @fecha_cancelacion_utc, codigo_motivo_cancelacion = @codigo_motivo
         WHERE id_tiquete = @id_tiquete;

        -- Los pagos pendientes se anulan: ya no pueden confirmarse.
        UPDATE ven.pago SET codigo_estado = 'ANULADO', fecha_resolucion_utc = @fecha_cancelacion_utc
         WHERE id_tiquete = @id_tiquete AND codigo_estado = 'PENDIENTE';

        IF @monto_reembolsado_usd > 0
        BEGIN
            WITH pagos AS (
                SELECT id_pago, monto_usd,
                       SUM(monto_usd) OVER (ORDER BY fecha_resolucion_utc DESC, id_pago DESC ROWS UNBOUNDED PRECEDING) AS acumulado
                FROM ven.pago
                WHERE id_tiquete = @id_tiquete AND codigo_estado = 'CONFIRMADO'
            )
            INSERT ven.reembolso (id_pago, monto_usd, fecha_reembolso_utc, codigo_motivo, porcentaje_aplicado, regla_aplicada, referencia)
            SELECT id_pago,
                   CASE WHEN acumulado <= @monto_reembolsado_usd THEN monto_usd
                        ELSE @monto_reembolsado_usd - (acumulado - monto_usd) END,
                   @fecha_cancelacion_utc, @codigo_motivo, @porcentaje_reembolso, @regla_aplicada, CONCAT('RB', id_pago)
            FROM pagos
            WHERE acumulado - monto_usd < @monto_reembolsado_usd;
        END;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* CU-11: cancela por vencimiento las reservas cuyo plazo de pago expiró. */
CREATE OR ALTER PROCEDURE ven.usp_vencer_reservas
    @fecha_corte_utc    DATETIME2(0) = NULL,
    @tiquetes_vencidos  INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @fecha_corte_utc = ISNULL(@fecha_corte_utc, SYSUTCDATETIME());
    SET @tiquetes_vencidos = 0;
    DECLARE @id INT, @limite DATETIME2(0);
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT id_tiquete, fecha_limite_pago_utc FROM ven.tiquete
        WHERE codigo_estado = 'RESERVADO' AND fecha_limite_pago_utc < @fecha_corte_utc
        ORDER BY fecha_limite_pago_utc, id_tiquete;
    OPEN cur;
    FETCH NEXT FROM cur INTO @id, @limite;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC ven.usp_cancelar_tiquete @id_tiquete = @id, @codigo_motivo = 'VENCIMIENTO', @fecha_cancelacion_utc = @limite;
        SET @tiquetes_vencidos += 1;
        FETCH NEXT FROM cur INTO @id, @limite;
    END;
    CLOSE cur;
    DEALLOCATE cur;
END;
GO

/* Registra el resultado del abordaje después de la salida (USADO o NO_PRESENTADO). */
CREATE OR ALTER PROCEDURE ven.usp_registrar_abordaje
    @id_tiquete INT,
    @presentado BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    UPDATE ven.tiquete
       SET codigo_estado = CASE WHEN @presentado = 1 THEN 'USADO' ELSE 'NO_PRESENTADO' END
     WHERE id_tiquete = @id_tiquete;   -- el trigger exige EMITIDO y vuelo EN_VUELO o ATERRIZADO
    IF @@ROWCOUNT = 0 THROW 50144, N'El tiquete no existe.', 1;
END;
GO

/* ============================================================ OPERACIONES === */
/* CU-03: genera los vuelos de una fecha a otra a partir de la programación vigente.
   Idempotente: no duplica vuelos existentes (la restricción única lo garantiza). */
CREATE OR ALTER PROCEDURE ops.usp_generar_vuelos
    @fecha_desde    DATE,
    @fecha_hasta    DATE,
    @vuelos_creados INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @fecha_desde IS NULL OR @fecha_hasta IS NULL OR @fecha_hasta < @fecha_desde
        THROW 50150, N'Rango de fechas no válido.', 1;
    IF DATEDIFF(DAY, @fecha_desde, @fecha_hasta) > 400
        THROW 50151, N'El rango máximo es de 400 días por ejecución.', 1;

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;

        WITH candidatos AS (
            SELECT p.id_programacion, p.numero_vuelo, p.duracion_programada_min, c.fecha,
                   lo.zona_horaria AS zona_origen, ld.zona_horaria AS zona_destino,
                   DATETIME2FROMPARTS(YEAR(c.fecha), MONTH(c.fecha), DAY(c.fecha),
                                      DATEPART(HOUR, p.hora_salida_local), DATEPART(MINUTE, p.hora_salida_local), 0, 0, 0) AS salida_local
            FROM ops.programacion AS p
            JOIN ops.ruta         AS r  ON r.id_ruta = p.id_ruta AND r.activa = 1
            JOIN ref.localizacion AS lo ON lo.id_localizacion = r.id_aeropuerto_origen
            JOIN ref.localizacion AS ld ON ld.id_localizacion = r.id_aeropuerto_destino
            CROSS APPLY ref.fn_calendario(
                CASE WHEN p.vigente_desde > @fecha_desde THEN p.vigente_desde ELSE @fecha_desde END,
                CASE WHEN ISNULL(p.vigente_hasta, '99991231') < @fecha_hasta THEN p.vigente_hasta ELSE @fecha_hasta END) AS c
            JOIN ops.programacion_dia AS pd ON pd.id_programacion = p.id_programacion AND pd.dia_semana = c.dia_semana_iso
            WHERE p.activa = 1
        ),
        horarios AS (
            -- AT TIME ZONE convierte la hora local en datetimeoffset con el desfase correcto (incluido el horario de verano).
            SELECT id_programacion, numero_vuelo, fecha, zona_destino, duracion_programada_min,
                   salida_local AT TIME ZONE zona_origen AS salida
            FROM candidatos
        )
        INSERT ops.vuelo (id_programacion, salida_programada, llegada_programada)
        SELECT h.id_programacion, h.salida, DATEADD(MINUTE, h.duracion_programada_min, h.salida) AT TIME ZONE h.zona_destino
        FROM horarios AS h
        WHERE NOT EXISTS (SELECT 1 FROM ops.vuelo AS v
                          WHERE v.id_programacion = h.id_programacion AND v.fecha_salida_local = h.fecha)
        ORDER BY h.fecha, h.salida, h.numero_vuelo;   -- orden determinista de los identificadores
        SET @vuelos_creados = @@ROWCOUNT;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Crea o ajusta el inventario por cabina según la configuración del avión asignado. */
CREATE OR ALTER PROCEDURE ops.usp_sincronizar_inventario
    @id_vuelo INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @capacidad TABLE (id_vuelo INT NOT NULL, codigo_cabina CHAR(3) NOT NULL, capacidad SMALLINT NOT NULL,
                              PRIMARY KEY (id_vuelo, codigo_cabina));
    INSERT @capacidad (id_vuelo, codigo_cabina, capacidad)
    SELECT v.id_vuelo, s.codigo_cabina, COUNT(*)
    FROM ops.vuelo AS v
    JOIN ops.avion AS a ON a.id_avion = v.id_avion
    JOIN ops.asiento_configuracion AS s ON s.id_configuracion = a.id_configuracion
    WHERE @id_vuelo IS NULL OR v.id_vuelo = @id_vuelo
    GROUP BY v.id_vuelo, s.codigo_cabina;

    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;
        UPDATE vc SET capacidad = c.capacidad
        FROM ops.vuelo_cabina AS vc
        JOIN @capacidad AS c ON c.id_vuelo = vc.id_vuelo AND c.codigo_cabina = vc.codigo_cabina
        WHERE vc.capacidad <> c.capacidad;              -- la CHECK impide bajar por debajo de las plazas ocupadas

        INSERT ops.vuelo_cabina (id_vuelo, codigo_cabina, capacidad)
        SELECT c.id_vuelo, c.codigo_cabina, c.capacidad
        FROM @capacidad AS c
        WHERE NOT EXISTS (SELECT 1 FROM ops.vuelo_cabina AS vc WHERE vc.id_vuelo = c.id_vuelo AND vc.codigo_cabina = c.codigo_cabina);
        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%ck_vuelo_cabina_capacidad%'
            THROW 50163, N'La nueva capacidad sería menor que las plazas ya vendidas.', 1;
        THROW;
    END CATCH;
END;
GO

/* CU-04: asigna un avión a un vuelo y ajusta el inventario. */
CREATE OR ALTER PROCEDURE ops.usp_asignar_avion
    @id_vuelo   INT,
    @id_avion   SMALLINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @estado_avion VARCHAR(15), @estado_vuelo VARCHAR(15);
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;
        -- Serializa las asignaciones del mismo avión antes de que el trigger compruebe solapes.
        SELECT @estado_avion = estado_operativo FROM ops.avion WITH (UPDLOCK, HOLDLOCK) WHERE id_avion = @id_avion;
        IF @estado_avion IS NULL THROW 50160, N'El avión no existe.', 1;
        SELECT @estado_vuelo = codigo_estado FROM ops.vuelo WITH (UPDLOCK) WHERE id_vuelo = @id_vuelo;
        IF @estado_vuelo IS NULL THROW 50161, N'El vuelo no existe.', 1;
        IF @estado_vuelo NOT IN ('PROGRAMADO', 'DEMORADO') THROW 50162, N'Solo se asignan aviones a vuelos programados o demorados.', 1;

        UPDATE ops.vuelo SET id_avion = @id_avion WHERE id_vuelo = @id_vuelo;   -- trigger: RN-09, RN-10, SUP-03
        EXEC ops.usp_sincronizar_inventario @id_vuelo = @id_vuelo;
        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* CU-12: cambia el estado del vuelo y registra las horas. Si se cancela,
   cancela sus tiquetes activos con reembolso total. */
CREATE OR ALTER PROCEDURE ops.usp_cambiar_estado_vuelo
    @id_vuelo               INT,
    @nuevo_estado           VARCHAR(15),
    @momento                DATETIMEOFFSET(0) = NULL,   -- hora del evento (salida o llegada); por defecto, ahora
    @salida_estimada        DATETIMEOFFSET(0) = NULL,   -- obligatoria para DEMORADO
    @motivo_cancelacion     NVARCHAR(200)     = NULL,   -- obligatorio para CANCELADO
    @tiquetes_cancelados    INT               = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @momento = ISNULL(@momento, SYSDATETIMEOFFSET());
    SET @tiquetes_cancelados = 0;
    DECLARE @tran_propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @estado VARCHAR(15), @zona_origen VARCHAR(50), @zona_destino VARCHAR(50);
    BEGIN TRY
        IF @tran_propia = 1 BEGIN TRANSACTION;
        SELECT @estado = v.codigo_estado, @zona_origen = lo.zona_horaria, @zona_destino = ld.zona_horaria
        FROM ops.vuelo AS v WITH (UPDLOCK, ROWLOCK)
        JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
        JOIN ops.ruta AS r ON r.id_ruta = p.id_ruta
        JOIN ref.localizacion AS lo ON lo.id_localizacion = r.id_aeropuerto_origen
        JOIN ref.localizacion AS ld ON ld.id_localizacion = r.id_aeropuerto_destino
        WHERE v.id_vuelo = @id_vuelo;
        IF @estado IS NULL THROW 50170, N'El vuelo no existe.', 1;

        IF @nuevo_estado = 'DEMORADO'
        BEGIN
            IF @salida_estimada IS NULL THROW 50171, N'Una demora requiere la nueva hora estimada de salida.', 1;
            UPDATE ops.vuelo SET codigo_estado = 'DEMORADO', salida_estimada = @salida_estimada AT TIME ZONE @zona_origen
             WHERE id_vuelo = @id_vuelo;
        END
        ELSE IF @nuevo_estado = 'EN_VUELO'
            UPDATE ops.vuelo SET codigo_estado = 'EN_VUELO', salida_real = @momento AT TIME ZONE @zona_origen
             WHERE id_vuelo = @id_vuelo;
        ELSE IF @nuevo_estado = 'ATERRIZADO'
            UPDATE ops.vuelo SET codigo_estado = 'ATERRIZADO', llegada_real = @momento AT TIME ZONE @zona_destino
             WHERE id_vuelo = @id_vuelo;
        ELSE IF @nuevo_estado = 'CANCELADO'
        BEGIN
            IF @motivo_cancelacion IS NULL THROW 50172, N'La cancelación de un vuelo requiere un motivo.', 1;
            UPDATE ops.vuelo SET codigo_estado = 'CANCELADO', motivo_cancelacion = @motivo_cancelacion
             WHERE id_vuelo = @id_vuelo;

            DECLARE @id INT, @fecha DATETIME2(0) = CONVERT(DATETIME2(0), SWITCHOFFSET(@momento, '+00:00'));
            DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT id_tiquete FROM ven.tiquete WHERE id_vuelo = @id_vuelo AND codigo_estado IN ('RESERVADO', 'EMITIDO');
            OPEN cur;
            FETCH NEXT FROM cur INTO @id;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC ven.usp_cancelar_tiquete @id_tiquete = @id, @codigo_motivo = 'VUELO_CANCELADO', @fecha_cancelacion_utc = @fecha;
                SET @tiquetes_cancelados += 1;
                FETCH NEXT FROM cur INTO @id;
            END;
            CLOSE cur;
            DEALLOCATE cur;
        END
        ELSE
            THROW 50173, N'Estado de destino no válido (use DEMORADO, EN_VUELO, ATERRIZADO o CANCELADO).', 1;

        IF @tran_propia = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tran_propia = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================== REPORTES === */
/* Ocupación de vuelos operados (ATERRIZADO) por ruta y cabina en un rango de fechas locales.
   Factor ponderado = SUM(volados) / SUM(capacidad), no el promedio de porcentajes. */
CREATE OR ALTER PROCEDURE rpt.usp_ocupacion_por_ruta
    @fecha_desde    DATE,
    @fecha_hasta    DATE,
    @codigo_cabina  CHAR(3) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.ruta, o.codigo_cabina,
           COUNT(*)                                                   AS vuelos,
           SUM(o.capacidad)                                           AS asientos_ofrecidos,
           SUM(o.usados)                                              AS pasajeros_volados,
           CAST(SUM(o.usados) * 1.0 / NULLIF(SUM(o.capacidad), 0) AS DECIMAL(7,4)) AS factor_ocupacion
    FROM rpt.v_ocupacion_vuelo_cabina AS o
    WHERE o.estado_vuelo = 'ATERRIZADO'
      AND o.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
      AND (@codigo_cabina IS NULL OR o.codigo_cabina = @codigo_cabina)
    GROUP BY o.ruta, o.codigo_cabina
    ORDER BY o.ruta, o.codigo_cabina;
END;
GO

/* Ventas, cobros y reembolsos por mes, cada uno por la fecha de su propio evento. */
CREATE OR ALTER PROCEDURE rpt.usp_resumen_financiero
    @fecha_desde DATE,
    @fecha_hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    WITH ventas AS (
        SELECT DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1) AS mes, COUNT(*) AS tiquetes, SUM(precio_final_usd) AS ventas_usd
        FROM ven.tiquete
        WHERE CAST(creado_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
        GROUP BY DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1)
    ), cobros AS (
        SELECT DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1) AS mes, SUM(monto_usd) AS cobros_usd
        FROM ven.pago
        WHERE codigo_estado = 'CONFIRMADO' AND CAST(fecha_resolucion_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
        GROUP BY DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1)
    ), reembolsos AS (
        SELECT DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1) AS mes, SUM(monto_usd) AS reembolsos_usd
        FROM ven.reembolso
        WHERE CAST(fecha_reembolso_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
        GROUP BY DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1)
    ), meses AS (
        SELECT mes FROM ventas UNION SELECT mes FROM cobros UNION SELECT mes FROM reembolsos
    )
    SELECT m.mes,
           ISNULL(v.tiquetes, 0)                                  AS tiquetes_vendidos,
           ISNULL(v.ventas_usd, 0)                                AS ventas_usd,
           ISNULL(c.cobros_usd, 0)                                AS cobros_confirmados_usd,
           ISNULL(r.reembolsos_usd, 0)                            AS reembolsos_usd,
           ISNULL(c.cobros_usd, 0) - ISNULL(r.reembolsos_usd, 0)  AS cobro_neto_usd
    FROM meses AS m
    LEFT JOIN ventas     AS v ON v.mes = m.mes
    LEFT JOIN cobros     AS c ON c.mes = m.mes
    LEFT JOIN reembolsos AS r ON r.mes = m.mes
    ORDER BY m.mes;
END;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '07_procedimientos')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('07_procedimientos', N'Procedimientos almacenados');
GO
SET NOEXEC OFF;
GO
