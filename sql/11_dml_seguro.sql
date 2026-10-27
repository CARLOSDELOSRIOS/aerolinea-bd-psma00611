/* =============================================================================
   11_dml_seguro.sql
   Propósito : ejemplos comentados de INSERT, UPDATE y DELETE sobre datos de
               negocio con un patrón seguro:
                 1. transacción explícita y SET XACT_ABORT ON;
                 2. cláusula OUTPUT para ver exactamente qué filas cambian
                    (OUTPUT ... INTO una variable de tabla cuando la tabla
                    tiene triggers: el motor no admite OUTPUT directo, error 334);
                 3. verificación de @@ROWCOUNT contra lo esperado;
                 4. confirmación explícita: por defecto se hace ROLLBACK.
   Uso       : ejecutar completo en SSMS conectado a AerolineaDB. Para que los
               cambios se confirmen, cambie el 0 por 1 en la primera
               instrucción (contexto de sesión 'confirmar_dml').
   NO forma parte del despliegue base (despliegue.py no lo ejecuta).
   Depende de: 02-10 y datos cargados.
   Reinicio  : con confirmación 0 no modifica nada; con 1, los ejemplos
               verifican existencia antes de insertar.
   ============================================================================= */
SET NOCOUNT ON;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script.', 16, 1);
    SET NOEXEC ON;
END
GO
-- 0 = solo simular (ROLLBACK)   1 = confirmar (COMMIT)
EXEC sys.sp_set_session_context @key = N'confirmar_dml', @value = 0;
GO

/* -----------------------------------------------------------------------------
   E1 · INSERT: nueva promoción de temporada.
   Regla: el código es único (uq_descuento_codigo) y el porcentaje es mayor
   que 0 y no supera 100 (ck_descuento_porcentaje). La promoción se limita a
   la cabina económica y exige 14 días de anticipación.
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
DECLARE @confirmar BIT = CAST(SESSION_CONTEXT(N'confirmar_dml') AS BIT);
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM ven.descuento WHERE codigo_descuento = 'NAVIDAD18')
        INSERT ven.descuento (codigo_descuento, descripcion, porcentaje, vigente_desde, vigente_hasta,
                              solo_clientes_registrados, codigo_cabina, dias_anticipacion_min, activo)
        OUTPUT N'E1 insertado' AS accion, inserted.id_descuento, inserted.codigo_descuento, inserted.porcentaje,
               inserted.vigente_desde, inserted.vigente_hasta
        VALUES ('NAVIDAD18', N'Navidad: 18 % en económica con 14 días de anticipación', 18.00,
                '20261120', '20261215', 0, 'ECO', 14, 1);
    IF @@ROWCOUNT NOT IN (0, 1) THROW 50900, N'E1: número de filas inesperado.', 1;
    IF @confirmar = 1 COMMIT; ELSE ROLLBACK;
    PRINT CONCAT(N'E1 ', IIF(@confirmar = 1, N'confirmado', N'revertido (simulación)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E1 rechazado [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO

/* -----------------------------------------------------------------------------
   E2 · UPDATE + INSERT: nueva versión de una tarifa (precio histórico).
   No se edita el precio de una tarifa usada (RN-20): se cierra su vigencia y se
   crea otra versión. Los tiquetes ya vendidos conservan su precio.
   El orden importa: primero cerrar y después insertar, o el trigger detecta
   vigencias solapadas (RN-18, error 50002).
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
DECLARE @confirmar BIT = CAST(SESSION_CONTEXT(N'confirmar_dml') AS BIT);
DECLARE @origen CHAR(3) = 'JFK', @destino CHAR(3) = 'LAX', @cabina CHAR(3) = 'ECO',
        @nueva_desde DATE = '20261201', @factor DECIMAL(5,4) = 1.0500;
DECLARE @id_tarifa INT, @precio DECIMAL(10,2), @id_ruta INT;
-- ven.tarifa tiene trigger: OUTPUT exige INTO (error 334 en caso contrario).
DECLARE @cambios TABLE (accion NVARCHAR(30), id_tarifa INT, precio_base_usd DECIMAL(10,2), vigente_desde DATE,
                        hasta_antes DATE NULL, hasta_despues DATE NULL);
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT @id_tarifa = t.id_tarifa, @precio = t.precio_base_usd, @id_ruta = t.id_ruta
    FROM ven.tarifa AS t WITH (UPDLOCK, HOLDLOCK)
    JOIN ops.ruta AS r ON r.id_ruta = t.id_ruta
    JOIN ref.aeropuerto AS ao ON ao.id_localizacion = r.id_aeropuerto_origen
    JOIN ref.aeropuerto AS ad ON ad.id_localizacion = r.id_aeropuerto_destino
    WHERE ao.codigo_iata = @origen AND ad.codigo_iata = @destino AND t.codigo_cabina = @cabina
      AND t.vigente_hasta IS NULL;
    IF @id_tarifa IS NULL THROW 50901, N'E2: no hay una tarifa abierta para esa ruta y cabina.', 1;

    UPDATE ven.tarifa
       SET vigente_hasta = DATEADD(DAY, -1, @nueva_desde)
    OUTPUT N'E2 cerrada', deleted.id_tarifa, deleted.precio_base_usd, deleted.vigente_desde,
           deleted.vigente_hasta, inserted.vigente_hasta INTO @cambios
     WHERE id_tarifa = @id_tarifa;
    IF @@ROWCOUNT <> 1 THROW 50902, N'E2: se esperaba cerrar exactamente una tarifa.', 1;

    INSERT ven.tarifa (id_ruta, codigo_cabina, precio_base_usd, vigente_desde, vigente_hasta)
    OUTPUT N'E2 nueva versión', inserted.id_tarifa, inserted.precio_base_usd, inserted.vigente_desde, NULL, inserted.vigente_hasta
    INTO @cambios
    VALUES (@id_ruta, @cabina, ROUND(@precio * @factor, 0) - 0.01, @nueva_desde, NULL);
    SELECT * FROM @cambios;

    IF @confirmar = 1 COMMIT; ELSE ROLLBACK;
    PRINT CONCAT(N'E2 ', IIF(@confirmar = 1, N'confirmado', N'revertido (simulación)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E2 rechazado [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO

/* -----------------------------------------------------------------------------
   E3 · UPDATE prohibido: editar el precio de una tarifa ya usada.
   Se espera el rechazo 50003 (RN-20). Demuestra que la regla la impone la base
   y no depende de la disciplina del usuario.
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE TOP (1) t SET precio_base_usd = precio_base_usd + 10
    FROM ven.tarifa AS t
    WHERE EXISTS (SELECT 1 FROM ven.tiquete AS q WHERE q.id_tarifa = t.id_tarifa);
    ROLLBACK;
    PRINT N'E3 INESPERADO: la base aceptó el cambio (se revirtió igualmente).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E3 rechazado como se esperaba [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO

/* -----------------------------------------------------------------------------
   E4 · UPDATE con condición sobre otra tabla: desactivar descuentos cuya
   vigencia terminó antes de la fecha de corte de los datos. «activo» no es una
   condición comercial (RN-21), por eso se permite aunque el descuento se usara.
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
DECLARE @confirmar BIT = CAST(SESSION_CONTEXT(N'confirmar_dml') AS BIT);
DECLARE @corte DATE = (SELECT CAST(CAST(valor AS DATETIME2(0)) AS DATE) FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS');
DECLARE @desactivados TABLE (id_descuento INT, codigo_descuento VARCHAR(20), vigente_hasta DATE);
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE d SET activo = 0
    OUTPUT inserted.id_descuento, inserted.codigo_descuento, inserted.vigente_hasta INTO @desactivados
    FROM ven.descuento AS d
    WHERE d.activo = 1 AND d.vigente_hasta < @corte;
    PRINT CONCAT(N'E4 filas afectadas: ', @@ROWCOUNT);
    SELECT N'E4 desactivado' AS accion, x.codigo_descuento, x.vigente_hasta,
           (SELECT COUNT(*) FROM ven.tiquete AS t WHERE t.id_descuento = x.id_descuento) AS tiquetes_con_descuento
    FROM @desactivados AS x;
    IF @confirmar = 1 COMMIT; ELSE ROLLBACK;
    PRINT CONCAT(N'E4 ', IIF(@confirmar = 1, N'confirmado', N'revertido (simulación)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E4 rechazado [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO

/* -----------------------------------------------------------------------------
   E5 · DELETE seguro: eliminar un descuento SOLO si nunca se usó.
   La condición NOT EXISTS protege el histórico; además la FK de tiquete
   rechazaría el borrado (error 547) si se omitiera.
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
DECLARE @confirmar BIT = CAST(SESSION_CONTEXT(N'confirmar_dml') AS BIT);
DECLARE @codigo VARCHAR(20) = 'INVIERNO25';
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE d
    OUTPUT N'E5 eliminado' AS accion, deleted.id_descuento, deleted.codigo_descuento, deleted.porcentaje
    FROM ven.descuento AS d
    WHERE d.codigo_descuento = @codigo
      AND NOT EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_descuento = d.id_descuento);
    IF @@ROWCOUNT = 0
        PRINT CONCAT(N'E5: ', @codigo, N' no existe o ya tiene tiquetes; no se elimina.');
    IF @confirmar = 1 COMMIT; ELSE ROLLBACK;
    PRINT CONCAT(N'E5 ', IIF(@confirmar = 1, N'confirmado', N'revertido (simulación)'));
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E5 rechazado [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO

/* -----------------------------------------------------------------------------
   E6 · DELETE prohibido: los pagos no se eliminan (RN-29, error 50059).
   Un pago erróneo se ANULA o se compensa con un reembolso; nunca se borra.
   ----------------------------------------------------------------------------- */
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE TOP (1) FROM ven.pago;
    ROLLBACK;
    PRINT N'E6 INESPERADO: la base aceptó el borrado (se revirtió igualmente).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    PRINT CONCAT(N'E6 rechazado como se esperaba [', ERROR_NUMBER(), N'] ', ERROR_MESSAGE());
END CATCH;
GO
EXEC sys.sp_set_session_context @key = N'confirmar_dml', @value = NULL;
GO
SET NOEXEC OFF;
GO
