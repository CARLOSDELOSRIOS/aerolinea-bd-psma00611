/* =============================================================================
   03_claves_y_restricciones.sql
   Propósito : restricciones declarativas: UNIQUE, CHECK, FOREIGN KEY e índices
               únicos filtrados que implementan reglas de negocio.
   Depende de: 02_esquemas_y_tablas.sql
   Reinicio  : idempotente (cada restricción se crea solo si no existe).
   Nota      : los patrones de códigos usan COLLATE Latin1_General_BIN porque en
               una intercalación CI '[A-Z]' también acepta minúsculas.
   ============================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- requerido por índices filtrados y columnas calculadas persistidas
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ============================================================ 1. UNIQUE ==== */
IF OBJECT_ID(N'ref.uq_pais_nombre', N'UQ') IS NULL
    ALTER TABLE ref.pais ADD CONSTRAINT uq_pais_nombre UNIQUE (nombre);
IF OBJECT_ID(N'ref.uq_estado_eeuu_nombre', N'UQ') IS NULL
    ALTER TABLE ref.estado_eeuu ADD CONSTRAINT uq_estado_eeuu_nombre UNIQUE (nombre);
IF OBJECT_ID(N'ref.uq_localizacion_codigo', N'UQ') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT uq_localizacion_codigo UNIQUE (codigo_localizacion);
IF OBJECT_ID(N'ref.uq_localizacion_id_tipo', N'UQ') IS NULL            -- destino de la FK del subtipo aeropuerto
    ALTER TABLE ref.localizacion ADD CONSTRAINT uq_localizacion_id_tipo UNIQUE (id_localizacion, tipo_localizacion);
IF OBJECT_ID(N'ref.uq_aeropuerto_iata', N'UQ') IS NULL
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT uq_aeropuerto_iata UNIQUE (codigo_iata);
IF OBJECT_ID(N'ref.uq_aeropuerto_icao', N'UQ') IS NULL
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT uq_aeropuerto_icao UNIQUE (codigo_icao);
IF OBJECT_ID(N'ref.uq_cabina_nombre', N'UQ') IS NULL
    ALTER TABLE ref.cabina ADD CONSTRAINT uq_cabina_nombre UNIQUE (nombre);
IF OBJECT_ID(N'ref.uq_cabina_orden_abordaje', N'UQ') IS NULL
    ALTER TABLE ref.cabina ADD CONSTRAINT uq_cabina_orden_abordaje UNIQUE (orden_abordaje);
IF OBJECT_ID(N'ref.uq_modelo_avion', N'UQ') IS NULL
    ALTER TABLE ref.modelo_avion ADD CONSTRAINT uq_modelo_avion UNIQUE (fabricante, modelo);
IF OBJECT_ID(N'ref.uq_metodo_pago_nombre', N'UQ') IS NULL
    ALTER TABLE ref.metodo_pago ADD CONSTRAINT uq_metodo_pago_nombre UNIQUE (nombre);
IF OBJECT_ID(N'rh.uq_departamento_nombre', N'UQ') IS NULL
    ALTER TABLE rh.departamento ADD CONSTRAINT uq_departamento_nombre UNIQUE (nombre);
IF OBJECT_ID(N'rh.uq_cargo_nombre', N'UQ') IS NULL
    ALTER TABLE rh.cargo ADD CONSTRAINT uq_cargo_nombre UNIQUE (nombre);
IF OBJECT_ID(N'rh.uq_empleado_numero', N'UQ') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT uq_empleado_numero UNIQUE (numero_empleado);
IF OBJECT_ID(N'rh.uq_empleado_email', N'UQ') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT uq_empleado_email UNIQUE (email_corporativo);
IF OBJECT_ID(N'ops.uq_configuracion_codigo', N'UQ') IS NULL
    ALTER TABLE ops.configuracion_asientos ADD CONSTRAINT uq_configuracion_codigo UNIQUE (codigo_configuracion);
IF OBJECT_ID(N'ops.uq_asiento_fila_letra', N'UQ') IS NULL
    ALTER TABLE ops.asiento_configuracion ADD CONSTRAINT uq_asiento_fila_letra UNIQUE (id_configuracion, fila, letra);
IF OBJECT_ID(N'ops.uq_avion_matricula', N'UQ') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT uq_avion_matricula UNIQUE (matricula);
IF OBJECT_ID(N'ops.uq_avion_numero_serie', N'UQ') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT uq_avion_numero_serie UNIQUE (numero_serie);
IF OBJECT_ID(N'ops.uq_ruta_origen_destino', N'UQ') IS NULL                       -- RN-01
    ALTER TABLE ops.ruta ADD CONSTRAINT uq_ruta_origen_destino UNIQUE (id_aeropuerto_origen, id_aeropuerto_destino);
IF OBJECT_ID(N'ops.uq_programacion_numero_vigencia', N'UQ') IS NULL
    ALTER TABLE ops.programacion ADD CONSTRAINT uq_programacion_numero_vigencia UNIQUE (numero_vuelo, vigente_desde);
IF OBJECT_ID(N'ops.uq_vuelo_programacion_fecha', N'UQ') IS NULL                  -- RN-04
    ALTER TABLE ops.vuelo ADD CONSTRAINT uq_vuelo_programacion_fecha UNIQUE (id_programacion, fecha_salida_local);
IF OBJECT_ID(N'ven.uq_cliente_numero_viajero', N'UQ') IS NULL                    -- RN-38
    ALTER TABLE ven.cliente ADD CONSTRAINT uq_cliente_numero_viajero UNIQUE (numero_viajero);
IF OBJECT_ID(N'ven.uq_cliente_email_acceso', N'UQ') IS NULL                      -- RN-38
    ALTER TABLE ven.cliente ADD CONSTRAINT uq_cliente_email_acceso UNIQUE (email_acceso);
IF OBJECT_ID(N'ven.uq_compra_codigo_reserva', N'UQ') IS NULL
    ALTER TABLE ven.compra ADD CONSTRAINT uq_compra_codigo_reserva UNIQUE (codigo_reserva);
IF OBJECT_ID(N'ven.uq_tarifa_ruta_cabina_desde', N'UQ') IS NULL
    ALTER TABLE ven.tarifa ADD CONSTRAINT uq_tarifa_ruta_cabina_desde UNIQUE (id_ruta, codigo_cabina, vigente_desde);
IF OBJECT_ID(N'ven.uq_tarifa_id_cabina', N'UQ') IS NULL                          -- destino de la FK compuesta de tiquete (RN-16)
    ALTER TABLE ven.tarifa ADD CONSTRAINT uq_tarifa_id_cabina UNIQUE (id_tarifa, codigo_cabina);
IF OBJECT_ID(N'ven.uq_descuento_codigo', N'UQ') IS NULL
    ALTER TABLE ven.descuento ADD CONSTRAINT uq_descuento_codigo UNIQUE (codigo_descuento);
IF OBJECT_ID(N'ven.uq_politica_cabina_horas', N'UQ') IS NULL
    ALTER TABLE ven.politica_cancelacion ADD CONSTRAINT uq_politica_cabina_horas UNIQUE (codigo_cabina, horas_antes_min);
IF OBJECT_ID(N'ven.uq_tiquete_numero', N'UQ') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT uq_tiquete_numero UNIQUE (numero_tiquete);
GO

/* ============================================================= 2. CHECK ==== */
-- ref
IF OBJECT_ID(N'ref.ck_pais_codigo', N'C') IS NULL
    ALTER TABLE ref.pais ADD CONSTRAINT ck_pais_codigo CHECK (codigo_pais COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z]');
IF OBJECT_ID(N'ref.ck_estado_eeuu_codigo', N'C') IS NULL
    ALTER TABLE ref.estado_eeuu ADD CONSTRAINT ck_estado_eeuu_codigo CHECK (codigo_estado COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z]');
IF OBJECT_ID(N'ref.ck_localizacion_tipo', N'C') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT ck_localizacion_tipo CHECK (tipo_localizacion IN ('AER', 'OFI', 'WEB'));
IF OBJECT_ID(N'ref.ck_localizacion_datos_tipo', N'C') IS NULL  -- datos obligatorios o prohibidos según el tipo
    ALTER TABLE ref.localizacion ADD CONSTRAINT ck_localizacion_datos_tipo CHECK (
        (tipo_localizacion IN ('AER', 'OFI') AND ciudad IS NOT NULL AND codigo_estado IS NOT NULL
             AND zona_horaria IS NOT NULL AND url IS NULL)
     OR (tipo_localizacion = 'WEB' AND url IS NOT NULL AND ciudad IS NULL AND codigo_estado IS NULL
             AND direccion IS NULL AND codigo_postal IS NULL AND zona_horaria IS NULL));
IF OBJECT_ID(N'ref.ck_localizacion_url', N'C') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT ck_localizacion_url CHECK (url IS NULL OR url LIKE 'https://_%');
IF OBJECT_ID(N'ref.ck_localizacion_codigo_postal', N'C') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT ck_localizacion_codigo_postal CHECK (codigo_postal IS NULL OR codigo_postal LIKE '[0-9][0-9][0-9][0-9][0-9]');
IF OBJECT_ID(N'ref.ck_aeropuerto_iata', N'C') IS NULL
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT ck_aeropuerto_iata CHECK (codigo_iata COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z][A-Z]');
IF OBJECT_ID(N'ref.ck_aeropuerto_icao', N'C') IS NULL
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT ck_aeropuerto_icao CHECK (codigo_icao COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z][A-Z][A-Z]');
IF OBJECT_ID(N'ref.ck_aeropuerto_coordenadas', N'C') IS NULL
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT ck_aeropuerto_coordenadas CHECK (latitud BETWEEN -90 AND 90 AND longitud BETWEEN -180 AND 180);
IF OBJECT_ID(N'ref.ck_cabina_codigo', N'C') IS NULL
    ALTER TABLE ref.cabina ADD CONSTRAINT ck_cabina_codigo CHECK (codigo_cabina COLLATE Latin1_General_BIN LIKE '[A-Z][A-Z][A-Z]');
IF OBJECT_ID(N'ref.ck_cabina_equipaje', N'C') IS NULL
    ALTER TABLE ref.cabina ADD CONSTRAINT ck_cabina_equipaje CHECK (piezas_equipaje_bodega <= 5 AND peso_max_equipaje_kg BETWEEN 1 AND 50);
IF OBJECT_ID(N'ref.ck_modelo_avion_datos', N'C') IS NULL
    ALTER TABLE ref.modelo_avion ADD CONSTRAINT ck_modelo_avion_datos CHECK (alcance_millas > 0 AND velocidad_crucero_mph BETWEEN 200 AND 700);
IF OBJECT_ID(N'ref.ck_metodo_pago_canal', N'C') IS NULL
    ALTER TABLE ref.metodo_pago ADD CONSTRAINT ck_metodo_pago_canal CHECK (permite_web = 1 OR permite_fisico = 1);
IF OBJECT_ID(N'ref.ck_motivo_cancelacion_iniciador', N'C') IS NULL
    ALTER TABLE ref.motivo_cancelacion ADD CONSTRAINT ck_motivo_cancelacion_iniciador CHECK (iniciado_por IN ('CLIENTE', 'AEROLINEA', 'SISTEMA'));
IF OBJECT_ID(N'ref.ck_parametro_tipo', N'C') IS NULL
    ALTER TABLE ref.parametro ADD CONSTRAINT ck_parametro_tipo CHECK (tipo_dato IN ('INT', 'DECIMAL', 'DATE', 'DATETIME', 'TEXT'));
IF OBJECT_ID(N'ref.ck_mensaje_error_numero', N'C') IS NULL
    ALTER TABLE ref.mensaje_error ADD CONSTRAINT ck_mensaje_error_numero CHECK (numero_error BETWEEN 50000 AND 50999);
-- rh
IF OBJECT_ID(N'rh.ck_cargo_categoria', N'C') IS NULL
    ALTER TABLE rh.cargo ADD CONSTRAINT ck_cargo_categoria CHECK (categoria_tripulacion IS NULL OR categoria_tripulacion IN ('TECNICA', 'CABINA'));
IF OBJECT_ID(N'rh.ck_empleado_numero', N'C') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_numero CHECK (numero_empleado COLLATE Latin1_General_BIN LIKE 'E[0-9][0-9][0-9][0-9][0-9]');
IF OBJECT_ID(N'rh.ck_empleado_email', N'C') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_email CHECK (email_corporativo LIKE '%_@_%._%');
IF OBJECT_ID(N'rh.ck_empleado_mayor_edad', N'C') IS NULL                           -- RN-39
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_mayor_edad CHECK (DATEADD(YEAR, 18, fecha_nacimiento) <= fecha_contratacion);
IF OBJECT_ID(N'rh.ck_empleado_terminacion', N'C') IS NULL                          -- RN-39
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_terminacion CHECK (fecha_terminacion IS NULL OR fecha_terminacion >= fecha_contratacion);
IF OBJECT_ID(N'rh.ck_empleado_salario', N'C') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_salario CHECK (salario_anual_usd > 0);
IF OBJECT_ID(N'rh.ck_empleado_supervisor', N'C') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT ck_empleado_supervisor CHECK (id_supervisor IS NULL OR id_supervisor <> id_empleado);
-- ops
IF OBJECT_ID(N'ops.ck_asiento_codigo', N'C') IS NULL
    ALTER TABLE ops.asiento_configuracion ADD CONSTRAINT ck_asiento_codigo CHECK (codigo_asiento = CONCAT(fila, letra));
IF OBJECT_ID(N'ops.ck_asiento_fila_letra', N'C') IS NULL
    ALTER TABLE ops.asiento_configuracion ADD CONSTRAINT ck_asiento_fila_letra CHECK (fila BETWEEN 1 AND 60 AND letra COLLATE Latin1_General_BIN LIKE '[A-K]');
IF OBJECT_ID(N'ops.ck_avion_matricula', N'C') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT ck_avion_matricula CHECK (matricula COLLATE Latin1_General_BIN LIKE 'N[1-9]%' AND LEN(matricula) BETWEEN 3 AND 6);
IF OBJECT_ID(N'ops.ck_avion_estado', N'C') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT ck_avion_estado CHECK (estado_operativo IN ('ACTIVO', 'MANTENIMIENTO', 'RETIRADO'));
IF OBJECT_ID(N'ops.ck_avion_fechas', N'C') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT ck_avion_fechas CHECK (fecha_incorporacion >= fecha_fabricacion);
IF OBJECT_ID(N'ops.ck_ruta_origen_destino', N'C') IS NULL                          -- RN-01
    ALTER TABLE ops.ruta ADD CONSTRAINT ck_ruta_origen_destino CHECK (id_aeropuerto_origen <> id_aeropuerto_destino);
IF OBJECT_ID(N'ops.ck_ruta_distancia', N'C') IS NULL
    ALTER TABLE ops.ruta ADD CONSTRAINT ck_ruta_distancia CHECK (distancia_millas BETWEEN 50 AND 6000);
IF OBJECT_ID(N'ops.ck_programacion_numero', N'C') IS NULL
    ALTER TABLE ops.programacion ADD CONSTRAINT ck_programacion_numero CHECK (numero_vuelo BETWEEN 1 AND 9999);
IF OBJECT_ID(N'ops.ck_programacion_duracion', N'C') IS NULL
    ALTER TABLE ops.programacion ADD CONSTRAINT ck_programacion_duracion CHECK (duracion_programada_min BETWEEN 20 AND 1080);
IF OBJECT_ID(N'ops.ck_programacion_vigencia', N'C') IS NULL
    ALTER TABLE ops.programacion ADD CONSTRAINT ck_programacion_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde);
IF OBJECT_ID(N'ops.ck_programacion_dia_semana', N'C') IS NULL                      -- RN-02
    ALTER TABLE ops.programacion_dia ADD CONSTRAINT ck_programacion_dia_semana CHECK (dia_semana BETWEEN 1 AND 7);
IF OBJECT_ID(N'ops.ck_vuelo_horario', N'C') IS NULL                                -- RN-05
    ALTER TABLE ops.vuelo ADD CONSTRAINT ck_vuelo_horario CHECK (
        llegada_programada > salida_programada
        AND DATEDIFF(MINUTE, salida_programada, llegada_programada) BETWEEN 20 AND 1080);
IF OBJECT_ID(N'ops.ck_vuelo_estado_horas', N'C') IS NULL                           -- RN-07
    ALTER TABLE ops.vuelo ADD CONSTRAINT ck_vuelo_estado_horas CHECK (
        (codigo_estado = 'PROGRAMADO' AND salida_estimada IS NULL AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL)
     OR (codigo_estado = 'DEMORADO'   AND salida_estimada > salida_programada AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL)
     OR (codigo_estado = 'EN_VUELO'   AND salida_real IS NOT NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL)
     OR (codigo_estado = 'ATERRIZADO' AND salida_real IS NOT NULL AND llegada_real > salida_real AND motivo_cancelacion IS NULL)
     OR (codigo_estado = 'CANCELADO'  AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NOT NULL));
IF OBJECT_ID(N'ops.ck_vuelo_salida_real', N'C') IS NULL   -- coherencia temporal: no antes de 30 min ni después de 24 h
    ALTER TABLE ops.vuelo ADD CONSTRAINT ck_vuelo_salida_real CHECK (
        salida_real IS NULL
        OR (salida_real >= DATEADD(MINUTE, -30, salida_programada) AND salida_real <= DATEADD(HOUR, 24, salida_programada)));
IF OBJECT_ID(N'ops.ck_vuelo_cabina_capacidad', N'C') IS NULL                       -- RN-11 (sin sobreventa)
    ALTER TABLE ops.vuelo_cabina ADD CONSTRAINT ck_vuelo_cabina_capacidad CHECK (capacidad > 0 AND plazas_ocupadas >= 0 AND plazas_ocupadas <= capacidad);
IF OBJECT_ID(N'ops.ck_asignacion_rol', N'C') IS NULL
    ALTER TABLE ops.asignacion_tripulacion ADD CONSTRAINT ck_asignacion_rol CHECK (rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL', 'JEFE_CABINA', 'AUXILIAR_VUELO'));
-- ven
IF OBJECT_ID(N'ven.ck_persona_genero', N'C') IS NULL
    ALTER TABLE ven.persona ADD CONSTRAINT ck_persona_genero CHECK (genero IS NULL OR genero IN ('F', 'M', 'X'));
IF OBJECT_ID(N'ven.ck_persona_email', N'C') IS NULL
    ALTER TABLE ven.persona ADD CONSTRAINT ck_persona_email CHECK (email_contacto IS NULL OR email_contacto LIKE '%_@_%._%');
IF OBJECT_ID(N'ven.ck_persona_documento', N'C') IS NULL   -- documento completo o ausente
    ALTER TABLE ven.persona ADD CONSTRAINT ck_persona_documento CHECK (
        (tipo_documento IS NULL AND numero_documento IS NULL AND codigo_pais_documento IS NULL)
     OR (tipo_documento IN ('PASAPORTE', 'LICENCIA', 'ID_ESTATAL') AND numero_documento IS NOT NULL AND codigo_pais_documento IS NOT NULL));
IF OBJECT_ID(N'ven.ck_persona_fecha_nacimiento', N'C') IS NULL
    ALTER TABLE ven.persona ADD CONSTRAINT ck_persona_fecha_nacimiento CHECK (
        fecha_nacimiento IS NULL OR (fecha_nacimiento >= '19000101' AND fecha_nacimiento <= CAST(creado_utc AS DATE)));
IF OBJECT_ID(N'ven.ck_cliente_nivel', N'C') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT ck_cliente_nivel CHECK (nivel_lealtad IN ('BASICO', 'PLATA', 'ORO', 'PLATINO'));
IF OBJECT_ID(N'ven.ck_cliente_estado', N'C') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT ck_cliente_estado CHECK (estado_cuenta IN ('ACTIVA', 'SUSPENDIDA', 'CERRADA'));
IF OBJECT_ID(N'ven.ck_cliente_numero_viajero', N'C') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT ck_cliente_numero_viajero CHECK (numero_viajero COLLATE Latin1_General_BIN LIKE 'VF[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
IF OBJECT_ID(N'ven.ck_cliente_email', N'C') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT ck_cliente_email CHECK (email_acceso LIKE '%_@_%._%');
IF OBJECT_ID(N'ven.ck_compra_codigo_reserva', N'C') IS NULL
    ALTER TABLE ven.compra ADD CONSTRAINT ck_compra_codigo_reserva CHECK (
        LEN(codigo_reserva) = 6 AND codigo_reserva COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9]%');
IF OBJECT_ID(N'ven.ck_tarifa_precio', N'C') IS NULL
    ALTER TABLE ven.tarifa ADD CONSTRAINT ck_tarifa_precio CHECK (precio_base_usd > 0);
IF OBJECT_ID(N'ven.ck_tarifa_vigencia', N'C') IS NULL
    ALTER TABLE ven.tarifa ADD CONSTRAINT ck_tarifa_vigencia CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde);
IF OBJECT_ID(N'ven.ck_descuento_porcentaje', N'C') IS NULL
    ALTER TABLE ven.descuento ADD CONSTRAINT ck_descuento_porcentaje CHECK (porcentaje > 0 AND porcentaje <= 100);
IF OBJECT_ID(N'ven.ck_descuento_vigencia', N'C') IS NULL
    ALTER TABLE ven.descuento ADD CONSTRAINT ck_descuento_vigencia CHECK (vigente_hasta >= vigente_desde);
IF OBJECT_ID(N'ven.ck_descuento_anticipacion', N'C') IS NULL
    ALTER TABLE ven.descuento ADD CONSTRAINT ck_descuento_anticipacion CHECK (dias_anticipacion_min IS NULL OR dias_anticipacion_min BETWEEN 0 AND 365);
IF OBJECT_ID(N'ven.ck_politica_valores', N'C') IS NULL
    ALTER TABLE ven.politica_cancelacion ADD CONSTRAINT ck_politica_valores CHECK (horas_antes_min >= 0 AND porcentaje_reembolso BETWEEN 0 AND 100);
IF OBJECT_ID(N'ven.ck_tiquete_numero', N'C') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_numero CHECK (LEN(numero_tiquete) = 13 AND numero_tiquete NOT LIKE '%[^0-9]%');
IF OBJECT_ID(N'ven.ck_tiquete_precio', N'C') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_precio CHECK (precio_base_usd > 0);
IF OBJECT_ID(N'ven.ck_tiquete_descuento', N'C') IS NULL                            -- RN-21
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_descuento CHECK (
        (id_descuento IS NULL AND porcentaje_descuento = 0)
     OR (id_descuento IS NOT NULL AND porcentaje_descuento > 0 AND porcentaje_descuento <= 100));
IF OBJECT_ID(N'ven.ck_tiquete_cancelacion', N'C') IS NULL                          -- RN-30
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_cancelacion CHECK (
        (codigo_estado = 'CANCELADO' AND fecha_cancelacion_utc IS NOT NULL AND codigo_motivo_cancelacion IS NOT NULL)
     OR (codigo_estado <> 'CANCELADO' AND fecha_cancelacion_utc IS NULL AND codigo_motivo_cancelacion IS NULL));
IF OBJECT_ID(N'ven.ck_tiquete_emision', N'C') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_emision CHECK (
        (codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') AND fecha_emision_utc IS NOT NULL)
     OR (codigo_estado = 'RESERVADO' AND fecha_emision_utc IS NULL)
     OR  codigo_estado = 'CANCELADO');
IF OBJECT_ID(N'ven.ck_tiquete_fechas', N'C') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT ck_tiquete_fechas CHECK (
        fecha_limite_pago_utc > creado_utc
        AND (fecha_emision_utc IS NULL OR fecha_emision_utc >= creado_utc)
        AND (fecha_cancelacion_utc IS NULL OR fecha_cancelacion_utc >= creado_utc));
IF OBJECT_ID(N'ven.ck_pago_monto', N'C') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_monto CHECK (monto_usd > 0);
IF OBJECT_ID(N'ven.ck_pago_tarjeta', N'C') IS NULL                                 -- RN-26
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_tarjeta CHECK (
        (codigo_metodo IN ('TC', 'TD') AND ultimos4_tarjeta IS NOT NULL AND marca_tarjeta IS NOT NULL)
     OR (codigo_metodo NOT IN ('TC', 'TD') AND ultimos4_tarjeta IS NULL AND marca_tarjeta IS NULL));
IF OBJECT_ID(N'ven.ck_pago_ultimos4', N'C') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_ultimos4 CHECK (ultimos4_tarjeta IS NULL OR ultimos4_tarjeta LIKE '[0-9][0-9][0-9][0-9]');
IF OBJECT_ID(N'ven.ck_pago_marca', N'C') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_marca CHECK (marca_tarjeta IS NULL OR marca_tarjeta IN ('VISA', 'MASTERCARD', 'AMEX', 'DISCOVER'));
IF OBJECT_ID(N'ven.ck_pago_estado_datos', N'C') IS NULL                            -- RN-27
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_estado_datos CHECK (
        (codigo_estado = 'PENDIENTE'  AND fecha_resolucion_utc IS NULL AND motivo_rechazo IS NULL)
     OR (codigo_estado = 'CONFIRMADO' AND fecha_resolucion_utc IS NOT NULL AND referencia_autorizacion IS NOT NULL AND motivo_rechazo IS NULL)
     OR (codigo_estado = 'FALLIDO'    AND fecha_resolucion_utc IS NOT NULL AND motivo_rechazo IS NOT NULL)
     OR (codigo_estado = 'ANULADO'    AND fecha_resolucion_utc IS NOT NULL));
IF OBJECT_ID(N'ven.ck_pago_fechas', N'C') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT ck_pago_fechas CHECK (fecha_resolucion_utc IS NULL OR fecha_resolucion_utc >= fecha_creacion_utc);
IF OBJECT_ID(N'ven.ck_reembolso_valores', N'C') IS NULL
    ALTER TABLE ven.reembolso ADD CONSTRAINT ck_reembolso_valores CHECK (monto_usd > 0 AND porcentaje_aplicado > 0 AND porcentaje_aplicado <= 100);
IF OBJECT_ID(N'ven.ck_reembolso_regla', N'C') IS NULL
    ALTER TABLE ven.reembolso ADD CONSTRAINT ck_reembolso_regla CHECK (regla_aplicada IN ('REEMBOLSO_TOTAL', 'REGLA_24H', 'POLITICA_CABINA'));
-- aud / tst
IF OBJECT_ID(N'aud.ck_cambio_estado_entidad', N'C') IS NULL
    ALTER TABLE aud.cambio_estado ADD CONSTRAINT ck_cambio_estado_entidad CHECK (entidad IN ('VUELO', 'TIQUETE', 'PAGO'));
IF OBJECT_ID(N'tst.ck_resultado_prueba_resultado', N'C') IS NULL
    ALTER TABLE tst.resultado_prueba ADD CONSTRAINT ck_resultado_prueba_resultado CHECK (resultado IN ('SUPERADA', 'FALLIDA'));
GO

/* ======================================================= 3. FOREIGN KEY ==== */
-- ref
IF OBJECT_ID(N'ref.fk_localizacion_estado', N'F') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT fk_localizacion_estado FOREIGN KEY (codigo_estado) REFERENCES ref.estado_eeuu (codigo_estado);
IF OBJECT_ID(N'ref.fk_localizacion_zona_horaria', N'F') IS NULL
    ALTER TABLE ref.localizacion ADD CONSTRAINT fk_localizacion_zona_horaria FOREIGN KEY (zona_horaria) REFERENCES ref.zona_horaria (nombre_windows);
IF OBJECT_ID(N'ref.fk_aeropuerto_localizacion', N'F') IS NULL   -- el subtipo solo puede apuntar a una localización de tipo AER
    ALTER TABLE ref.aeropuerto ADD CONSTRAINT fk_aeropuerto_localizacion FOREIGN KEY (id_localizacion, tipo_localizacion)
        REFERENCES ref.localizacion (id_localizacion, tipo_localizacion);
IF OBJECT_ID(N'ref.fk_transicion_vuelo_origen', N'F') IS NULL
    ALTER TABLE ref.transicion_vuelo ADD CONSTRAINT fk_transicion_vuelo_origen FOREIGN KEY (estado_origen) REFERENCES ref.estado_vuelo (codigo_estado);
IF OBJECT_ID(N'ref.fk_transicion_vuelo_destino', N'F') IS NULL
    ALTER TABLE ref.transicion_vuelo ADD CONSTRAINT fk_transicion_vuelo_destino FOREIGN KEY (estado_destino) REFERENCES ref.estado_vuelo (codigo_estado);
IF OBJECT_ID(N'ref.fk_transicion_tiquete_origen', N'F') IS NULL
    ALTER TABLE ref.transicion_tiquete ADD CONSTRAINT fk_transicion_tiquete_origen FOREIGN KEY (estado_origen) REFERENCES ref.estado_tiquete (codigo_estado);
IF OBJECT_ID(N'ref.fk_transicion_tiquete_destino', N'F') IS NULL
    ALTER TABLE ref.transicion_tiquete ADD CONSTRAINT fk_transicion_tiquete_destino FOREIGN KEY (estado_destino) REFERENCES ref.estado_tiquete (codigo_estado);
IF OBJECT_ID(N'ref.fk_transicion_pago_origen', N'F') IS NULL
    ALTER TABLE ref.transicion_pago ADD CONSTRAINT fk_transicion_pago_origen FOREIGN KEY (estado_origen) REFERENCES ref.estado_pago (codigo_estado);
IF OBJECT_ID(N'ref.fk_transicion_pago_destino', N'F') IS NULL
    ALTER TABLE ref.transicion_pago ADD CONSTRAINT fk_transicion_pago_destino FOREIGN KEY (estado_destino) REFERENCES ref.estado_pago (codigo_estado);
-- rh
IF OBJECT_ID(N'rh.fk_cargo_departamento', N'F') IS NULL
    ALTER TABLE rh.cargo ADD CONSTRAINT fk_cargo_departamento FOREIGN KEY (codigo_departamento) REFERENCES rh.departamento (codigo_departamento);
IF OBJECT_ID(N'rh.fk_empleado_cargo', N'F') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT fk_empleado_cargo FOREIGN KEY (codigo_cargo) REFERENCES rh.cargo (codigo_cargo);
IF OBJECT_ID(N'rh.fk_empleado_localizacion', N'F') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT fk_empleado_localizacion FOREIGN KEY (id_localizacion_base) REFERENCES ref.localizacion (id_localizacion);
IF OBJECT_ID(N'rh.fk_empleado_supervisor', N'F') IS NULL
    ALTER TABLE rh.empleado ADD CONSTRAINT fk_empleado_supervisor FOREIGN KEY (id_supervisor) REFERENCES rh.empleado (id_empleado);
-- ops
IF OBJECT_ID(N'ops.fk_configuracion_modelo', N'F') IS NULL
    ALTER TABLE ops.configuracion_asientos ADD CONSTRAINT fk_configuracion_modelo FOREIGN KEY (id_modelo) REFERENCES ref.modelo_avion (id_modelo);
IF OBJECT_ID(N'ops.fk_asiento_configuracion', N'F') IS NULL
    ALTER TABLE ops.asiento_configuracion ADD CONSTRAINT fk_asiento_configuracion FOREIGN KEY (id_configuracion) REFERENCES ops.configuracion_asientos (id_configuracion);
IF OBJECT_ID(N'ops.fk_asiento_cabina', N'F') IS NULL
    ALTER TABLE ops.asiento_configuracion ADD CONSTRAINT fk_asiento_cabina FOREIGN KEY (codigo_cabina) REFERENCES ref.cabina (codigo_cabina);
IF OBJECT_ID(N'ops.fk_avion_configuracion', N'F') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT fk_avion_configuracion FOREIGN KEY (id_configuracion) REFERENCES ops.configuracion_asientos (id_configuracion);
IF OBJECT_ID(N'ops.fk_avion_aeropuerto_base', N'F') IS NULL
    ALTER TABLE ops.avion ADD CONSTRAINT fk_avion_aeropuerto_base FOREIGN KEY (id_aeropuerto_base) REFERENCES ref.aeropuerto (id_localizacion);
IF OBJECT_ID(N'ops.fk_ruta_origen', N'F') IS NULL
    ALTER TABLE ops.ruta ADD CONSTRAINT fk_ruta_origen FOREIGN KEY (id_aeropuerto_origen) REFERENCES ref.aeropuerto (id_localizacion);
IF OBJECT_ID(N'ops.fk_ruta_destino', N'F') IS NULL
    ALTER TABLE ops.ruta ADD CONSTRAINT fk_ruta_destino FOREIGN KEY (id_aeropuerto_destino) REFERENCES ref.aeropuerto (id_localizacion);
IF OBJECT_ID(N'ops.fk_programacion_ruta', N'F') IS NULL
    ALTER TABLE ops.programacion ADD CONSTRAINT fk_programacion_ruta FOREIGN KEY (id_ruta) REFERENCES ops.ruta (id_ruta);
IF OBJECT_ID(N'ops.fk_programacion_dia_programacion', N'F') IS NULL
    ALTER TABLE ops.programacion_dia ADD CONSTRAINT fk_programacion_dia_programacion FOREIGN KEY (id_programacion) REFERENCES ops.programacion (id_programacion);
IF OBJECT_ID(N'ops.fk_vuelo_programacion', N'F') IS NULL
    ALTER TABLE ops.vuelo ADD CONSTRAINT fk_vuelo_programacion FOREIGN KEY (id_programacion) REFERENCES ops.programacion (id_programacion);
IF OBJECT_ID(N'ops.fk_vuelo_avion', N'F') IS NULL
    ALTER TABLE ops.vuelo ADD CONSTRAINT fk_vuelo_avion FOREIGN KEY (id_avion) REFERENCES ops.avion (id_avion);
IF OBJECT_ID(N'ops.fk_vuelo_estado', N'F') IS NULL
    ALTER TABLE ops.vuelo ADD CONSTRAINT fk_vuelo_estado FOREIGN KEY (codigo_estado) REFERENCES ref.estado_vuelo (codigo_estado);
IF OBJECT_ID(N'ops.fk_vuelo_cabina_vuelo', N'F') IS NULL
    ALTER TABLE ops.vuelo_cabina ADD CONSTRAINT fk_vuelo_cabina_vuelo FOREIGN KEY (id_vuelo) REFERENCES ops.vuelo (id_vuelo);
IF OBJECT_ID(N'ops.fk_vuelo_cabina_cabina', N'F') IS NULL
    ALTER TABLE ops.vuelo_cabina ADD CONSTRAINT fk_vuelo_cabina_cabina FOREIGN KEY (codigo_cabina) REFERENCES ref.cabina (codigo_cabina);
IF OBJECT_ID(N'ops.fk_asignacion_vuelo', N'F') IS NULL
    ALTER TABLE ops.asignacion_tripulacion ADD CONSTRAINT fk_asignacion_vuelo FOREIGN KEY (id_vuelo) REFERENCES ops.vuelo (id_vuelo);
IF OBJECT_ID(N'ops.fk_asignacion_empleado', N'F') IS NULL
    ALTER TABLE ops.asignacion_tripulacion ADD CONSTRAINT fk_asignacion_empleado FOREIGN KEY (id_empleado) REFERENCES rh.empleado (id_empleado);
-- ven
IF OBJECT_ID(N'ven.fk_persona_pais_nacionalidad', N'F') IS NULL
    ALTER TABLE ven.persona ADD CONSTRAINT fk_persona_pais_nacionalidad FOREIGN KEY (codigo_pais_nacionalidad) REFERENCES ref.pais (codigo_pais);
IF OBJECT_ID(N'ven.fk_persona_pais_documento', N'F') IS NULL
    ALTER TABLE ven.persona ADD CONSTRAINT fk_persona_pais_documento FOREIGN KEY (codigo_pais_documento) REFERENCES ref.pais (codigo_pais);
IF OBJECT_ID(N'ven.fk_cliente_persona', N'F') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT fk_cliente_persona FOREIGN KEY (id_persona) REFERENCES ven.persona (id_persona);
IF OBJECT_ID(N'ven.fk_cliente_aeropuerto', N'F') IS NULL
    ALTER TABLE ven.cliente ADD CONSTRAINT fk_cliente_aeropuerto FOREIGN KEY (id_aeropuerto_preferido) REFERENCES ref.aeropuerto (id_localizacion);
IF OBJECT_ID(N'ven.fk_compra_comprador', N'F') IS NULL
    ALTER TABLE ven.compra ADD CONSTRAINT fk_compra_comprador FOREIGN KEY (id_persona_comprador) REFERENCES ven.persona (id_persona);
IF OBJECT_ID(N'ven.fk_compra_localizacion', N'F') IS NULL
    ALTER TABLE ven.compra ADD CONSTRAINT fk_compra_localizacion FOREIGN KEY (id_localizacion_venta) REFERENCES ref.localizacion (id_localizacion);
IF OBJECT_ID(N'ven.fk_compra_vendedor', N'F') IS NULL
    ALTER TABLE ven.compra ADD CONSTRAINT fk_compra_vendedor FOREIGN KEY (id_empleado_vendedor) REFERENCES rh.empleado (id_empleado);
IF OBJECT_ID(N'ven.fk_tarifa_ruta', N'F') IS NULL
    ALTER TABLE ven.tarifa ADD CONSTRAINT fk_tarifa_ruta FOREIGN KEY (id_ruta) REFERENCES ops.ruta (id_ruta);
IF OBJECT_ID(N'ven.fk_tarifa_cabina', N'F') IS NULL
    ALTER TABLE ven.tarifa ADD CONSTRAINT fk_tarifa_cabina FOREIGN KEY (codigo_cabina) REFERENCES ref.cabina (codigo_cabina);
IF OBJECT_ID(N'ven.fk_descuento_cabina', N'F') IS NULL
    ALTER TABLE ven.descuento ADD CONSTRAINT fk_descuento_cabina FOREIGN KEY (codigo_cabina) REFERENCES ref.cabina (codigo_cabina);
IF OBJECT_ID(N'ven.fk_politica_cabina', N'F') IS NULL
    ALTER TABLE ven.politica_cancelacion ADD CONSTRAINT fk_politica_cabina FOREIGN KEY (codigo_cabina) REFERENCES ref.cabina (codigo_cabina);
IF OBJECT_ID(N'ven.fk_tiquete_compra', N'F') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_compra FOREIGN KEY (id_compra) REFERENCES ven.compra (id_compra);
IF OBJECT_ID(N'ven.fk_tiquete_vuelo_cabina', N'F') IS NULL                         -- RN-15
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_vuelo_cabina FOREIGN KEY (id_vuelo, codigo_cabina) REFERENCES ops.vuelo_cabina (id_vuelo, codigo_cabina);
IF OBJECT_ID(N'ven.fk_tiquete_pasajero', N'F') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_pasajero FOREIGN KEY (id_persona_pasajero) REFERENCES ven.persona (id_persona);
IF OBJECT_ID(N'ven.fk_tiquete_tarifa_cabina', N'F') IS NULL                        -- RN-16
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_tarifa_cabina FOREIGN KEY (id_tarifa, codigo_cabina) REFERENCES ven.tarifa (id_tarifa, codigo_cabina);
IF OBJECT_ID(N'ven.fk_tiquete_descuento', N'F') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_descuento FOREIGN KEY (id_descuento) REFERENCES ven.descuento (id_descuento);
IF OBJECT_ID(N'ven.fk_tiquete_estado', N'F') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_estado FOREIGN KEY (codigo_estado) REFERENCES ref.estado_tiquete (codigo_estado);
IF OBJECT_ID(N'ven.fk_tiquete_motivo', N'F') IS NULL
    ALTER TABLE ven.tiquete ADD CONSTRAINT fk_tiquete_motivo FOREIGN KEY (codigo_motivo_cancelacion) REFERENCES ref.motivo_cancelacion (codigo_motivo);
IF OBJECT_ID(N'ven.fk_pago_tiquete', N'F') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT fk_pago_tiquete FOREIGN KEY (id_tiquete) REFERENCES ven.tiquete (id_tiquete);
IF OBJECT_ID(N'ven.fk_pago_metodo', N'F') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT fk_pago_metodo FOREIGN KEY (codigo_metodo) REFERENCES ref.metodo_pago (codigo_metodo);
IF OBJECT_ID(N'ven.fk_pago_localizacion', N'F') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT fk_pago_localizacion FOREIGN KEY (id_localizacion_cobro) REFERENCES ref.localizacion (id_localizacion);
IF OBJECT_ID(N'ven.fk_pago_estado', N'F') IS NULL
    ALTER TABLE ven.pago ADD CONSTRAINT fk_pago_estado FOREIGN KEY (codigo_estado) REFERENCES ref.estado_pago (codigo_estado);
IF OBJECT_ID(N'ven.fk_reembolso_pago', N'F') IS NULL
    ALTER TABLE ven.reembolso ADD CONSTRAINT fk_reembolso_pago FOREIGN KEY (id_pago) REFERENCES ven.pago (id_pago);
IF OBJECT_ID(N'ven.fk_reembolso_motivo', N'F') IS NULL
    ALTER TABLE ven.reembolso ADD CONSTRAINT fk_reembolso_motivo FOREIGN KEY (codigo_motivo) REFERENCES ref.motivo_cancelacion (codigo_motivo);
GO

/* ====================== 4. Índices únicos filtrados (restricciones de negocio) */
-- RN-12: un asiento no se vende dos veces en el mismo vuelo (solo cuentan tiquetes activos).
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_tiquete_vuelo_asiento' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_tiquete_vuelo_asiento ON ven.tiquete (id_vuelo, codigo_asiento)
        WHERE codigo_asiento IS NOT NULL AND codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO');
-- RN-14: un pasajero no tiene dos tiquetes activos en el mismo vuelo.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_tiquete_vuelo_pasajero' AND object_id = OBJECT_ID(N'ven.tiquete'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_tiquete_vuelo_pasajero ON ven.tiquete (id_vuelo, id_persona_pasajero)
        WHERE codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO');
-- RN-34: un capitán, un primer oficial y un jefe de cabina por vuelo.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_asignacion_capitan' AND object_id = OBJECT_ID(N'ops.asignacion_tripulacion'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_asignacion_capitan ON ops.asignacion_tripulacion (id_vuelo) WHERE rol_vuelo = 'CAPITAN';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_asignacion_primer_oficial' AND object_id = OBJECT_ID(N'ops.asignacion_tripulacion'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_asignacion_primer_oficial ON ops.asignacion_tripulacion (id_vuelo) WHERE rol_vuelo = 'PRIMER_OFICIAL';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_asignacion_jefe_cabina' AND object_id = OBJECT_ID(N'ops.asignacion_tripulacion'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_asignacion_jefe_cabina ON ops.asignacion_tripulacion (id_vuelo) WHERE rol_vuelo = 'JEFE_CABINA';
-- Las URL de los canales web no se repiten.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_localizacion_url' AND object_id = OBJECT_ID(N'ref.localizacion'))
    CREATE UNIQUE NONCLUSTERED INDEX ux_localizacion_url ON ref.localizacion (url) WHERE url IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '03_claves_y_restricciones')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('03_claves_y_restricciones', N'UNIQUE, CHECK, FK e índices únicos filtrados');
GO
SET NOEXEC OFF;
GO
