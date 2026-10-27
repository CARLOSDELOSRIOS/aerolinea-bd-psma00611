/* =============================================================================
   05_funciones_y_triggers.sql
   Propósito : funciones auxiliares y triggers que garantizan reglas que no se
               pueden expresar con restricciones declarativas (reglas entre
               tablas, transiciones de estado, solapes temporales e inventario).
   Principios:
     - Una restricción declarativa se prefiere siempre que sea suficiente.
     - Los triggers son set-based: validan todas las filas de inserted/deleted,
       por lo que funcionan igual con una fila (procedimiento) que con una carga
       masiva.
     - Ante una violación, THROW con número 500xx (catálogo ref.mensaje_error);
       el trigger se ejecuta dentro de la transacción de la sentencia y el error
       la revierte por completo.
     - Para impedir que dos transacciones concurrentes validen a la vez el mismo
       recurso (anomalía de escritura sesgada / write skew) se bloquea primero la
       fila padre con UPDLOCK (tiquete, pago, avión o empleado); en catálogos
       pequeños se usa UPDLOCK + HOLDLOCK (bloqueo de rango).
     - Las sentencias que leen inserted/deleted llevan OPTION (RECOMPILE): un
       mismo trigger procesa 1 fila (procedimiento) o cientos de miles (carga);
       sin recompilar, el plan compilado para un caso se reutiliza en el otro
       (p. ej., bucles anidados sobre 280 000 x 280 000 filas). El costo es
       una compilación de pocos milisegundos por sentencia. Además se desactiva
       el "objetivo de filas" de TOP (1): sin ese ajuste el optimizador supone
       que la primera coincidencia aparece enseguida y elige bucles anidados.
   Depende de: 04_indices.sql
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

/* ============================================================ FUNCIONES ==== */

/* Calendario entre dos fechas con día de la semana ISO (1 = lunes).
   No depende de SET DATEFIRST: el 1-ene-1900 fue lunes. */
CREATE OR ALTER FUNCTION ref.fn_calendario (@desde DATE, @hasta DATE)
RETURNS TABLE
AS
RETURN
WITH d0 (n) AS (SELECT 0 FROM (VALUES (0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) AS v (n)),
     d1 (n) AS (SELECT 0 FROM d0 AS a CROSS JOIN d0 AS b),          -- 100
     d2 (n) AS (SELECT 0 FROM d1 AS a CROSS JOIN d1 AS b),          -- 10 000
     num (i) AS (
        SELECT TOP (CASE WHEN @hasta >= @desde THEN DATEDIFF(DAY, @desde, @hasta) + 1 ELSE 0 END)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
        FROM d2)
SELECT DATEADD(DAY, i, @desde) AS fecha,
       CAST(DATEDIFF(DAY, CAST('19000101' AS DATE), DATEADD(DAY, i, @desde)) % 7 + 1 AS TINYINT) AS dia_semana_iso
FROM num;
GO

/* Política de reembolso aplicable a un tiquete (RN-36).
   Prioridad: 1) motivo con reembolso total (vuelo cancelado, vencimiento);
              2) regla de 24 h (cancelación voluntaria ≤ 24 h después de la venta,
                 si la venta ocurrió ≥ 7 días antes de la salida);
              3) política por cabina según las horas que faltan para la salida. */
CREATE OR ALTER FUNCTION ven.fn_politica_reembolso (
    @id_tiquete INT, @codigo_motivo VARCHAR(15), @fecha_cancelacion_utc DATETIME2(0))
RETURNS TABLE
AS
RETURN
WITH base AS (
    SELECT t.id_tiquete, t.codigo_cabina, t.creado_utc AS fecha_venta_utc,
           CONVERT(DATETIME2(0), SWITCHOFFSET(v.salida_programada, '+00:00')) AS salida_utc
    FROM ven.tiquete AS t
    JOIN ops.vuelo   AS v ON v.id_vuelo = t.id_vuelo
    WHERE t.id_tiquete = @id_tiquete
),
opciones AS (
    SELECT 1 AS prioridad, CAST(100.00 AS DECIMAL(5,2)) AS porcentaje, CAST('REEMBOLSO_TOTAL' AS VARCHAR(20)) AS regla
    FROM ref.motivo_cancelacion AS m
    WHERE m.codigo_motivo = @codigo_motivo AND m.reembolso_total = 1
    UNION ALL
    SELECT 2, CAST(100.00 AS DECIMAL(5,2)), CAST('REGLA_24H' AS VARCHAR(20))
    FROM base AS b
    WHERE @codigo_motivo = 'VOLUNTARIA'
      AND @fecha_cancelacion_utc <= DATEADD(HOUR, 24, b.fecha_venta_utc)
      AND DATEDIFF(MINUTE, b.fecha_venta_utc, b.salida_utc) >= 7 * 24 * 60
    UNION ALL
    SELECT 3, p.porcentaje_reembolso, CAST('POLITICA_CABINA' AS VARCHAR(20))
    FROM base AS b
    CROSS APPLY (
        SELECT TOP (1) pc.porcentaje_reembolso
        FROM ven.politica_cancelacion AS pc
        WHERE pc.codigo_cabina = b.codigo_cabina
          AND pc.horas_antes_min * 60 <= DATEDIFF(MINUTE, @fecha_cancelacion_utc, b.salida_utc)
        ORDER BY pc.horas_antes_min DESC) AS p
)
SELECT TOP (1)
       o.porcentaje AS porcentaje_reembolso,
       o.regla      AS regla_aplicada,
       (SELECT CAST(DATEDIFF(MINUTE, @fecha_cancelacion_utc, b.salida_utc) / 60.0 AS DECIMAL(9,2)) FROM base AS b) AS horas_antes_salida
FROM opciones AS o
ORDER BY o.prioridad;
GO

/* ====================================================== TRIGGERS: ref/ops === */

/* RN-03: un número de vuelo no puede tener dos programaciones con vigencias solapadas. */
CREATE OR ALTER TRIGGER ops.trg_programacion_reglas ON ops.programacion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048);

    SELECT TOP (1) @msg = CONCAT(N'RN-03: el vuelo ', i.numero_vuelo, N' ya tiene la programación ', p.id_programacion,
                                 N' con una vigencia que se solapa.')
    FROM inserted AS i
    JOIN ops.programacion AS p WITH (UPDLOCK, HOLDLOCK)
      ON p.numero_vuelo = i.numero_vuelo AND p.id_programacion <> i.id_programacion
    WHERE p.vigente_desde <= ISNULL(i.vigente_hasta, '99991231')
      AND i.vigente_desde <= ISNULL(p.vigente_hasta, '99991231')
      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50001, @msg, 1;
END;
GO

/* Reglas de vuelo: RN-06 desfases, RN-08 transiciones, RN-09 y RN-10 avión,
   SUP-03 cambio de avión con ventas, RN-35 tripulación completa. */
CREATE OR ALTER TRIGGER ops.trg_vuelo_reglas ON ops.vuelo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048), @bloqueados INT;
    DECLARE @es_insercion BIT = CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 0 ELSE 1 END;
    DECLARE @rotacion INT = ISNULL((SELECT CAST(valor AS INT) FROM ref.parametro WHERE clave = 'MIN_ROTACION_AVION'), 40);
    DECLARE @asientos_por_tcp DECIMAL(5,1) = ISNULL((SELECT CAST(valor AS INT) FROM ref.parametro WHERE clave = 'ASIENTOS_POR_TRIPULANTE_CABINA'), 50);

    -- Inmutabilidad del origen del vuelo.
    IF @es_insercion = 0
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'La programación de origen del vuelo ', i.id_vuelo, N' no puede cambiar.')
        FROM inserted AS i JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
        WHERE i.id_programacion <> d.id_programacion
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50024, @msg, 1;
    END;

    -- RN-08: estado inicial y transiciones.
    IF @es_insercion = 1
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-08: un vuelo nuevo no puede crearse en estado ', i.codigo_estado, N'.')
        FROM inserted AS i JOIN ref.estado_vuelo AS e ON e.codigo_estado = i.codigo_estado
        WHERE e.es_estado_inicial = 0
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50021, @msg, 1;

        -- El vuelo debe corresponder a la programación: fecha dentro de la vigencia y día operado.
        SELECT TOP (1) @msg = CONCAT(N'El vuelo de la fecha ', CONVERT(CHAR(10), i.fecha_salida_local, 23),
                                     N' no corresponde a los días ni a la vigencia de la programación ', i.id_programacion, N'.')
        FROM inserted AS i
        JOIN ops.programacion AS p ON p.id_programacion = i.id_programacion
        WHERE p.activa = 0
           OR i.fecha_salida_local < p.vigente_desde
           OR i.fecha_salida_local > ISNULL(p.vigente_hasta, '99991231')
           OR NOT EXISTS (SELECT 1 FROM ops.programacion_dia AS pd
                          WHERE pd.id_programacion = p.id_programacion
                            AND pd.dia_semana = DATEDIFF(DAY, CAST('19000101' AS DATE), i.fecha_salida_local) % 7 + 1)
                            OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50022, @msg, 1;
    END
    ELSE
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-08: transición de vuelo no válida (vuelo ', i.id_vuelo, N'): ',
                                     d.codigo_estado, N' -> ', i.codigo_estado, N'.')
        FROM inserted AS i JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
        WHERE i.codigo_estado <> d.codigo_estado
          AND NOT EXISTS (SELECT 1 FROM ref.transicion_vuelo AS t
                          WHERE t.estado_origen = d.codigo_estado AND t.estado_destino = i.codigo_estado)
                          OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50023, @msg, 1;
    END;

    -- RN-06: los desfases deben coincidir con la zona horaria del aeropuerto (incluye horario de verano).
    SELECT TOP (1) @msg = CONCAT(N'RN-06: el vuelo ', i.id_vuelo, N' tiene un desfase horario distinto al de la zona del aeropuerto.')
    FROM inserted AS i
    JOIN ops.programacion AS p  ON p.id_programacion = i.id_programacion
    JOIN ops.ruta         AS r  ON r.id_ruta = p.id_ruta
    JOIN ref.localizacion AS lo ON lo.id_localizacion = r.id_aeropuerto_origen
    JOIN ref.localizacion AS ld ON ld.id_localizacion = r.id_aeropuerto_destino
    WHERE DATEPART(TZOFFSET, i.salida_programada)  <> DATEPART(TZOFFSET, i.salida_programada  AT TIME ZONE lo.zona_horaria)
       OR DATEPART(TZOFFSET, i.llegada_programada) <> DATEPART(TZOFFSET, i.llegada_programada AT TIME ZONE ld.zona_horaria)
       OR (i.salida_estimada IS NOT NULL AND DATEPART(TZOFFSET, i.salida_estimada) <> DATEPART(TZOFFSET, i.salida_estimada AT TIME ZONE lo.zona_horaria))
       OR (i.salida_real     IS NOT NULL AND DATEPART(TZOFFSET, i.salida_real)     <> DATEPART(TZOFFSET, i.salida_real     AT TIME ZONE lo.zona_horaria))
       OR (i.llegada_real    IS NOT NULL AND DATEPART(TZOFFSET, i.llegada_real)    <> DATEPART(TZOFFSET, i.llegada_real    AT TIME ZONE ld.zona_horaria))
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50026, @msg, 1;

    -- Filas en las que cambió el avión o el horario (solo en ellas se revisa el avión).
    DECLARE @cambio_avion TABLE (id_vuelo INT PRIMARY KEY);
    INSERT @cambio_avion (id_vuelo)
    SELECT i.id_vuelo
    FROM inserted AS i LEFT JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
    WHERE i.id_avion IS NOT NULL
      AND (d.id_vuelo IS NULL
           OR ISNULL(d.id_avion, -1) <> i.id_avion
           OR d.salida_programada <> i.salida_programada
           OR d.llegada_programada <> i.llegada_programada
           OR (d.codigo_estado = 'CANCELADO' AND i.codigo_estado <> 'CANCELADO'))
           OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));

    IF EXISTS (SELECT 1 FROM @cambio_avion)
    BEGIN
        -- RN-10: solo aviones activos.
        SELECT TOP (1) @msg = CONCAT(N'RN-10: el avión ', a.matricula, N' está en estado ', a.estado_operativo, N' y no puede asignarse.')
        FROM inserted AS i
        JOIN @cambio_avion AS c ON c.id_vuelo = i.id_vuelo
        JOIN ops.avion AS a ON a.id_avion = i.id_avion
        LEFT JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
        WHERE a.estado_operativo <> 'ACTIVO' AND ISNULL(d.id_avion, -1) <> i.id_avion
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50027, @msg, 1;

        -- RN-09: sin solapes del mismo avión, considerando la rotación mínima en tierra.
        -- Se bloquea la fila del avión (serializa asignaciones concurrentes del mismo avión) y se ordena
        -- su agenda: si dos vuelos se solapan, también se solapan dos vuelos consecutivos (LAG).
        SELECT @bloqueados = COUNT(*) FROM ops.avion WITH (UPDLOCK, ROWLOCK)
        WHERE id_avion IN (SELECT i.id_avion FROM inserted AS i JOIN @cambio_avion AS c ON c.id_vuelo = i.id_vuelo)
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        WITH agenda AS (
            SELECT v.id_avion, v.id_vuelo, v.salida_programada,
                   LAG(v.llegada_programada) OVER (PARTITION BY v.id_avion ORDER BY v.salida_programada, v.id_vuelo) AS llegada_anterior,
                   LAG(v.id_vuelo)           OVER (PARTITION BY v.id_avion ORDER BY v.salida_programada, v.id_vuelo) AS vuelo_anterior
            FROM ops.vuelo AS v
            WHERE v.codigo_estado <> 'CANCELADO'
              AND v.id_avion IN (SELECT i.id_avion FROM inserted AS i JOIN @cambio_avion AS c ON c.id_vuelo = i.id_vuelo)
        )
        SELECT TOP (1) @msg = CONCAT(N'RN-09: el avión ', a.matricula, N' ya está asignado al vuelo ', g.vuelo_anterior,
                                     N', que se solapa con el vuelo ', g.id_vuelo, N' (rotación mínima ', @rotacion, N' min).')
        FROM agenda AS g
        JOIN ops.avion AS a ON a.id_avion = g.id_avion
        WHERE g.salida_programada < DATEADD(MINUTE, @rotacion, g.llegada_anterior)
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50028, @msg, 1;
    END;

    -- SUP-03: con tiquetes activos solo se admite un avión de la misma configuración.
    IF @es_insercion = 0
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'SUP-03: el vuelo ', i.id_vuelo, N' tiene tiquetes activos; el nuevo avión debe tener la misma configuración de asientos.')
        FROM inserted AS i
        JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
        JOIN ops.avion AS anterior ON anterior.id_avion = d.id_avion
        LEFT JOIN ops.avion AS nuevo ON nuevo.id_avion = i.id_avion
        WHERE ISNULL(i.id_avion, -1) <> d.id_avion
          AND (nuevo.id_avion IS NULL OR nuevo.id_configuracion <> anterior.id_configuracion)
          AND EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_vuelo = i.id_vuelo AND t.codigo_estado <> 'CANCELADO')
          OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50025, @msg, 1;

        -- RN-35: para despegar se exige avión y tripulación completa.
        SELECT TOP (1) @msg = CONCAT(N'RN-35: el vuelo ', i.id_vuelo, N' no tiene tripulación completa (capitán ', ISNULL(tr.capitanes, 0),
                                     N', primer oficial ', ISNULL(tr.primeros_oficiales, 0), N', cabina ', ISNULL(tr.cabina, 0),
                                     N' de ', CEILING(ISNULL(cap.asientos, 0) / @asientos_por_tcp), N' requeridos).')
        FROM inserted AS i
        JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
        OUTER APPLY (SELECT SUM(CASE WHEN a.rol_vuelo = 'CAPITAN' THEN 1 ELSE 0 END) AS capitanes,
                            SUM(CASE WHEN a.rol_vuelo = 'PRIMER_OFICIAL' THEN 1 ELSE 0 END) AS primeros_oficiales,
                            SUM(CASE WHEN a.rol_vuelo IN ('JEFE_CABINA', 'AUXILIAR_VUELO') THEN 1 ELSE 0 END) AS cabina
                     FROM ops.asignacion_tripulacion AS a WHERE a.id_vuelo = i.id_vuelo) AS tr
        OUTER APPLY (SELECT SUM(vc.capacidad) AS asientos FROM ops.vuelo_cabina AS vc WHERE vc.id_vuelo = i.id_vuelo) AS cap
        WHERE i.codigo_estado = 'EN_VUELO' AND d.codigo_estado <> 'EN_VUELO'
          AND (i.id_avion IS NULL
               OR ISNULL(tr.capitanes, 0) <> 1
               OR ISNULL(tr.primeros_oficiales, 0) <> 1
               OR ISNULL(tr.cabina, 0) < CEILING(ISNULL(cap.asientos, 0) / @asientos_por_tcp))
               OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50029, @msg, 1;
    END;

    -- Auditoría de cambios de estado.
    INSERT aud.cambio_estado (entidad, id_entidad, estado_anterior, estado_nuevo)
    SELECT 'VUELO', i.id_vuelo, d.codigo_estado, i.codigo_estado
    FROM inserted AS i LEFT JOIN deleted AS d ON d.id_vuelo = i.id_vuelo
    WHERE d.id_vuelo IS NULL OR d.codigo_estado <> i.codigo_estado
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
END;
GO

/* RN-33: rol compatible con el cargo, empleado vigente, vuelo asignable y sin solapes. */
CREATE OR ALTER TRIGGER ops.trg_asignacion_tripulacion_reglas ON ops.asignacion_tripulacion
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048), @bloqueados INT;
    DECLARE @descanso INT = ISNULL((SELECT CAST(valor AS INT) FROM ref.parametro WHERE clave = 'MIN_DESCANSO_TRIPULACION'), 30);

    SELECT TOP (1) @msg = CONCAT(N'RN-33: el empleado ', e.numero_empleado, N' (cargo ', e.codigo_cargo,
                                 N') no puede desempeñar el rol ', i.rol_vuelo, N'.')
    FROM inserted AS i
    JOIN rh.empleado AS e ON e.id_empleado = i.id_empleado
    JOIN rh.cargo    AS c ON c.codigo_cargo = e.codigo_cargo
    -- ISNULL es imprescindible: el personal de tierra tiene categoría NULL y, sin él, NOT(...) daría
    -- NULL (lógica trivalente) y la fila no se seleccionaría, aceptando una asignación inválida.
    WHERE NOT ((i.rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL') AND ISNULL(c.categoria_tripulacion, '') = 'TECNICA')
            OR (i.rol_vuelo IN ('JEFE_CABINA', 'AUXILIAR_VUELO') AND ISNULL(c.categoria_tripulacion, '') = 'CABINA'))
            OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50031, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'RN-33: el empleado ', e.numero_empleado, N' no está vigente el ',
                                 CONVERT(CHAR(10), v.fecha_salida_local, 23), N'.')
    FROM inserted AS i
    JOIN rh.empleado AS e ON e.id_empleado = i.id_empleado
    JOIN ops.vuelo   AS v ON v.id_vuelo = i.id_vuelo
    WHERE e.fecha_contratacion > v.fecha_salida_local
       OR (e.fecha_terminacion IS NOT NULL AND e.fecha_terminacion < v.fecha_salida_local)
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50032, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'RN-33: el vuelo ', v.id_vuelo, N' está en estado ', v.codigo_estado, N' y no admite cambios de tripulación.')
    FROM inserted AS i JOIN ops.vuelo AS v ON v.id_vuelo = i.id_vuelo
    WHERE v.codigo_estado NOT IN ('PROGRAMADO', 'DEMORADO')
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50033, @msg, 1;

    -- Serializa por empleado (bloqueo de la fila padre) y revisa su agenda en orden: un solape implica
    -- un solape entre vuelos consecutivos, que se detecta con LAG en O(n log n).
    SELECT @bloqueados = COUNT(*) FROM rh.empleado WITH (UPDLOCK, ROWLOCK)
    WHERE id_empleado IN (SELECT id_empleado FROM inserted)
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    WITH agenda AS (
        SELECT a.id_empleado, v.id_vuelo, v.salida_programada,
               LAG(v.llegada_programada) OVER (PARTITION BY a.id_empleado ORDER BY v.salida_programada, v.id_vuelo) AS llegada_anterior,
               LAG(v.id_vuelo)           OVER (PARTITION BY a.id_empleado ORDER BY v.salida_programada, v.id_vuelo) AS vuelo_anterior
        FROM ops.asignacion_tripulacion AS a
        JOIN ops.vuelo AS v ON v.id_vuelo = a.id_vuelo AND v.codigo_estado <> 'CANCELADO'
        WHERE a.id_empleado IN (SELECT id_empleado FROM inserted)
    )
    SELECT TOP (1) @msg = CONCAT(N'RN-33: el empleado ', e.numero_empleado, N' ya está asignado al vuelo ', g.vuelo_anterior,
                                 N', que se solapa con el vuelo ', g.id_vuelo, N' (descanso mínimo ', @descanso, N' min).')
    FROM agenda AS g
    JOIN rh.empleado AS e ON e.id_empleado = g.id_empleado
    WHERE g.salida_programada < DATEADD(MINUTE, @descanso, g.llegada_anterior)
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50034, @msg, 1;
END;
GO

/* ========================================================= TRIGGERS: ven ==== */

/* RN-18 y RN-20: tarifas sin solapes y versionadas (una tarifa usada no se edita). */
CREATE OR ALTER TRIGGER ven.trg_tarifa_reglas ON ven.tarifa
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048);

    SELECT TOP (1) @msg = CONCAT(N'RN-18: la tarifa ', i.id_tarifa, N' se solapa con la tarifa ', t.id_tarifa,
                                 N' de la misma ruta y cabina.')
    FROM inserted AS i
    JOIN ven.tarifa AS t WITH (UPDLOCK, HOLDLOCK)
      ON t.id_ruta = i.id_ruta AND t.codigo_cabina = i.codigo_cabina AND t.id_tarifa <> i.id_tarifa
    WHERE t.vigente_desde <= ISNULL(i.vigente_hasta, '99991231')
      AND i.vigente_desde <= ISNULL(t.vigente_hasta, '99991231')
      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50002, @msg, 1;

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-20: la tarifa ', i.id_tarifa, N' ya se usó en tiquetes; no se puede cambiar su ruta, ',
                                     N'cabina, precio ni inicio de vigencia. Cierre su vigencia y cree una nueva versión.')
        FROM inserted AS i JOIN deleted AS d ON d.id_tarifa = i.id_tarifa
        WHERE (i.id_ruta <> d.id_ruta OR i.codigo_cabina <> d.codigo_cabina
               OR i.precio_base_usd <> d.precio_base_usd OR i.vigente_desde <> d.vigente_desde)
          AND EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_tarifa = i.id_tarifa)
          OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50003, @msg, 1;

        SELECT TOP (1) @msg = CONCAT(N'RN-20: la vigencia de la tarifa ', i.id_tarifa, N' no puede terminar antes de ventas ya realizadas con ella.')
        FROM inserted AS i JOIN deleted AS d ON d.id_tarifa = i.id_tarifa
        WHERE ISNULL(i.vigente_hasta, '99991231') < ISNULL(d.vigente_hasta, '99991231')
          AND EXISTS (SELECT 1 FROM ven.tiquete AS t
                      WHERE t.id_tarifa = i.id_tarifa AND CAST(t.creado_utc AS DATE) > i.vigente_hasta)
                      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50004, @msg, 1;
    END;
END;
GO

/* RN-21: un descuento ya aplicado no cambia sus condiciones (se crea un código nuevo). */
CREATE OR ALTER TRIGGER ven.trg_descuento_reglas ON ven.descuento
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @msg NVARCHAR(2048);
    SELECT TOP (1) @msg = CONCAT(N'RN-21: el descuento ', i.codigo_descuento, N' ya se aplicó a tiquetes; ',
                                 N'no se pueden cambiar su código, porcentaje ni condiciones.')
    FROM inserted AS i JOIN deleted AS d ON d.id_descuento = i.id_descuento
    WHERE (i.codigo_descuento <> d.codigo_descuento OR i.porcentaje <> d.porcentaje
           OR ISNULL(i.codigo_cabina, '') <> ISNULL(d.codigo_cabina, '')
           OR ISNULL(i.dias_anticipacion_min, -1) <> ISNULL(d.dias_anticipacion_min, -1)
           OR i.solo_clientes_registrados <> d.solo_clientes_registrados
           OR i.vigente_desde <> d.vigente_desde)
      AND EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_descuento = i.id_descuento)
      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50005, @msg, 1;
END;
GO

/* RN-32: canal y vendedor coherentes; la compra es inmutable. */
CREATE OR ALTER TRIGGER ven.trg_compra_reglas ON ven.compra
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048);

    SELECT TOP (1) @msg = CONCAT(N'Los datos de la compra ', d.codigo_reserva, N' (localizador, comprador, canal, vendedor y fecha) son inmutables.')
    FROM inserted AS i JOIN deleted AS d ON d.id_compra = i.id_compra
    WHERE i.codigo_reserva <> d.codigo_reserva OR i.id_persona_comprador <> d.id_persona_comprador
       OR i.id_localizacion_venta <> d.id_localizacion_venta OR i.fecha_compra_utc <> d.fecha_compra_utc
       OR ISNULL(i.id_empleado_vendedor, -1) <> ISNULL(d.id_empleado_vendedor, -1)
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50010, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'La localización ', l.codigo_localizacion, N' no está habilitada para vender tiquetes.')
    FROM inserted AS i JOIN ref.localizacion AS l ON l.id_localizacion = i.id_localizacion_venta
    WHERE l.vende_tiquetes = 0 OR l.activa = 0
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50011, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'RN-32: la compra ', i.codigo_reserva,
                                 CASE WHEN l.tipo_localizacion = 'WEB' THEN N' es web y no admite vendedor.'
                                      ELSE N' es física y requiere un vendedor.' END)
    FROM inserted AS i JOIN ref.localizacion AS l ON l.id_localizacion = i.id_localizacion_venta
    WHERE (l.tipo_localizacion = 'WEB' AND i.id_empleado_vendedor IS NOT NULL)
       OR (l.tipo_localizacion IN ('AER', 'OFI') AND i.id_empleado_vendedor IS NULL)
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50012, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'RN-32: el vendedor ', e.numero_empleado, N' no estaba vigente en la fecha de la compra.')
    FROM inserted AS i JOIN rh.empleado AS e ON e.id_empleado = i.id_empleado_vendedor
    WHERE e.fecha_contratacion > CAST(i.fecha_compra_utc AS DATE)
       OR (e.fecha_terminacion IS NOT NULL AND e.fecha_terminacion < CAST(i.fecha_compra_utc AS DATE))
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50013, @msg, 1;
END;
GO

/* Reglas del tiquete: RN-08, RN-11, RN-13, RN-17, RN-19, RN-21, RN-24, RN-31, RN-41 e inventario. */
CREATE OR ALTER TRIGGER ven.trg_tiquete_reglas ON ven.tiquete
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048);
    DECLARE @es_insercion BIT = CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 0 ELSE 1 END;

    /* 1. RN-19: inmutabilidad de los datos comerciales (precio histórico). */
    IF @es_insercion = 0
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-19: los datos comerciales del tiquete ', i.numero_tiquete,
                                     N' (vuelo, cabina, pasajero, tarifa, precio y descuento) son inmutables.')
        FROM inserted AS i JOIN deleted AS d ON d.id_tiquete = i.id_tiquete
        WHERE i.numero_tiquete <> d.numero_tiquete OR i.id_compra <> d.id_compra OR i.id_vuelo <> d.id_vuelo
           OR i.codigo_cabina <> d.codigo_cabina OR i.id_persona_pasajero <> d.id_persona_pasajero
           OR i.id_tarifa <> d.id_tarifa OR i.precio_base_usd <> d.precio_base_usd
           OR i.porcentaje_descuento <> d.porcentaje_descuento OR ISNULL(i.id_descuento, -1) <> ISNULL(d.id_descuento, -1)
           OR i.creado_utc <> d.creado_utc
           OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50040, @msg, 1;
    END;

    /* 2. RN-08: estado inicial y transiciones. */
    IF @es_insercion = 1
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-08: un tiquete nuevo debe crearse en estado RESERVADO (se recibió ', i.codigo_estado, N').')
        FROM inserted AS i JOIN ref.estado_tiquete AS e ON e.codigo_estado = i.codigo_estado
        WHERE e.es_estado_inicial = 0
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50041, @msg, 1;
    END
    ELSE
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-08: transición de tiquete no válida (', i.numero_tiquete, N'): ',
                                     d.codigo_estado, N' -> ', i.codigo_estado, N'.')
        FROM inserted AS i JOIN deleted AS d ON d.id_tiquete = i.id_tiquete
        WHERE i.codigo_estado <> d.codigo_estado
          AND NOT EXISTS (SELECT 1 FROM ref.transicion_tiquete AS t
                          WHERE t.estado_origen = d.codigo_estado AND t.estado_destino = i.codigo_estado)
                          OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50042, @msg, 1;
    END;

    /* 3. Validaciones de la venta (solo en la inserción). */
    IF @es_insercion = 1
    BEGIN
        -- RN-31: el vuelo está abierto a la venta y la venta es anterior a la salida.
        SELECT TOP (1) @msg = CONCAT(N'RN-31: el vuelo ', v.id_vuelo, N' (', v.codigo_estado, N') no admite ventas en ',
                                     CONVERT(VARCHAR(19), i.creado_utc, 120), N' UTC.')
        FROM inserted AS i
        JOIN ven.compra AS c ON c.id_compra = i.id_compra
        JOIN ops.vuelo  AS v ON v.id_vuelo = i.id_vuelo
        WHERE v.codigo_estado NOT IN ('PROGRAMADO', 'DEMORADO')
           OR i.creado_utc >= CONVERT(DATETIME2(0), SWITCHOFFSET(v.salida_programada, '+00:00'))
           OR i.creado_utc < c.fecha_compra_utc
           OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50043, @msg, 1;

        -- RN-17: tarifa de la ruta del vuelo, vigente en la fecha de venta, con el mismo precio base.
        SELECT TOP (1) @msg = CONCAT(N'RN-17: la tarifa ', i.id_tarifa, N' no corresponde a la ruta del vuelo, ',
                                     N'no estaba vigente el ', CONVERT(CHAR(10), CAST(i.creado_utc AS DATE), 23),
                                     N' o su precio difiere del precio base del tiquete.')
        FROM inserted AS i
        JOIN ops.vuelo        AS v  ON v.id_vuelo = i.id_vuelo
        JOIN ops.programacion AS p  ON p.id_programacion = v.id_programacion
        JOIN ven.tarifa       AS tf ON tf.id_tarifa = i.id_tarifa
        WHERE tf.id_ruta <> p.id_ruta
           OR CAST(i.creado_utc AS DATE) < tf.vigente_desde
           OR CAST(i.creado_utc AS DATE) > ISNULL(tf.vigente_hasta, '99991231')
           OR tf.precio_base_usd <> i.precio_base_usd
           OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50044, @msg, 1;

        -- RN-21: el descuento es aplicable a esta venta.
        SELECT TOP (1) @msg = CONCAT(N'RN-21: el descuento ', ds.codigo_descuento, N' no es aplicable al tiquete ', i.numero_tiquete,
                                     N' (porcentaje, vigencia, cabina, anticipación o registro del comprador).')
        FROM inserted AS i
        JOIN ven.descuento AS ds ON ds.id_descuento = i.id_descuento
        JOIN ven.compra    AS c  ON c.id_compra = i.id_compra
        JOIN ops.vuelo     AS v  ON v.id_vuelo = i.id_vuelo
        WHERE ds.porcentaje <> i.porcentaje_descuento
           OR ds.activo = 0
           OR CAST(i.creado_utc AS DATE) NOT BETWEEN ds.vigente_desde AND ds.vigente_hasta
           OR (ds.codigo_cabina IS NOT NULL AND ds.codigo_cabina <> i.codigo_cabina)
           OR (ds.dias_anticipacion_min IS NOT NULL
               AND DATEDIFF(DAY, CAST(i.creado_utc AS DATE), v.fecha_salida_local) < ds.dias_anticipacion_min)
           OR (ds.solo_clientes_registrados = 1
               AND NOT EXISTS (SELECT 1 FROM ven.cliente AS cl
                               WHERE cl.id_persona = c.id_persona_comprador
                                 AND cl.fecha_registro_utc <= i.creado_utc
                                 AND cl.estado_cuenta = 'ACTIVA'))
                                 OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50045, @msg, 1;

        -- RN-41: el pasajero tiene los datos exigidos para volar.
        SELECT TOP (1) @msg = CONCAT(N'RN-41: el pasajero ', p.id_persona, N' requiere fecha de nacimiento y género.')
        FROM inserted AS i JOIN ven.persona AS p ON p.id_persona = i.id_persona_pasajero
        WHERE p.fecha_nacimiento IS NULL OR p.genero IS NULL
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50046, @msg, 1;
    END;

    /* 4. RN-24: emitir exige pago total confirmado. */
    SELECT TOP (1) @msg = CONCAT(N'RN-24: el tiquete ', i.numero_tiquete, N' no está pagado (cobrado ',
                                 ISNULL(pg.cobrado, 0), N' de ', i.precio_final_usd, N' USD).')
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.id_tiquete = i.id_tiquete
    OUTER APPLY (SELECT SUM(p.monto_usd) AS cobrado
                 FROM ven.pago AS p JOIN ref.estado_pago AS ep ON ep.codigo_estado = p.codigo_estado
                 WHERE p.id_tiquete = i.id_tiquete AND ep.es_cobro = 1) AS pg
    WHERE i.codigo_estado = 'EMITIDO' AND ISNULL(d.codigo_estado, '') <> 'EMITIDO'
      AND ISNULL(pg.cobrado, 0) < i.precio_final_usd
      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50047, @msg, 1;

    /* 5. Uso y cancelación coherentes con el estado del vuelo. */
    SELECT TOP (1) @msg = CONCAT(N'El tiquete ', i.numero_tiquete, N' no puede pasar a ', i.codigo_estado,
                                 N' con el vuelo en estado ', v.codigo_estado, N'.')
    FROM inserted AS i
    JOIN deleted  AS d ON d.id_tiquete = i.id_tiquete
    JOIN ops.vuelo AS v ON v.id_vuelo = i.id_vuelo
    WHERE i.codigo_estado <> d.codigo_estado
      AND ((i.codigo_estado IN ('USADO', 'NO_PRESENTADO') AND v.codigo_estado NOT IN ('EN_VUELO', 'ATERRIZADO'))
        OR (i.codigo_estado = 'CANCELADO' AND v.codigo_estado NOT IN ('PROGRAMADO', 'DEMORADO', 'CANCELADO'))
        OR (i.codigo_estado = 'CANCELADO' AND i.codigo_motivo_cancelacion <> 'VUELO_CANCELADO'
            AND i.fecha_cancelacion_utc >= CONVERT(DATETIME2(0), SWITCHOFFSET(v.salida_programada, '+00:00'))))
            OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50048, @msg, 1;

    /* 6. RN-13: el asiento existe en la configuración del avión y pertenece a la cabina del tiquete;
          solo se asigna o cambia mientras el tiquete está activo y el vuelo no ha salido. */
    SELECT TOP (1) @msg = CONCAT(N'RN-13: el asiento ', i.codigo_asiento, N' no existe en la cabina ', i.codigo_cabina,
                                 N' del avión asignado al vuelo ', i.id_vuelo, N', o el vuelo ya no admite cambios de asiento.')
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.id_tiquete = i.id_tiquete
    JOIN ops.vuelo AS v ON v.id_vuelo = i.id_vuelo
    LEFT JOIN ops.avion AS a ON a.id_avion = v.id_avion
    WHERE i.codigo_asiento IS NOT NULL
      AND (d.id_tiquete IS NULL OR ISNULL(d.codigo_asiento, '') <> i.codigo_asiento)
      AND (v.codigo_estado NOT IN ('PROGRAMADO', 'DEMORADO')
           OR i.codigo_estado NOT IN ('RESERVADO', 'EMITIDO')
           OR NOT EXISTS (SELECT 1 FROM ops.asiento_configuracion AS s
                          WHERE s.id_configuracion = a.id_configuracion
                            AND s.codigo_asiento = i.codigo_asiento
                            AND s.codigo_cabina = i.codigo_cabina))
                            OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50049, @msg, 1;

    /* 7. RN-11: inventario por vuelo y cabina (sin sobreventa). */
    DECLARE @delta TABLE (id_vuelo INT NOT NULL, codigo_cabina CHAR(3) NOT NULL, cambio INT NOT NULL,
                          PRIMARY KEY (id_vuelo, codigo_cabina));
    INSERT @delta (id_vuelo, codigo_cabina, cambio)
    SELECT x.id_vuelo, x.codigo_cabina, SUM(x.cambio)
    FROM (SELECT i.id_vuelo, i.codigo_cabina, CAST(e.ocupa_inventario AS INT) AS cambio
          FROM inserted AS i JOIN ref.estado_tiquete AS e ON e.codigo_estado = i.codigo_estado
          UNION ALL
          SELECT d.id_vuelo, d.codigo_cabina, -CAST(e.ocupa_inventario AS INT)
          FROM deleted AS d JOIN ref.estado_tiquete AS e ON e.codigo_estado = d.codigo_estado) AS x
    GROUP BY x.id_vuelo, x.codigo_cabina
    HAVING SUM(x.cambio) <> 0
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));

    IF EXISTS (SELECT 1 FROM @delta)
    BEGIN
        -- Bloqueo de actualización sobre la fila de inventario: serializa las ventas concurrentes del mismo vuelo y cabina.
        SELECT TOP (1) @msg = CONCAT(N'RN-11: sin disponibilidad en la cabina ', vc.codigo_cabina, N' del vuelo ', vc.id_vuelo,
                                     N' (capacidad ', vc.capacidad, N', ocupadas ', vc.plazas_ocupadas, N', solicitadas ', d.cambio, N').')
        FROM ops.vuelo_cabina AS vc WITH (UPDLOCK, ROWLOCK)
        JOIN @delta AS d ON d.id_vuelo = vc.id_vuelo AND d.codigo_cabina = vc.codigo_cabina
        WHERE vc.plazas_ocupadas + d.cambio > vc.capacidad
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50020, @msg, 1;

        -- La restricción ck_vuelo_cabina_capacidad es la garantía final aunque la comprobación anterior se omitiera.
        UPDATE vc
           SET plazas_ocupadas = vc.plazas_ocupadas + d.cambio
        FROM ops.vuelo_cabina AS vc
        JOIN @delta AS d ON d.id_vuelo = vc.id_vuelo AND d.codigo_cabina = vc.codigo_cabina
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    END;

    /* 8. Auditoría de estados. */
    INSERT aud.cambio_estado (entidad, id_entidad, estado_anterior, estado_nuevo)
    SELECT 'TIQUETE', i.id_tiquete, d.codigo_estado, i.codigo_estado
    FROM inserted AS i LEFT JOIN deleted AS d ON d.id_tiquete = i.id_tiquete
    WHERE d.id_tiquete IS NULL OR d.codigo_estado <> i.codigo_estado
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
END;
GO

/* Reglas del pago: RN-08, RN-23, RN-25, inmutabilidad y pagos solo sobre reservas. */
CREATE OR ALTER TRIGGER ven.trg_pago_reglas ON ven.pago
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048), @bloqueados INT;
    DECLARE @es_insercion BIT = CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 0 ELSE 1 END;

    -- Serializa por tiquete: bloquea primero las filas padre (evita doble cobro concurrente).
    SELECT @bloqueados = COUNT(*)
    FROM ven.tiquete AS t WITH (UPDLOCK, ROWLOCK)
    WHERE t.id_tiquete IN (SELECT id_tiquete FROM inserted)
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));

    IF @es_insercion = 0
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'El pago ', i.id_pago, N' solo puede cambiar de estado; su tiquete, método, monto y fecha son inmutables.')
        FROM inserted AS i JOIN deleted AS d ON d.id_pago = i.id_pago
        WHERE i.id_tiquete <> d.id_tiquete OR i.codigo_metodo <> d.codigo_metodo OR i.monto_usd <> d.monto_usd
           OR i.id_localizacion_cobro <> d.id_localizacion_cobro OR i.fecha_creacion_utc <> d.fecha_creacion_utc
           OR ISNULL(i.ultimos4_tarjeta, '') <> ISNULL(d.ultimos4_tarjeta, '')
           OR ISNULL(i.marca_tarjeta, '') <> ISNULL(d.marca_tarjeta, '')
           OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50050, @msg, 1;

        SELECT TOP (1) @msg = CONCAT(N'RN-08: transición de pago no válida (pago ', i.id_pago, N'): ',
                                     d.codigo_estado, N' -> ', i.codigo_estado, N'.')
        FROM inserted AS i JOIN deleted AS d ON d.id_pago = i.id_pago
        WHERE i.codigo_estado <> d.codigo_estado
          AND NOT EXISTS (SELECT 1 FROM ref.transicion_pago AS t
                          WHERE t.estado_origen = d.codigo_estado AND t.estado_destino = i.codigo_estado)
                          OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50051, @msg, 1;
    END
    ELSE
    BEGIN
        SELECT TOP (1) @msg = CONCAT(N'RN-08: un pago no puede crearse en estado ', i.codigo_estado, N'.')
        FROM inserted AS i JOIN ref.estado_pago AS e ON e.codigo_estado = i.codigo_estado
        WHERE e.es_estado_inicial = 0
        OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
        IF @msg IS NOT NULL THROW 50052, @msg, 1;
    END;

    -- Solo se registran o confirman pagos de tiquetes en reserva.
    SELECT TOP (1) @msg = CONCAT(N'El tiquete ', t.numero_tiquete, N' está en estado ', t.codigo_estado,
                                 N'; solo se registran o confirman pagos de tiquetes RESERVADOS.')
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.id_pago = i.id_pago
    JOIN ven.tiquete AS t ON t.id_tiquete = i.id_tiquete
    WHERE t.codigo_estado <> 'RESERVADO'
      AND (d.id_pago IS NULL OR (i.codigo_estado = 'CONFIRMADO' AND d.codigo_estado <> 'CONFIRMADO'))
      OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50053, @msg, 1;

    -- RN-23: los cobros confirmados nunca superan el precio final.
    SELECT TOP (1) @msg = CONCAT(N'RN-23: los pagos confirmados del tiquete ', t.numero_tiquete, N' (', s.cobrado,
                                 N' USD) superarían su precio final (', t.precio_final_usd, N' USD).')
    FROM (SELECT DISTINCT id_tiquete FROM inserted) AS i
    JOIN ven.tiquete AS t ON t.id_tiquete = i.id_tiquete
    CROSS APPLY (SELECT SUM(p.monto_usd) AS cobrado
                 FROM ven.pago AS p JOIN ref.estado_pago AS ep ON ep.codigo_estado = p.codigo_estado
                 WHERE p.id_tiquete = i.id_tiquete AND ep.es_cobro = 1) AS s
    WHERE s.cobrado > t.precio_final_usd
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50054, @msg, 1;

    -- RN-25: método permitido en el tipo de localización (p. ej., efectivo solo en puntos físicos).
    SELECT TOP (1) @msg = CONCAT(N'RN-25: el método ', m.codigo_metodo, N' no está permitido en la localización ', l.codigo_localizacion, N'.')
    FROM inserted AS i
    JOIN ref.metodo_pago  AS m ON m.codigo_metodo = i.codigo_metodo
    JOIN ref.localizacion AS l ON l.id_localizacion = i.id_localizacion_cobro
    WHERE l.vende_tiquetes = 0
       OR (l.tipo_localizacion = 'WEB' AND m.permite_web = 0)
       OR (l.tipo_localizacion <> 'WEB' AND m.permite_fisico = 0)
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50055, @msg, 1;

    -- Coherencia temporal: el pago no es anterior a la venta del tiquete.
    SELECT TOP (1) @msg = CONCAT(N'El pago ', i.id_pago, N' es anterior a la venta del tiquete ', t.numero_tiquete, N'.')
    FROM inserted AS i JOIN ven.tiquete AS t ON t.id_tiquete = i.id_tiquete
    WHERE i.fecha_creacion_utc < t.creado_utc
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50056, @msg, 1;

    INSERT aud.cambio_estado (entidad, id_entidad, estado_anterior, estado_nuevo)
    SELECT 'PAGO', i.id_pago, d.codigo_estado, i.codigo_estado
    FROM inserted AS i LEFT JOIN deleted AS d ON d.id_pago = i.id_pago
    WHERE d.id_pago IS NULL OR d.codigo_estado <> i.codigo_estado
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
END;
GO

/* RN-28: reembolsos solo sobre pagos confirmados de tiquetes cancelados, sin exceder el pago. */
CREATE OR ALTER TRIGGER ven.trg_reembolso_reglas ON ven.reembolso
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @msg NVARCHAR(2048), @bloqueados INT;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50060, N'RN-29: los reembolsos son inmutables; registre un movimiento nuevo si fuera necesario.', 1;

    SELECT @bloqueados = COUNT(*)
    FROM ven.pago AS p WITH (UPDLOCK, ROWLOCK)
    WHERE p.id_pago IN (SELECT id_pago FROM inserted)
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));

    SELECT TOP (1) @msg = CONCAT(N'RN-28: el pago ', p.id_pago, N' (', p.codigo_estado, N') del tiquete ', t.numero_tiquete,
                                 N' (', t.codigo_estado, N') no admite reembolsos.')
    FROM inserted AS i
    JOIN ven.pago    AS p ON p.id_pago = i.id_pago
    JOIN ven.tiquete AS t ON t.id_tiquete = p.id_tiquete
    WHERE p.codigo_estado <> 'CONFIRMADO' OR t.codigo_estado <> 'CANCELADO'
       OR i.codigo_motivo <> t.codigo_motivo_cancelacion
       OR i.fecha_reembolso_utc < t.fecha_cancelacion_utc
       OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50061, @msg, 1;

    SELECT TOP (1) @msg = CONCAT(N'RN-28: los reembolsos del pago ', p.id_pago, N' (', s.reembolsado,
                                 N' USD) superan el monto pagado (', p.monto_usd, N' USD).')
    FROM (SELECT DISTINCT id_pago FROM inserted) AS i
    JOIN ven.pago AS p ON p.id_pago = i.id_pago
    CROSS APPLY (SELECT SUM(r.monto_usd) AS reembolsado FROM ven.reembolso AS r WHERE r.id_pago = i.id_pago) AS s
    WHERE s.reembolsado > p.monto_usd
    OPTION (RECOMPILE, USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'));
    IF @msg IS NOT NULL THROW 50062, @msg, 1;
END;
GO

/* RN-29: los registros financieros no se eliminan (se cancelan o se compensan). */
CREATE OR ALTER TRIGGER ven.trg_tiquete_sin_borrado ON ven.tiquete
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50039, N'RN-29: los tiquetes no se eliminan; use ven.usp_cancelar_tiquete.', 1;
END;
GO
CREATE OR ALTER TRIGGER ven.trg_pago_sin_borrado ON ven.pago
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50059, N'RN-29: los pagos no se eliminan; un pago pendiente se anula y uno confirmado se reembolsa.', 1;
END;
GO
CREATE OR ALTER TRIGGER ven.trg_reembolso_sin_borrado ON ven.reembolso
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50069, N'RN-29: los reembolsos no se eliminan.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '05_funciones_y_triggers')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('05_funciones_y_triggers', N'Funciones y triggers de reglas de negocio');
GO
SET NOEXEC OFF;
GO
