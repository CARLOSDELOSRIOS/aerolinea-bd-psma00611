/* =============================================================================
   04_indices.sql
   Propósito : índices no agrupados de rendimiento. Los índices que implementan
               reglas (únicos filtrados) están en 03.
   Criterio  : se indexan (a) las FK de tablas de alto volumen usadas en JOIN,
               (b) los predicados de las reglas de los triggers y
               (c) los filtros temporales de las consultas analíticas.
               Las tablas de catálogo pequeñas no se indexan más allá de su PK.
   Depende de: 03_claves_y_restricciones.sql
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

-- ops.vuelo ----------------------------------------------------------------
-- RN-09 (solape de avión) y utilización de flota: búsqueda por avión en orden temporal.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_vuelo_avion_salida' AND object_id = OBJECT_ID(N'ops.vuelo'))
    CREATE NONCLUSTERED INDEX ix_vuelo_avion_salida ON ops.vuelo (id_avion, salida_programada)
        INCLUDE (llegada_programada, codigo_estado);
-- Filtros por fecha operativa (consultas Q01, Q11, Q15).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_vuelo_fecha' AND object_id = OBJECT_ID(N'ops.vuelo'))
    CREATE NONCLUSTERED INDEX ix_vuelo_fecha ON ops.vuelo (fecha_salida_local)
        INCLUDE (id_programacion, codigo_estado, id_avion);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_programacion_ruta' AND object_id = OBJECT_ID(N'ops.programacion'))
    CREATE NONCLUSTERED INDEX ix_programacion_ruta ON ops.programacion (id_ruta);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ruta_destino' AND object_id = OBJECT_ID(N'ops.ruta'))
    CREATE NONCLUSTERED INDEX ix_ruta_destino ON ops.ruta (id_aeropuerto_destino);
-- RN-33 (solape de tripulante): búsqueda de vuelos por empleado.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_asignacion_empleado' AND object_id = OBJECT_ID(N'ops.asignacion_tripulacion'))
    CREATE NONCLUSTERED INDEX ix_asignacion_empleado ON ops.asignacion_tripulacion (id_empleado) INCLUDE (rol_vuelo);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_empleado_cargo' AND object_id = OBJECT_ID(N'rh.empleado'))
    CREATE NONCLUSTERED INDEX ix_empleado_cargo ON rh.empleado (codigo_cargo) INCLUDE (id_localizacion_base, fecha_contratacion, fecha_terminacion);

-- ven.compra ---------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_compra_comprador' AND object_id = OBJECT_ID(N'ven.compra'))
    CREATE NONCLUSTERED INDEX ix_compra_comprador ON ven.compra (id_persona_comprador);
-- Ventas por período y canal (Q03, Q07, Q11).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_compra_fecha' AND object_id = OBJECT_ID(N'ven.compra'))
    CREATE NONCLUSTERED INDEX ix_compra_fecha ON ven.compra (fecha_compra_utc) INCLUDE (id_localizacion_venta, id_persona_comprador);

-- ven.tiquete --------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_compra' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_compra ON ven.tiquete (id_compra);
-- Ocupación por vuelo y cabina (Q01, Q02) y conciliación del inventario (RN-40).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_vuelo_cabina' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_vuelo_cabina ON ven.tiquete (id_vuelo, codigo_cabina)
        INCLUDE (codigo_estado, precio_base_usd, porcentaje_descuento, precio_final_usd);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_pasajero' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_pasajero ON ven.tiquete (id_persona_pasajero);
-- RN-20 (tarifa usada no cambia) y análisis de precios por tarifa.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_tarifa' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_tarifa ON ven.tiquete (id_tarifa);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_descuento' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_descuento ON ven.tiquete (id_descuento) WHERE id_descuento IS NOT NULL;
-- Vencimiento de reservas (usp_vencer_reservas): índice filtrado pequeño.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_tiquete_reservas_pendientes' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE NONCLUSTERED INDEX ix_tiquete_reservas_pendientes ON ven.tiquete (fecha_limite_pago_utc)
        WHERE codigo_estado = 'RESERVADO';

-- ven.pago y ven.reembolso -------------------------------------------------
-- RN-23 (suma de pagos por tiquete) y saldos (Q04).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_pago_tiquete' AND object_id = OBJECT_ID(N'ven.pago'))
    CREATE NONCLUSTERED INDEX ix_pago_tiquete ON ven.pago (id_tiquete) INCLUDE (codigo_estado, monto_usd, fecha_resolucion_utc);
-- Cobros por período (Q03).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_pago_resolucion' AND object_id = OBJECT_ID(N'ven.pago'))
    CREATE NONCLUSTERED INDEX ix_pago_resolucion ON ven.pago (fecha_resolucion_utc) INCLUDE (codigo_estado, monto_usd, codigo_metodo);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_reembolso_pago' AND object_id = OBJECT_ID(N'ven.reembolso'))
    CREATE NONCLUSTERED INDEX ix_reembolso_pago ON ven.reembolso (id_pago) INCLUDE (monto_usd);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_reembolso_fecha' AND object_id = OBJECT_ID(N'ven.reembolso'))
    CREATE NONCLUSTERED INDEX ix_reembolso_fecha ON ven.reembolso (fecha_reembolso_utc) INCLUDE (monto_usd, codigo_motivo);

-- ven.persona --------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_persona_documento' AND object_id = OBJECT_ID(N'ven.persona'))
    CREATE NONCLUSTERED INDEX ix_persona_documento ON ven.persona (numero_documento) WHERE numero_documento IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_persona_apellidos' AND object_id = OBJECT_ID(N'ven.persona'))
    CREATE NONCLUSTERED INDEX ix_persona_apellidos ON ven.persona (apellidos, nombres);

-- aud ----------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_cambio_estado_entidad' AND object_id = OBJECT_ID(N'aud.cambio_estado'))
    CREATE NONCLUSTERED INDEX ix_cambio_estado_entidad ON aud.cambio_estado (entidad, id_entidad);
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '04_indices')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('04_indices', N'Índices de rendimiento');
GO
SET NOEXEC OFF;
GO
