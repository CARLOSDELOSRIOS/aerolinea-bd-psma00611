/* =============================================================================
   12_pruebas_integridad.sql
   Propósito : pruebas automatizadas de reglas, integridad y operaciones críticas.
   Diseño    :
     - tst.usp_preparar_escenario crea un escenario aislado y relativo a la
       fecha real de ejecución: activa la ruta BOS-ORD (inactiva en los datos),
       crea un avión de prueba (E175: 12 VIP + 64 ECO), tarifas, una
       programación y un vuelo a @dias_hasta_vuelo días.
     - tst.usp_ejecutar_pruebas ejecuta cada prueba dentro de una transacción
       que SIEMPRE se revierte: no deja datos. Los resultados se acumulan en una
       variable de tabla (no afectada por ROLLBACK) y al final se guardan en
       tst.resultado_prueba.
     - Las pruebas de concurrencia (varias sesiones simultáneas) están en
       src/aerolinea/pruebas.py porque requieren conexiones paralelas.
   Ejecución : EXEC tst.usp_ejecutar_pruebas;   (SSMS o python -m aerolinea pruebas)
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

CREATE OR ALTER PROCEDURE tst.usp_preparar_escenario
    @numero_vuelo       SMALLINT = 9901,
    @dias_hasta_vuelo   INT      = 30,
    @hora_salida        TIME(0)  = '10:00',
    @asignar_avion      BIT      = 1,
    @id_vuelo           INT      = NULL OUTPUT,
    @id_avion           SMALLINT = NULL OUTPUT,
    @id_comprador       INT      = NULL OUTPUT,
    @id_web             INT      = NULL OUTPUT,
    @id_mostrador       INT      = NULL OUTPUT,
    @id_vendedor        INT      = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @hoy DATE = CAST(SYSUTCDATETIME() AS DATE);
    DECLARE @fecha DATE = DATEADD(DAY, @dias_hasta_vuelo, @hoy);
    DECLARE @id_ruta SMALLINT = (SELECT r.id_ruta FROM ops.ruta AS r
                                 JOIN ref.aeropuerto AS o ON o.id_localizacion = r.id_aeropuerto_origen AND o.codigo_iata = 'BOS'
                                 JOIN ref.aeropuerto AS d ON d.id_localizacion = r.id_aeropuerto_destino AND d.codigo_iata = 'ORD');
    UPDATE ops.ruta SET activa = 1 WHERE id_ruta = @id_ruta AND activa = 0;

    IF NOT EXISTS (SELECT 1 FROM ops.avion WHERE matricula = 'N99TST')
        INSERT ops.avion (matricula, numero_serie, id_configuracion, fecha_fabricacion, fecha_incorporacion, id_aeropuerto_base)
        SELECT 'N99TST', 'MSN-PRUEBA-0001', id_configuracion, '20200101', '20260101',
               (SELECT id_localizacion FROM ref.aeropuerto WHERE codigo_iata = 'BOS')
        FROM ops.configuracion_asientos WHERE codigo_configuracion = 'E175-12V64E';
    SET @id_avion = (SELECT id_avion FROM ops.avion WHERE matricula = 'N99TST');

    IF NOT EXISTS (SELECT 1 FROM ven.tarifa WHERE id_ruta = @id_ruta)
        INSERT ven.tarifa (id_ruta, codigo_cabina, precio_base_usd, vigente_desde, vigente_hasta)
        VALUES (@id_ruta, 'ECO', 199.99, DATEADD(DAY, -30, @hoy), NULL),
               (@id_ruta, 'VIP', 499.99, DATEADD(DAY, -30, @hoy), NULL);

    DECLARE @id_programacion INT;
    INSERT ops.programacion (numero_vuelo, id_ruta, hora_salida_local, duracion_programada_min, vigente_desde, vigente_hasta)
    VALUES (@numero_vuelo, @id_ruta, @hora_salida, 150, @fecha, @fecha);
    SET @id_programacion = CAST(SCOPE_IDENTITY() AS INT);
    INSERT ops.programacion_dia (id_programacion, dia_semana)
    VALUES (@id_programacion, DATEDIFF(DAY, CAST('19000101' AS DATE), @fecha) % 7 + 1);

    EXEC ops.usp_generar_vuelos @fecha_desde = @fecha, @fecha_hasta = @fecha;
    SET @id_vuelo = (SELECT id_vuelo FROM ops.vuelo WHERE id_programacion = @id_programacion);
    IF @asignar_avion = 1
        EXEC ops.usp_asignar_avion @id_vuelo = @id_vuelo, @id_avion = @id_avion;

    EXEC ven.usp_registrar_persona @nombres = N'Prueba', @apellidos = N'Comprador', @fecha_nacimiento = '19900101',
         @genero = 'F', @email_contacto = 'comprador@prueba.test', @id_persona = @id_comprador OUTPUT;
    SET @id_web = (SELECT id_localizacion FROM ref.localizacion WHERE codigo_localizacion = 'WEB-SITIO');
    SET @id_mostrador = (SELECT id_localizacion FROM ref.localizacion WHERE codigo_localizacion = 'AER-BOS');
    SET @id_vendedor = (SELECT TOP (1) id_empleado FROM rh.empleado
                        WHERE codigo_cargo = 'AGENTE_VTA' AND id_localizacion_base = @id_mostrador AND fecha_terminacion IS NULL
                        ORDER BY numero_empleado);
END;
GO

/* Pasajero nuevo con los datos exigidos para volar. */
CREATE OR ALTER PROCEDURE tst.usp_nuevo_pasajero @sufijo INT, @id_persona INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @apellido NVARCHAR(60) = CONCAT(N'Pasajero', @sufijo);
    EXEC ven.usp_registrar_persona @nombres = N'Prueba', @apellidos = @apellido, @fecha_nacimiento = '19850615',
         @genero = 'M', @id_persona = @id_persona OUTPUT;
END;
GO

/* Elimina los escenarios de prueba confirmados por las pruebas de concurrencia
   (vuelos 9900-9999, avión N99TST, personas *@prueba.test o apellido PasajeroN).
   Desactiva temporalmente los triggers de borrado: uso exclusivo de pruebas. */
CREATE OR ALTER PROCEDURE tst.usp_limpiar_escenarios
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    DECLARE @vuelos TABLE (id_vuelo INT PRIMARY KEY);
    INSERT @vuelos SELECT v.id_vuelo FROM ops.vuelo AS v JOIN ops.programacion AS p ON p.id_programacion = v.id_programacion
                   WHERE p.numero_vuelo BETWEEN 9900 AND 9999;
    DECLARE @tiquetes TABLE (id_tiquete INT PRIMARY KEY, id_compra INT);
    INSERT @tiquetes SELECT id_tiquete, id_compra FROM ven.tiquete WHERE id_vuelo IN (SELECT id_vuelo FROM @vuelos);

    ALTER TABLE ven.reembolso DISABLE TRIGGER ALL;
    ALTER TABLE ven.pago DISABLE TRIGGER ALL;
    ALTER TABLE ven.tiquete DISABLE TRIGGER ALL;
    DELETE r FROM ven.reembolso AS r JOIN ven.pago AS p ON p.id_pago = r.id_pago WHERE p.id_tiquete IN (SELECT id_tiquete FROM @tiquetes);
    DELETE FROM ven.pago WHERE id_tiquete IN (SELECT id_tiquete FROM @tiquetes);
    DELETE FROM ven.tiquete WHERE id_tiquete IN (SELECT id_tiquete FROM @tiquetes);
    ALTER TABLE ven.tiquete ENABLE TRIGGER ALL;
    ALTER TABLE ven.pago ENABLE TRIGGER ALL;
    ALTER TABLE ven.reembolso ENABLE TRIGGER ALL;

    DELETE FROM ven.compra WHERE id_compra IN (SELECT id_compra FROM @tiquetes)
       AND NOT EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_compra = ven.compra.id_compra);
    DELETE FROM aud.cambio_estado WHERE entidad = 'VUELO' AND id_entidad IN (SELECT id_vuelo FROM @vuelos);
    DELETE FROM aud.cambio_estado WHERE entidad = 'TIQUETE' AND id_entidad IN (SELECT id_tiquete FROM @tiquetes);
    DELETE FROM ops.asignacion_tripulacion WHERE id_vuelo IN (SELECT id_vuelo FROM @vuelos);
    DELETE FROM ops.vuelo_cabina WHERE id_vuelo IN (SELECT id_vuelo FROM @vuelos);
    DELETE FROM ops.vuelo WHERE id_vuelo IN (SELECT id_vuelo FROM @vuelos);
    DELETE pd FROM ops.programacion_dia AS pd JOIN ops.programacion AS p ON p.id_programacion = pd.id_programacion WHERE p.numero_vuelo BETWEEN 9900 AND 9999;
    DELETE FROM ops.programacion WHERE numero_vuelo BETWEEN 9900 AND 9999;
    DELETE FROM ops.avion WHERE matricula = 'N99TST' AND NOT EXISTS (SELECT 1 FROM ops.vuelo AS v WHERE v.id_avion = ops.avion.id_avion);
    DELETE FROM ven.persona WHERE (email_contacto LIKE '%@prueba.test' OR (nombres = N'Prueba' AND apellidos LIKE N'Pasajero%'))
       AND NOT EXISTS (SELECT 1 FROM ven.compra AS c WHERE c.id_persona_comprador = ven.persona.id_persona)
       AND NOT EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_persona_pasajero = ven.persona.id_persona);
    DELETE t FROM ven.tarifa AS t JOIN ops.ruta AS r ON r.id_ruta = t.id_ruta
    JOIN ref.aeropuerto AS o ON o.id_localizacion = r.id_aeropuerto_origen AND o.codigo_iata = 'BOS'
    JOIN ref.aeropuerto AS d ON d.id_localizacion = r.id_aeropuerto_destino AND d.codigo_iata = 'ORD'
    WHERE NOT EXISTS (SELECT 1 FROM ven.tiquete AS x WHERE x.id_tarifa = t.id_tarifa);
    UPDATE r SET activa = 0 FROM ops.ruta AS r
    JOIN ref.aeropuerto AS o ON o.id_localizacion = r.id_aeropuerto_origen AND o.codigo_iata = 'BOS'
    JOIN ref.aeropuerto AS d ON d.id_localizacion = r.id_aeropuerto_destino AND d.codigo_iata = 'ORD';
    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE tst.usp_ejecutar_pruebas
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @r TABLE (orden INT IDENTITY(1,1), id_prueba VARCHAR(20), regla VARCHAR(20), descripcion NVARCHAR(300),
                      resultado VARCHAR(10), detalle NVARCHAR(1000));
    DECLARE @v INT, @avion SMALLINT, @comprador INT, @web INT, @mostrador INT, @vendedor INT,
            @p1 INT, @p2 INT, @p3 INT, @t1 INT, @t2 INT, @t3 INT, @pago INT, @compra INT,
            @err INT, @msg NVARCHAR(2048), @ok BIT, @det NVARCHAR(1000), @precio DECIMAL(10,2), @precio2 DECIMAL(10,2),
            @saldo DECIMAL(10,2), @estado VARCHAR(15), @reemb DECIMAL(10,2), @ret DECIMAL(10,2), @regla VARCHAR(20),
            @pct DECIMAL(5,2), @n INT, @n2 INT, @i INT, @ahora DATETIME2(0), @salida DATETIME2(0), @tarifa INT;

    EXEC tst.usp_limpiar_escenarios;   -- por si una ejecución anterior se interrumpió

    /* ---------------------------------------------- PR-01 integridad referencial */
    SET @err = 0;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT ven.pago (id_tiquete, codigo_metodo, id_localizacion_cobro, monto_usd, codigo_estado, fecha_resolucion_utc, referencia_autorizacion)
        VALUES (-1, 'BILLETERA', 1, 10, 'CONFIRMADO', SYSUTCDATETIME(), 'X');
    END TRY BEGIN CATCH SELECT @err = ERROR_NUMBER(), @msg = ERROR_MESSAGE(); END CATCH;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @r VALUES ('PR-01', 'FK', N'Un pago de un tiquete inexistente es rechazado (clave foránea)',
                      CASE WHEN @err = 547 AND @msg LIKE '%fk_pago_tiquete%' THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@err, ': ', LEFT(@msg, 300)));

    /* ---------------------------------------------- PR-02 valores inválidos (CHECK) */
    SET @n = 0;
    BEGIN TRANSACTION;
    BEGIN TRY UPDATE TOP (1) ops.ruta SET id_aeropuerto_destino = id_aeropuerto_origen; END TRY BEGIN CATCH IF ERROR_NUMBER() IN (547, 2627) SET @n += 1; END CATCH;
    BEGIN TRY UPDATE TOP (1) ven.descuento SET porcentaje = 150; END TRY BEGIN CATCH IF ERROR_NUMBER() = 547 SET @n += 1; END CATCH;
    BEGIN TRY UPDATE TOP (1) ven.persona SET email_contacto = 'sin-arroba'; END TRY BEGIN CATCH IF ERROR_NUMBER() = 547 SET @n += 1; END CATCH;
    BEGIN TRY UPDATE TOP (1) ops.vuelo_cabina SET plazas_ocupadas = capacidad + 1; END TRY BEGIN CATCH IF ERROR_NUMBER() = 547 SET @n += 1; END CATCH;
    BEGIN TRY INSERT ref.aeropuerto (id_localizacion, codigo_iata, codigo_icao, latitud, longitud)
              SELECT id_localizacion, 'abc', 'ABCD', 0, 0 FROM ref.localizacion WHERE codigo_localizacion = 'OFI-NYC'; END TRY
    BEGIN CATCH IF ERROR_NUMBER() = 547 SET @n += 1; END CATCH;   -- minúsculas y subtipo de otra localización
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @r VALUES ('PR-02', 'CHECK', N'Valores inválidos rechazados: ruta circular, % > 100, correo, sobreocupación, IATA en minúsculas y subtipo incorrecto',
                      CASE WHEN @n = 5 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 5 rechazos'));

    /* ---------------------------------------------- PR-03 compra sin registro */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_avion = @avion OUTPUT, @id_comprador = @comprador OUTPUT,
             @id_web = @web OUTPUT, @id_mostrador = @mostrador OUTPUT, @id_vendedor = @vendedor OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        SELECT @ok = CASE WHEN comprador_registrado = 0 AND canal = 'WEB' THEN 1 ELSE 0 END FROM rpt.v_venta WHERE id_tiquete = @t1;
        SET @det = CONCAT(N'tiquete ', @t1, N', precio ', @precio, N', comprador no registrado');
        ROLLBACK;
        INSERT @r VALUES ('PR-03', 'RE', N'Una persona sin cuenta compra un tiquete en la web', CASE WHEN @ok = 1 THEN 'SUPERADA' ELSE 'FALLIDA' END, @det);
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-03', 'RE', N'Compra sin registro', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-04 descuento solo para registrados */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        SET @err = 0;
        BEGIN TRY
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_descuento = 'CLIENTE10';
        END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
        ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_registrar_cliente @id_persona = @comprador, @email_acceso = 'cliente@prueba.test';
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_descuento = 'CLIENTE10',
             @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        SELECT @pct = porcentaje_descuento FROM ven.tiquete WHERE id_tiquete = @t1;
        ROLLBACK;
        INSERT @r VALUES ('PR-04', 'RN-21', N'CLIENTE10: rechazado sin cuenta (50115) y aplicado al registrarse (10 %, 199,99 -> 179,99)',
                          CASE WHEN @err = 50115 AND @pct = 10 AND @precio = 179.99 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(N'error sin registro ', @err, N'; con registro ', @pct, N' % => ', @precio));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-04', 'RN-21', N'Descuento para registrados', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-05 precio histórico */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        SET @ahora = SYSUTCDATETIME();
        DECLARE @hace5 DATETIME2(0) = DATEADD(DAY, -5, @ahora);
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @fecha_venta_utc = @hace5,
             @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        SELECT @tarifa = id_tarifa FROM ven.tiquete WHERE id_tiquete = @t1;
        SET @n = 0;
        BEGIN TRY UPDATE ven.tarifa SET precio_base_usd = 1.00 WHERE id_tarifa = @tarifa; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50003 SET @n += 1; END CATCH;
        ROLLBACK;   -- el error del trigger revierte la transacción: se repite el escenario para el resto de la prueba
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @fecha_venta_utc = @hace5,
             @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        SELECT @tarifa = id_tarifa FROM ven.tiquete WHERE id_tiquete = @t1;
        -- Nueva versión de tarifa: se cierra la vigente ayer y se abre otra desde hoy a 249,99.
        UPDATE ven.tarifa SET vigente_hasta = DATEADD(DAY, -1, CAST(@ahora AS DATE)) WHERE id_tarifa = @tarifa;
        INSERT ven.tarifa (id_ruta, codigo_cabina, precio_base_usd, vigente_desde)
        SELECT id_ruta, codigo_cabina, 249.99, CAST(@ahora AS DATE) FROM ven.tarifa WHERE id_tarifa = @tarifa;
        EXEC tst.usp_nuevo_pasajero @sufijo = 1, @id_persona = @p1 OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @p1,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web,
             @id_tiquete = @t2 OUTPUT, @precio_final_usd = @precio2 OUTPUT;
        SELECT @det = CONCAT(N'tiquete anterior ', (SELECT precio_final_usd FROM ven.tiquete WHERE id_tiquete = @t1),
                             N' USD; tiquete nuevo ', @precio2, N' USD');
        SET @ok = CASE WHEN (SELECT precio_final_usd FROM ven.tiquete WHERE id_tiquete = @t1) = 199.99 AND @precio2 = 249.99 THEN 1 ELSE 0 END;
        BEGIN TRY UPDATE ven.tiquete SET precio_base_usd = 1.00 WHERE id_tiquete = @t1; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50040 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-05', 'RN-19/20', N'Precio histórico: la tarifa usada no se edita (50003), una nueva versión no altera ventas previas y el precio del tiquete es inmutable (50040)',
                          CASE WHEN @ok = 1 AND @n = 2 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@det, N'; rechazos ', @n, N' de 2'));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-05', 'RN-19/20', N'Precio histórico', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-06 pagos parciales y conciliación */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT, @id_mostrador = @mostrador OUTPUT, @id_vendedor = @vendedor OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @mostrador, @id_empleado_vendedor = @vendedor,
             @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'TC', @monto_usd = 100.00, @id_localizacion_cobro = @web,
             @resultado = 'FALLIDO', @ultimos4_tarjeta = '4242', @marca_tarjeta = 'VISA', @saldo_pendiente_usd = @saldo OUTPUT;
        DECLARE @saldo_tras_fallido DECIMAL(10,2) = @saldo;
        EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'EFECTIVO', @monto_usd = 200.00, @id_localizacion_cobro = @mostrador,
             @saldo_pendiente_usd = @saldo OUTPUT, @estado_tiquete = @estado OUTPUT;
        DECLARE @estado_parcial VARCHAR(15) = @estado, @saldo_parcial DECIMAL(10,2) = @saldo;
        EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'TC', @monto_usd = 299.99, @id_localizacion_cobro = @web,
             @ultimos4_tarjeta = '4242', @marca_tarjeta = 'VISA', @saldo_pendiente_usd = @saldo OUTPUT, @estado_tiquete = @estado OUTPUT;
        SELECT @det = CONCAT(N'precio ', @precio, N'; tras fallido saldo ', @saldo_tras_fallido, N'; tras 200 en efectivo ', @estado_parcial,
                             N' saldo ', @saldo_parcial, N'; tras 299,99 ', @estado, N' saldo ', @saldo, N'; cobrado ', cobrado_usd,
                             N' en ', pagos_confirmados, N' pagos y ', pagos_fallidos, N' fallido')
        FROM rpt.v_tiquete_financiero WHERE id_tiquete = @t1;
        SET @ok = CASE WHEN @saldo_tras_fallido = 499.99 AND @estado_parcial = 'RESERVADO' AND @saldo_parcial = 299.99
                            AND @estado = 'EMITIDO' AND @saldo = 0 THEN 1 ELSE 0 END;
        ROLLBACK;
        INSERT @r VALUES ('PR-06', 'RN-23/24', N'Pago fallido sin efecto, pago parcial deja saldo y el pago final emite el tiquete',
                          CASE WHEN @ok = 1 THEN 'SUPERADA' ELSE 'FALLIDA' END, @det);
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-06', 'RN-23/24', N'Pagos parciales', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-07 sobrepago y efectivo en web */
    BEGIN TRY
        SET @n = 0;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
        BEGIN TRY EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'BILLETERA', @monto_usd = 500.00, @id_localizacion_cobro = @web; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50135 SET @n += 1; END CATCH;
        ROLLBACK;
        BEGIN TRANSACTION;   -- inserción directa (sin procedimiento): la garantiza el trigger
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
        BEGIN TRY
            INSERT ven.pago (id_tiquete, codigo_metodo, id_localizacion_cobro, monto_usd, codigo_estado, fecha_resolucion_utc, referencia_autorizacion)
            VALUES (@t1, 'BILLETERA', @web, 500.00, 'CONFIRMADO', SYSUTCDATETIME(), 'AUTPRUEBA');
        END TRY BEGIN CATCH IF ERROR_NUMBER() = 50054 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
        BEGIN TRY EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'EFECTIVO', @monto_usd = 50.00, @id_localizacion_cobro = @web; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50055 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-07', 'RN-23/25/37', N'Sobrepago rechazado por el procedimiento (50135) y por el trigger (50054); efectivo en web rechazado (50055)',
                          CASE WHEN @n = 3 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 3 rechazos'));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-07', 'RN-23/25', N'Sobrepago y efectivo', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-08 asiento duplicado e inválido */
    BEGIN TRY
        SET @n = 0;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC tst.usp_nuevo_pasajero @sufijo = 1, @id_persona = @p1 OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_asiento = '14A';
        BEGIN TRY
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @p1,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_asiento = '14A';
        END TRY BEGIN CATCH IF ERROR_NUMBER() = 50120 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        BEGIN TRY   -- 1A pertenece a VIP
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_asiento = '1A';
        END TRY BEGIN CATCH IF ERROR_NUMBER() = 50049 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web;
        BEGIN TRY   -- el mismo pasajero dos veces en el vuelo
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @comprador,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web;
        END TRY BEGIN CATCH IF ERROR_NUMBER() = 50121 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-08', 'RN-12/13/14', N'Asiento duplicado (50120), asiento de otra cabina (50049) y pasajero repetido en el vuelo (50121) rechazados',
                          CASE WHEN @n = 3 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 3 rechazos'));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-08', 'RN-12/13/14', N'Asientos', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-09 sobreventa y liberación de plaza */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        SET @i = 1;
        WHILE @i <= 12      -- la cabina VIP del E175 tiene 12 asientos
        BEGIN
            EXEC tst.usp_nuevo_pasajero @sufijo = @i, @id_persona = @p1 OUTPUT;
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @p1,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
            SET @i += 1;
        END;
        SELECT @n = plazas_ocupadas FROM ops.vuelo_cabina WHERE id_vuelo = @v AND codigo_cabina = 'VIP';
        EXEC ven.usp_cancelar_tiquete @id_tiquete = @t1;
        SELECT @n2 = plazas_ocupadas FROM ops.vuelo_cabina WHERE id_vuelo = @v AND codigo_cabina = 'VIP';
        EXEC tst.usp_nuevo_pasajero @sufijo = 13, @id_persona = @p2 OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @p2,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web;
        EXEC tst.usp_nuevo_pasajero @sufijo = 14, @id_persona = @p3 OUTPUT;
        SET @err = 0;
        BEGIN TRY
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @p3,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web;
        END TRY BEGIN CATCH SELECT @err = ERROR_NUMBER(), @msg = ERROR_MESSAGE(); END CATCH;
        SELECT @det = CONCAT(N'ocupadas tras 12 ventas: ', @n, N'; tras cancelar una: ', @n2, N'; tras revender: ', plazas_ocupadas,
                             N'; venta 13 => error ', @err, N' ', LEFT(@msg, 120))
        FROM ops.vuelo_cabina WHERE id_vuelo = @v AND codigo_cabina = 'VIP';
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-09', 'RN-11', N'Sin sobreventa: la venta 13 de una cabina de 12 se rechaza; cancelar libera la plaza',
                          CASE WHEN @n = 12 AND @n2 = 11 AND @err = 50020 THEN 'SUPERADA' ELSE 'FALLIDA' END, @det);
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-09', 'RN-11', N'Sobreventa', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-10 rollback de una operación incompleta */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        COMMIT;    -- escenario confirmado para observar que la venta fallida no deja una compra huérfana
        SELECT @n = COUNT(*) FROM ven.compra WHERE id_persona_comprador = @comprador;
        SET @err = 0;
        BEGIN TRY   -- la compra se inserta y luego falla el tiquete (asiento inexistente): todo se revierte
            EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
                 @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @codigo_asiento = '99Z';
        END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
        SELECT @n2 = COUNT(*) FROM ven.compra WHERE id_persona_comprador = @comprador;
        EXEC tst.usp_limpiar_escenarios;
        INSERT @r VALUES ('PR-10', 'ACID', N'Si falla el tiquete, la compra creada en la misma transacción también se revierte',
                          CASE WHEN @err IN (50049, 547) AND @n = 0 AND @n2 = 0 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(N'error ', @err, N'; compras antes ', @n, N', después ', @n2));
    END TRY BEGIN CATCH DECLARE @m10 NVARCHAR(2048) = ERROR_MESSAGE(); IF @@TRANCOUNT > 0 ROLLBACK; EXEC tst.usp_limpiar_escenarios; INSERT @r VALUES ('PR-10', 'ACID', N'Rollback', 'FALLIDA', @m10); END CATCH;

    /* ---------------------------------------------- PR-11 transiciones inválidas */
    BEGIN TRY
        SET @n = 0;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
        SET @det = N'errores observados:';
        BEGIN TRY UPDATE ven.tiquete SET codigo_estado = 'USADO', fecha_emision_utc = SYSUTCDATETIME() WHERE id_tiquete = @t1; END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N' ', ERROR_NUMBER()); IF ERROR_NUMBER() = 50042 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador,
             @id_persona_comprador = @comprador, @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT;
        BEGIN TRY UPDATE ven.tiquete SET codigo_estado = 'EMITIDO', fecha_emision_utc = SYSUTCDATETIME() WHERE id_tiquete = @t1; END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N' ', ERROR_NUMBER()); IF ERROR_NUMBER() = 50047 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT;
        BEGIN TRY UPDATE ops.vuelo SET codigo_estado = 'ATERRIZADO', llegada_real = llegada_programada, salida_real = salida_programada WHERE id_vuelo = @v; END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N' ', ERROR_NUMBER(), N' (', LEFT(ERROR_MESSAGE(), 90), N')'); IF ERROR_NUMBER() = 50023 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-11', 'RN-08/24', N'Transiciones inválidas rechazadas: RESERVADO->USADO (50042), emisión sin pago (50047), PROGRAMADO->ATERRIZADO (50023)',
                          CASE WHEN @n = 3 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 3 rechazos; ', @det));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-11', 'RN-08', N'Transiciones', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-12 política de reembolso */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        SELECT @salida = CONVERT(DATETIME2(0), SWITCHOFFSET(salida_programada, '+00:00')) FROM ops.vuelo WHERE id_vuelo = @v;
        SET @ahora = SYSUTCDATETIME();
        DECLARE @hace2h DATETIME2(0) = DATEADD(HOUR, -2, @ahora), @hace10d DATETIME2(0) = DATEADD(DAY, -10, @ahora);
        DECLARE @c48 DATETIME2(0) = DATEADD(HOUR, -48, @salida), @c10d DATETIME2(0) = DATEADD(DAY, -10, @salida);
        EXEC tst.usp_nuevo_pasajero @sufijo = 1, @id_persona = @p1 OUTPUT;
        EXEC tst.usp_nuevo_pasajero @sufijo = 2, @id_persona = @p2 OUTPUT;
        -- a) regla de 24 h: venta hace 2 h, vuelo en 30 días, cancelación ahora => 100 %
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @fecha_venta_utc = @hace2h, @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'BILLETERA', @monto_usd = @precio, @id_localizacion_cobro = @web, @fecha_pago_utc = @hace2h;
        EXEC ven.usp_cancelar_tiquete @id_tiquete = @t1, @monto_reembolsado_usd = @reemb OUTPUT, @regla_aplicada = @regla OUTPUT;
        SET @det = CONCAT(N'a) ', @regla, N' ', @reemb);
        SET @ok = CASE WHEN @regla = 'REGLA_24H' AND @reemb = @precio THEN 1 ELSE 0 END;
        -- b) ECO cancelado 48 h antes (venta hace 10 días) => 0 % (fila 0 h de la política)
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @p1, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @fecha_venta_utc = @hace10d, @id_tiquete = @t2 OUTPUT, @precio_final_usd = @precio OUTPUT;
        EXEC ven.usp_registrar_pago @id_tiquete = @t2, @codigo_metodo = 'BILLETERA', @monto_usd = @precio, @id_localizacion_cobro = @web, @fecha_pago_utc = @hace10d;
        EXEC ven.usp_cancelar_tiquete @id_tiquete = @t2, @fecha_cancelacion_utc = @c48, @monto_reembolsado_usd = @reemb OUTPUT,
             @monto_retenido_usd = @ret OUTPUT, @porcentaje_reembolso = @pct OUTPUT;
        SET @det = CONCAT(@det, N'; b) ECO 48 h: ', @pct, N' % reembolso ', @reemb, N' retenido ', @ret);
        SET @ok = @ok & CASE WHEN @pct = 0 AND @reemb = 0 AND @ret = @precio THEN 1 ELSE 0 END;
        -- c) VIP cancelado 10 días antes => 90 %, con dos pagos: reembolso del más reciente al más antiguo
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'VIP', @id_persona_pasajero = @p2, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @fecha_venta_utc = @hace10d, @id_tiquete = @t3 OUTPUT, @precio_final_usd = @precio OUTPUT;
        DECLARE @hace9d DATETIME2(0) = DATEADD(DAY, -9, @ahora), @resto DECIMAL(10,2) = @precio - 100.00;
        EXEC ven.usp_registrar_pago @id_tiquete = @t3, @codigo_metodo = 'BILLETERA', @monto_usd = 100.00, @id_localizacion_cobro = @web, @fecha_pago_utc = @hace10d;
        EXEC ven.usp_registrar_pago @id_tiquete = @t3, @codigo_metodo = 'BILLETERA', @monto_usd = @resto, @id_localizacion_cobro = @web, @fecha_pago_utc = @hace9d;
        EXEC ven.usp_cancelar_tiquete @id_tiquete = @t3, @fecha_cancelacion_utc = @c10d, @monto_reembolsado_usd = @reemb OUTPUT,
             @porcentaje_reembolso = @pct OUTPUT;
        SELECT @n = COUNT(*) FROM ven.reembolso AS r JOIN ven.pago AS p ON p.id_pago = r.id_pago WHERE p.id_tiquete = @t3;
        SET @det = CONCAT(@det, N'; c) VIP 10 días: ', @pct, N' % = ', @reemb, N' en ', @n, N' reembolsos');
        SET @ok = @ok & CASE WHEN @pct = 90 AND @reemb = CAST(ROUND(@precio * 0.9, 2) AS DECIMAL(10,2)) AND @n = 2 THEN 1 ELSE 0 END;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-12', 'RN-36', N'Política de reembolso: regla de 24 h, ECO 48 h antes (0 %) y VIP 10 días antes (90 %) repartido sobre dos pagos',
                          CASE WHEN @ok = 1 THEN 'SUPERADA' ELSE 'FALLIDA' END, @det);
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-12', 'RN-36', N'Reembolsos', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-13 cancelación del vuelo y vencimiento */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        EXEC tst.usp_nuevo_pasajero @sufijo = 1, @id_persona = @p1 OUTPUT;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @id_tiquete = @t1 OUTPUT, @precio_final_usd = @precio OUTPUT;
        EXEC ven.usp_registrar_pago @id_tiquete = @t1, @codigo_metodo = 'BILLETERA', @monto_usd = @precio, @id_localizacion_cobro = @web;
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @p1, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @id_tiquete = @t2 OUTPUT;
        EXEC ops.usp_cambiar_estado_vuelo @id_vuelo = @v, @nuevo_estado = 'CANCELADO', @motivo_cancelacion = N'Prueba', @tiquetes_cancelados = @n OUTPUT;
        SELECT @det = CONCAT(N'tiquetes cancelados ', @n, N'; reembolsado ', SUM(reembolsado_usd), N' de ', SUM(cobrado_usd),
                             N'; plazas ocupadas ', (SELECT SUM(plazas_ocupadas) FROM ops.vuelo_cabina WHERE id_vuelo = @v))
        FROM rpt.v_tiquete_financiero WHERE id_vuelo = @v;
        SELECT @ok = CASE WHEN @n = 2 AND SUM(reembolsado_usd) = SUM(cobrado_usd) AND MIN(codigo_estado) = 'CANCELADO' AND MAX(codigo_estado) = 'CANCELADO'
                          AND (SELECT SUM(plazas_ocupadas) FROM ops.vuelo_cabina WHERE id_vuelo = @v) = 0 THEN 1 ELSE 0 END
        FROM rpt.v_tiquete_financiero WHERE id_vuelo = @v;
        ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT;
        SET @hace10d = DATEADD(DAY, -10, SYSUTCDATETIME());
        EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador, @id_persona_comprador = @comprador,
             @id_localizacion_venta = @web, @fecha_venta_utc = @hace10d, @id_tiquete = @t1 OUTPUT;
        EXEC ven.usp_vencer_reservas @tiquetes_vencidos = @n OUTPUT;
        SELECT @det = CONCAT(@det, N' | vencidas ', @n, N'; estado ', codigo_estado, N' ', codigo_motivo_cancelacion) FROM ven.tiquete WHERE id_tiquete = @t1;
        SELECT @ok = @ok & CASE WHEN codigo_estado = 'CANCELADO' AND codigo_motivo_cancelacion = 'VENCIMIENTO' THEN 1 ELSE 0 END FROM ven.tiquete WHERE id_tiquete = @t1;
        ROLLBACK;
        INSERT @r VALUES ('PR-13', 'SUP-07/11', N'Cancelar un vuelo cancela sus tiquetes con reembolso total y libera plazas; una reserva sin pago vence',
                          CASE WHEN @ok = 1 THEN 'SUPERADA' ELSE 'FALLIDA' END, @det);
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-13', 'SUP-07/11', N'Cancelación de vuelo', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-14 consistencia temporal */
    BEGIN TRY
        SET @n = 0;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT;
        BEGIN TRY UPDATE ops.vuelo SET salida_programada = SWITCHOFFSET(salida_programada, '-08:00') WHERE id_vuelo = @v; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50026 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT;
        BEGIN TRY UPDATE ops.vuelo SET llegada_programada = DATEADD(MINUTE, -10, salida_programada) WHERE id_vuelo = @v; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 547 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        -- Independencia de SET DATEFIRST: el día ISO del calendario no cambia.
        SET DATEFIRST 7;
        SELECT @n2 = dia_semana_iso FROM ref.fn_calendario('20261101', '20261101');
        SET DATEFIRST 1;
        SELECT @i = dia_semana_iso FROM ref.fn_calendario('20261101', '20261101');
        INSERT @r VALUES ('PR-14', 'RN-05/06', N'Desfase horario incorrecto (50026) y llegada anterior a la salida (CHECK) rechazados; el día ISO no depende de DATEFIRST',
                          CASE WHEN @n = 2 AND @n2 = 7 AND @i = 7 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(@n, N' de 2 rechazos; 2026-11-01 = día ', @n2, N' / ', @i, N' (domingo = 7)'));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-14', 'RN-05/06', N'Consistencia temporal', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-15 asignación temporal de avión y tripulación */
    BEGIN TRY
        SET @n = 0;
        DECLARE @v2 INT, @cap INT, @fo INT, @jefe INT, @aux INT, @agente INT, @desde DATETIMEOFFSET(0), @hasta DATETIMEOFFSET(0);
        -- Escenarios confirmados (cada rechazo esperado revierte su propia transacción); se limpian al final.
        EXEC tst.usp_preparar_escenario @numero_vuelo = 9901, @hora_salida = '10:00', @id_vuelo = @v OUTPUT, @id_avion = @avion OUTPUT;
        EXEC tst.usp_preparar_escenario @numero_vuelo = 9902, @hora_salida = '11:00', @asignar_avion = 0, @id_vuelo = @v2 OUTPUT;
        -- Tripulantes vigentes sin vuelos en la ventana de los escenarios (±1 día); no se depende de personal sin asignar.
        SELECT @desde = DATEADD(DAY, -1, MIN(salida_programada)), @hasta = DATEADD(DAY, 1, MAX(llegada_programada))
        FROM ops.vuelo WHERE id_vuelo IN (@v, @v2);
        DECLARE @libres TABLE (codigo_cargo VARCHAR(20) NOT NULL, id_empleado INT NOT NULL, orden INT NOT NULL);
        INSERT @libres (codigo_cargo, id_empleado, orden)
        SELECT e.codigo_cargo, e.id_empleado, ROW_NUMBER() OVER (PARTITION BY e.codigo_cargo ORDER BY e.numero_empleado)
        FROM rh.empleado AS e
        WHERE e.codigo_cargo IN ('PILOTO_CAP', 'PILOTO_FO', 'TCP_JEFE', 'TCP') AND e.fecha_terminacion IS NULL
          AND NOT EXISTS (SELECT 1 FROM ops.asignacion_tripulacion AS a JOIN ops.vuelo AS x ON x.id_vuelo = a.id_vuelo
                          WHERE a.id_empleado = e.id_empleado AND x.salida_programada < @hasta AND x.llegada_programada > @desde);
        SELECT @cap  = id_empleado FROM @libres WHERE codigo_cargo = 'PILOTO_CAP' AND orden = 1;
        SELECT @fo   = id_empleado FROM @libres WHERE codigo_cargo = 'PILOTO_FO'  AND orden = 1;
        SELECT @jefe = id_empleado FROM @libres WHERE codigo_cargo = 'TCP_JEFE'   AND orden = 1;
        SELECT @aux  = id_empleado FROM @libres WHERE codigo_cargo = 'TCP'        AND orden = 1;
        SELECT TOP (1) @agente = id_empleado FROM rh.empleado WHERE codigo_cargo = 'AGENTE_VTA' ORDER BY numero_empleado;
        IF @cap IS NULL OR @fo IS NULL OR @jefe IS NULL OR @aux IS NULL
            THROW 50999, N'PR-15: no hay tripulantes libres en la ventana del escenario.', 1;
        SET @err = 0; SET @det = N'errores observados:';   -- 9901 sale a las 10:00 y dura 150 min; 9902 a las 11:00: mismo avión => solape
        BEGIN TRY EXEC ops.usp_asignar_avion @id_vuelo = @v2, @id_avion = @avion; END TRY BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH;
        SET @det = CONCAT(@det, N' avión ', @err);
        IF @err = 50028 SET @n += 1;
        BEGIN TRANSACTION;
        INSERT ops.asignacion_tripulacion (id_vuelo, id_empleado, rol_vuelo) VALUES (@v2, @cap, 'CAPITAN');
        BEGIN TRY INSERT ops.asignacion_tripulacion (id_vuelo, id_empleado, rol_vuelo) VALUES (@v, @cap, 'CAPITAN'); END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N'; solape tripulante ', ERROR_NUMBER()); IF ERROR_NUMBER() = 50034 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        SET @err = 0;
        BEGIN TRY INSERT ops.asignacion_tripulacion (id_vuelo, id_empleado, rol_vuelo) VALUES (@v, @agente, 'CAPITAN'); END TRY
        BEGIN CATCH SET @err = ERROR_NUMBER(); IF ERROR_NUMBER() = 50031 SET @n += 1; END CATCH;
        SET @det = CONCAT(@det, N'; rol incompatible ', @err);
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        DECLARE @despegue DATETIMEOFFSET(0), @aterrizaje DATETIMEOFFSET(0);
        SELECT @despegue = DATEADD(MINUTE, 12, salida_programada), @aterrizaje = DATEADD(MINUTE, 8, llegada_programada)
        FROM ops.vuelo WHERE id_vuelo = @v;
        BEGIN TRY EXEC ops.usp_cambiar_estado_vuelo @id_vuelo = @v, @nuevo_estado = 'EN_VUELO', @momento = @despegue; END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N'; despegue sin tripulación ', ERROR_NUMBER()); IF ERROR_NUMBER() = 50029 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;   -- con tripulación completa (E175: 76 asientos => 2 de cabina) el vuelo despega y aterriza
        INSERT ops.asignacion_tripulacion (id_vuelo, id_empleado, rol_vuelo)
        VALUES (@v, @cap, 'CAPITAN'), (@v, @fo, 'PRIMER_OFICIAL'), (@v, @jefe, 'JEFE_CABINA'), (@v, @aux, 'AUXILIAR_VUELO');
        EXEC ops.usp_cambiar_estado_vuelo @id_vuelo = @v, @nuevo_estado = 'EN_VUELO', @momento = @despegue;
        EXEC ops.usp_cambiar_estado_vuelo @id_vuelo = @v, @nuevo_estado = 'ATERRIZADO', @momento = @aterrizaje;
        SELECT @estado = codigo_estado FROM ops.vuelo WHERE id_vuelo = @v;
        ROLLBACK;
        EXEC tst.usp_limpiar_escenarios;
        INSERT @r VALUES ('PR-15', 'RN-09/33/35', N'Solape de avión (50028) y de tripulante (50034), rol incompatible (50031) y despegue sin tripulación (50029) rechazados; con tripulación completa el vuelo opera',
                          CASE WHEN @n = 4 AND @estado = 'ATERRIZADO' THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 4 rechazos; ', @det, N'; estado final ', @estado));
    END TRY BEGIN CATCH DECLARE @m15 NVARCHAR(2048) = ERROR_MESSAGE(); IF @@TRANCOUNT > 0 ROLLBACK; EXEC tst.usp_limpiar_escenarios; INSERT @r VALUES ('PR-15', 'RN-09/33/35', N'Asignaciones', 'FALLIDA', @m15); END CATCH;

    /* ---------------------------------------------- PR-16 registros financieros no se borran */
    SET @n = 0;
    BEGIN TRANSACTION;
    BEGIN TRY DELETE TOP (1) FROM ven.pago; END TRY BEGIN CATCH IF ERROR_NUMBER() = 50059 SET @n += 1; END CATCH;
    IF @@TRANCOUNT > 0 ROLLBACK;
    BEGIN TRANSACTION;
    BEGIN TRY DELETE TOP (1) FROM ven.tiquete; END TRY BEGIN CATCH IF ERROR_NUMBER() = 50039 SET @n += 1; END CATCH;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @r VALUES ('PR-16', 'RN-29', N'Pagos y tiquetes no se eliminan', CASE WHEN @n = 2 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 2 rechazos'));

    /* ---------------------------------------------- PR-17 programación, tarifas y venta web con vendedor */
    BEGIN TRY
        SET @n = 0;
        BEGIN TRANSACTION;
        BEGIN TRY INSERT ops.programacion (numero_vuelo, id_ruta, hora_salida_local, duracion_programada_min, vigente_desde)
                  SELECT 101, id_ruta, '07:00', 370, '20261015' FROM ops.programacion WHERE numero_vuelo = 101; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50001 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        BEGIN TRY INSERT ven.tarifa (id_ruta, codigo_cabina, precio_base_usd, vigente_desde)
                  SELECT TOP (1) id_ruta, codigo_cabina, 99.99, DATEADD(DAY, 1, vigente_desde) FROM ven.tarifa ORDER BY id_tarifa; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50002 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT, @id_comprador = @comprador OUTPUT, @id_web = @web OUTPUT, @id_vendedor = @vendedor OUTPUT;
        BEGIN TRY EXEC ven.usp_emitir_tiquete @id_vuelo = @v, @codigo_cabina = 'ECO', @id_persona_pasajero = @comprador, @id_persona_comprador = @comprador,
                       @id_localizacion_venta = @web, @id_empleado_vendedor = @vendedor; END TRY
        BEGIN CATCH IF ERROR_NUMBER() = 50012 SET @n += 1; END CATCH;
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @r VALUES ('PR-17', 'RN-03/18/32', N'Programación solapada (50001), tarifa solapada (50002) y venta web con vendedor (50012) rechazadas',
                          CASE WHEN @n = 3 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 3 rechazos'));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-17', 'RN-03/18/32', N'Reglas de catálogo', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-18 generación idempotente de vuelos */
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC tst.usp_preparar_escenario @id_vuelo = @v OUTPUT;
        DECLARE @f DATE = (SELECT fecha_salida_local FROM ops.vuelo WHERE id_vuelo = @v);
        EXEC ops.usp_generar_vuelos @fecha_desde = @f, @fecha_hasta = @f, @vuelos_creados = @n OUTPUT;
        ROLLBACK;
        INSERT @r VALUES ('PR-18', 'RN-04', N'Generar de nuevo los vuelos de una fecha no crea duplicados',
                          CASE WHEN @n = 0 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(N'vuelos creados en la segunda ejecución: ', @n));
    END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; INSERT @r VALUES ('PR-18', 'RN-04', N'Generación idempotente', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-19 permisos y enmascaramiento */
    -- Las sentencias se ejecutan con sp_executesql: dentro de un procedimiento de dbo, una consulta
    -- estática sobre tablas de dbo no comprueba permisos (encadenamiento de propiedad), incluso con
    -- EXECUTE AS. El SQL dinámico rompe la cadena y comprueba los permisos del usuario suplantado.
    BEGIN TRY
        SET @n = 0; SET @det = N'';
        EXECUTE AS USER = 'usr_demo_analista';
        BEGIN TRY EXEC sys.sp_executesql N'SELECT @c = COUNT(*) FROM ven.persona;', N'@c INT OUTPUT', @c = @i OUTPUT; END TRY
        BEGIN CATCH SET @det = CONCAT(N'analista->ven.persona: ', ERROR_NUMBER()); IF ERROR_NUMBER() = 229 SET @n += 1; END CATCH;
        BEGIN TRY EXEC sys.sp_executesql N'SELECT @c = COUNT(*) FROM rpt.v_vuelo;', N'@c INT OUTPUT', @c = @i OUTPUT;
                  SET @n += 1; SET @det = CONCAT(@det, N'; analista->rpt.v_vuelo: ', @i, N' filas'); END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N'; analista->rpt: ', ERROR_NUMBER()); END CATCH;
        REVERT;
        EXECUTE AS USER = 'usr_demo_aplicacion';
        BEGIN TRY EXEC sys.sp_executesql N'DELETE FROM ven.compra WHERE 1 = 0;'; END TRY
        BEGIN CATCH SET @det = CONCAT(@det, N'; aplicación->DELETE: ', ERROR_NUMBER()); IF ERROR_NUMBER() = 229 SET @n += 1; END CATCH;
        REVERT;
        DECLARE @correo VARCHAR(120);
        BEGIN TRANSACTION;
        CREATE USER usr_prueba_mascara WITHOUT LOGIN;
        GRANT SELECT ON ven.persona TO usr_prueba_mascara;
        EXECUTE AS USER = 'usr_prueba_mascara';
        EXEC sys.sp_executesql N'SELECT TOP (1) @e = email_contacto FROM ven.persona WHERE email_contacto IS NOT NULL ORDER BY id_persona;',
             N'@e VARCHAR(120) OUTPUT', @e = @correo OUTPUT;
        REVERT;
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @det = CONCAT(@det, N'; correo visto por un usuario sin UNMASK: ', @correo);
        IF @correo COLLATE Latin1_General_BIN LIKE '_XXX@XXXX.com' SET @n += 1;
        INSERT @r VALUES ('PR-19', 'Seguridad', N'Analista sin acceso a tablas base (229) y con acceso a rpt; la aplicación no escribe directo (229); el correo se muestra enmascarado',
                          CASE WHEN @n = 4 THEN 'SUPERADA' ELSE 'FALLIDA' END, CONCAT(@n, N' de 4; ', @det));
    END TRY BEGIN CATCH DECLARE @m19 NVARCHAR(2048) = ERROR_MESSAGE(); IF @@TRANCOUNT > 0 ROLLBACK; IF USER_NAME() <> N'dbo' REVERT; INSERT @r VALUES ('PR-19', 'Seguridad', N'Permisos', 'FALLIDA', @m19); END CATCH;

    /* ---------------------------------------------- PR-20 agregaciones sin duplicación */
    BEGIN TRY
        DECLARE @directo DECIMAL(18,2), @vista DECIMAL(18,2), @ingenuo DECIMAL(18,2);
        SELECT @directo = SUM(monto_usd) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO';
        SELECT @vista = SUM(cobrado_usd) FROM rpt.v_tiquete_financiero;
        -- Unión ingenua: cada pago se repite por cada reembolso del mismo tiquete (abanico).
        SELECT @ingenuo = SUM(p.monto_usd)
        FROM ven.tiquete AS t
        JOIN ven.pago AS p ON p.id_tiquete = t.id_tiquete AND p.codigo_estado = 'CONFIRMADO'
        LEFT JOIN ven.pago AS p2 ON p2.id_tiquete = t.id_tiquete
        LEFT JOIN ven.reembolso AS r ON r.id_pago = p2.id_pago;
        INSERT @r VALUES ('PR-20', 'Análisis', N'El cobro agregado por la vista coincide con la suma directa; una unión ingenua lo infla',
                          CASE WHEN @directo = @vista AND (@ingenuo > @directo OR @directo IS NULL) THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(N'directo ', @directo, N'; vista ', @vista, N'; unión ingenua ', @ingenuo));
    END TRY BEGIN CATCH INSERT @r VALUES ('PR-20', 'Análisis', N'Agregaciones', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-21 conciliación de los datos cargados */
    BEGIN TRY
        SELECT @n = COUNT(*) FROM rpt.v_conciliacion_inventario WHERE diferencia <> 0;
        SELECT @n2 = COUNT(*) FROM rpt.v_tiquete_financiero WHERE cobrado_usd > precio_final_usd OR reembolsado_usd > cobrado_usd
                        OR (codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') AND cobrado_usd <> precio_final_usd);
        DECLARE @dif DECIMAL(18,2) =
            (SELECT ISNULL(SUM(monto_usd), 0) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO')
          - (SELECT ISNULL(SUM(monto_usd), 0) FROM ven.reembolso)
          - (SELECT ISNULL(SUM(CASE WHEN codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') THEN precio_final_usd
                                    WHEN codigo_estado = 'RESERVADO' THEN cobrado_usd ELSE penalidad_retenida_usd END), 0)
             FROM rpt.v_tiquete_financiero);
        INSERT @r VALUES ('PR-21', 'RN-40', N'Datos cargados: inventario conciliado, sin sobrecobros y con identidad de caja exacta',
                          CASE WHEN @n = 0 AND @n2 = 0 AND @dif = 0 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(N'diferencias de inventario ', @n, N'; tiquetes incoherentes ', @n2, N'; diferencia de caja ', @dif, N' USD'));
    END TRY BEGIN CATCH INSERT @r VALUES ('PR-21', 'RN-40', N'Conciliación', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-22 réplica de la política sobre los datos cargados */
    BEGIN TRY
        SELECT @n = COUNT(*), @n2 = SUM(CASE WHEN f.reembolsado_usd <> CAST(ROUND(f.cobrado_usd * p.porcentaje_reembolso / 100.0, 2) AS DECIMAL(10,2)) THEN 1 ELSE 0 END)
        FROM ven.tiquete AS t
        JOIN rpt.v_tiquete_financiero AS f ON f.id_tiquete = t.id_tiquete
        CROSS APPLY ven.fn_politica_reembolso(t.id_tiquete, t.codigo_motivo_cancelacion, t.fecha_cancelacion_utc) AS p
        WHERE t.codigo_estado = 'CANCELADO';
        INSERT @r VALUES ('PR-22', 'RN-36', N'Cada reembolso cargado coincide con el que calcula ven.fn_politica_reembolso',
                          CASE WHEN ISNULL(@n2, 0) = 0 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(N'tiquetes cancelados verificados ', @n, N'; discrepancias ', ISNULL(@n2, 0)));
    END TRY BEGIN CATCH INSERT @r VALUES ('PR-22', 'RN-36', N'Réplica de política', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* ---------------------------------------------- PR-23 vistas y procedimientos de reporte */
    BEGIN TRY
        DECLARE @resumen TABLE (mes DATE, tiquetes INT, ventas DECIMAL(18,2), cobros DECIMAL(18,2), reembolsos DECIMAL(18,2), neto DECIMAL(18,2));
        INSERT @resumen EXEC rpt.usp_resumen_financiero @fecha_desde = '20260101', @fecha_hasta = '20271231';
        SELECT @n = COUNT(*) FROM @resumen;
        SELECT @directo = ISNULL(SUM(cobros), 0) FROM @resumen;
        SELECT @vista = ISNULL(SUM(monto_usd), 0) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO';
        SELECT @n2 = (SELECT COUNT(*) FROM rpt.v_vuelo) - (SELECT COUNT(*) FROM ops.vuelo);
        INSERT @r VALUES ('PR-23', 'Vistas/SP', N'rpt.usp_resumen_financiero concilia con los pagos y rpt.v_vuelo no pierde ni duplica vuelos',
                          CASE WHEN @directo = @vista AND @n2 = 0 THEN 'SUPERADA' ELSE 'FALLIDA' END,
                          CONCAT(@n, N' meses; cobros del resumen ', @directo, N' = pagos ', @vista, N'; diferencia de filas en v_vuelo ', @n2));
    END TRY BEGIN CATCH INSERT @r VALUES ('PR-23', 'Vistas/SP', N'Reportes', 'FALLIDA', ERROR_MESSAGE()); END CATCH;

    /* --------------------------------------------------------------- resultados */
    DECLARE @ejecucion UNIQUEIDENTIFIER = NEWID();
    INSERT tst.resultado_prueba (id_ejecucion, id_prueba, regla, descripcion, resultado, detalle)
    SELECT @ejecucion, id_prueba, regla, descripcion, resultado, detalle FROM @r ORDER BY orden;
    SELECT id_prueba, regla, resultado, descripcion, detalle FROM @r ORDER BY orden;
END;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '12_pruebas_integridad')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('12_pruebas_integridad', N'Procedimientos de prueba');
GO
SET NOEXEC OFF;
GO
