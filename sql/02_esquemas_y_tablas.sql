/* =============================================================================
   02_esquemas_y_tablas.sql
   Propósito : crear esquemas, secuencias y tablas con su clave primaria,
               valores predeterminados y columnas calculadas.
               Las claves foráneas, UNIQUE y CHECK se agregan en 03.
   Requisito : conectado a la base del proyecto (local: AerolineaDB; Azure: la
               base creada en el portal). No usa USE ni objetos de otras bases.
   Reinicio  : idempotente. Cada objeto se crea solo si no existe; reejecutar
               el script no borra datos ni altera tablas existentes.
   Convenciones:
     - Nombres en español, snake_case, tablas en singular.
     - pk_ clave primaria, df_ predeterminado, fk_ foránea, uq_ única, ck_ check,
       ix_ índice, ux_ índice único filtrado.
     - Importes en USD con DECIMAL(10,2); porcentajes con DECIMAL(5,2).
     - Marcas de tiempo transaccionales en UTC: DATETIME2(0) con sufijo _utc.
     - Horarios de vuelo: DATETIMEOFFSET(0) en hora local del aeropuerto.
   ============================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script (no a %s).', 16, 1, N'una base de sistema');
    SET NOEXEC ON;
END
GO

/* ---------------------------------------------------------------- esquemas */
IF SCHEMA_ID(N'adm') IS NULL EXEC (N'CREATE SCHEMA adm AUTHORIZATION dbo;');  -- administración del despliegue
IF SCHEMA_ID(N'ref') IS NULL EXEC (N'CREATE SCHEMA ref AUTHORIZATION dbo;');  -- referencia y catálogos
IF SCHEMA_ID(N'ops') IS NULL EXEC (N'CREATE SCHEMA ops AUTHORIZATION dbo;');  -- operaciones: red, flota, vuelos, tripulación
IF SCHEMA_ID(N'rh')  IS NULL EXEC (N'CREATE SCHEMA rh AUTHORIZATION dbo;');   -- recursos humanos
IF SCHEMA_ID(N'ven') IS NULL EXEC (N'CREATE SCHEMA ven AUTHORIZATION dbo;');  -- ventas: personas, compras, tiquetes, pagos
IF SCHEMA_ID(N'aud') IS NULL EXEC (N'CREATE SCHEMA aud AUTHORIZATION dbo;');  -- auditoría
IF SCHEMA_ID(N'rpt') IS NULL EXEC (N'CREATE SCHEMA rpt AUTHORIZATION dbo;');  -- vistas y procedimientos de reporte
IF SCHEMA_ID(N'stg') IS NULL EXEC (N'CREATE SCHEMA stg AUTHORIZATION dbo;');  -- área de carga (staging) de datos sintéticos
IF SCHEMA_ID(N'tst') IS NULL EXEC (N'CREATE SCHEMA tst AUTHORIZATION dbo;');  -- resultados de pruebas
GO

/* ------------------------------------------------------------ adm: despliegue */
IF OBJECT_ID(N'adm.registro_despliegue', N'U') IS NULL
CREATE TABLE adm.registro_despliegue (
    id_registro     INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_registro_despliegue PRIMARY KEY,
    script          VARCHAR(80)       NOT NULL,
    descripcion     NVARCHAR(400)     NULL,
    ejecutado_utc   DATETIME2(0)      NOT NULL CONSTRAINT df_registro_despliegue_ejecutado DEFAULT (SYSUTCDATETIME()),
    usuario         NVARCHAR(128)     NOT NULL CONSTRAINT df_registro_despliegue_usuario DEFAULT (SUSER_SNAME()),
    version_motor   NVARCHAR(128)     NOT NULL CONSTRAINT df_registro_despliegue_version DEFAULT (CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)))
);
GO

/* ------------------------------------------------------------- secuencias */
IF OBJECT_ID(N'ven.seq_numero_tiquete', N'SO') IS NULL
    CREATE SEQUENCE ven.seq_numero_tiquete AS BIGINT START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9999999999 NO CYCLE CACHE 50;
IF OBJECT_ID(N'ven.seq_numero_viajero', N'SO') IS NULL
    CREATE SEQUENCE ven.seq_numero_viajero AS INT START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 99999999 NO CYCLE CACHE 20;
GO

/* ================================================================ ref ===== */
IF OBJECT_ID(N'ref.pais', N'U') IS NULL
CREATE TABLE ref.pais (
    codigo_pais     CHAR(2)        NOT NULL CONSTRAINT pk_pais PRIMARY KEY,   -- ISO 3166-1 alfa-2
    nombre          NVARCHAR(60)   NOT NULL
);

IF OBJECT_ID(N'ref.estado_eeuu', N'U') IS NULL
CREATE TABLE ref.estado_eeuu (
    codigo_estado   CHAR(2)        NOT NULL CONSTRAINT pk_estado_eeuu PRIMARY KEY,  -- código postal USPS
    nombre          NVARCHAR(40)   NOT NULL
);

IF OBJECT_ID(N'ref.zona_horaria', N'U') IS NULL
CREATE TABLE ref.zona_horaria (
    nombre_windows          VARCHAR(50)   NOT NULL CONSTRAINT pk_zona_horaria PRIMARY KEY,  -- nombre que acepta AT TIME ZONE
    nombre_iana             VARCHAR(50)   NOT NULL,
    descripcion             NVARCHAR(100) NOT NULL,
    observa_horario_verano  BIT           NOT NULL
);

IF OBJECT_ID(N'ref.localizacion', N'U') IS NULL
CREATE TABLE ref.localizacion (
    id_localizacion     INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_localizacion PRIMARY KEY,
    codigo_localizacion VARCHAR(12)    NOT NULL,
    tipo_localizacion   CHAR(3)        NOT NULL,           -- AER aeropuerto, OFI oficina física, WEB canal web
    nombre              NVARCHAR(100)  NOT NULL,
    ciudad              NVARCHAR(60)   NULL,
    codigo_estado       CHAR(2)        NULL,
    direccion           NVARCHAR(150)  NULL,
    codigo_postal       VARCHAR(10)    NULL,
    zona_horaria        VARCHAR(50)    NULL,
    url                 VARCHAR(200)   NULL,
    vende_tiquetes      BIT            NOT NULL CONSTRAINT df_localizacion_vende DEFAULT (1),
    activa              BIT            NOT NULL CONSTRAINT df_localizacion_activa DEFAULT (1),
    fecha_apertura      DATE           NOT NULL,
    creado_utc          DATETIME2(0)   NOT NULL CONSTRAINT df_localizacion_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ref.aeropuerto', N'U') IS NULL
CREATE TABLE ref.aeropuerto (                          -- subtipo de localizacion (tipo AER)
    id_localizacion     INT            NOT NULL CONSTRAINT pk_aeropuerto PRIMARY KEY,
    tipo_localizacion   AS CAST('AER' AS CHAR(3)) PERSISTED NOT NULL,  -- fija el subtipo para la FK compuesta
    codigo_iata         CHAR(3)        NOT NULL,
    codigo_icao         CHAR(4)        NOT NULL,
    latitud             DECIMAL(9,6)   NOT NULL,
    longitud            DECIMAL(9,6)   NOT NULL,
    es_base_operaciones BIT            NOT NULL CONSTRAINT df_aeropuerto_base DEFAULT (0)
);

IF OBJECT_ID(N'ref.cabina', N'U') IS NULL
CREATE TABLE ref.cabina (
    codigo_cabina           CHAR(3)        NOT NULL CONSTRAINT pk_cabina PRIMARY KEY,   -- VIP, ECO
    nombre                  NVARCHAR(40)   NOT NULL,
    descripcion             NVARCHAR(200)  NOT NULL,
    piezas_equipaje_bodega  TINYINT        NOT NULL,
    peso_max_equipaje_kg    TINYINT        NOT NULL,
    acceso_sala_vip         BIT            NOT NULL,
    orden_abordaje          TINYINT        NOT NULL
);

IF OBJECT_ID(N'ref.modelo_avion', N'U') IS NULL
CREATE TABLE ref.modelo_avion (
    id_modelo               SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_modelo_avion PRIMARY KEY,
    fabricante              NVARCHAR(40)   NOT NULL,
    modelo                  NVARCHAR(40)   NOT NULL,
    alcance_millas          SMALLINT       NOT NULL,
    velocidad_crucero_mph   SMALLINT       NOT NULL
);

IF OBJECT_ID(N'ref.metodo_pago', N'U') IS NULL
CREATE TABLE ref.metodo_pago (
    codigo_metodo   VARCHAR(15)    NOT NULL CONSTRAINT pk_metodo_pago PRIMARY KEY,   -- TC, TD, EFECTIVO, BILLETERA
    nombre          NVARCHAR(40)   NOT NULL,
    es_tarjeta      BIT            NOT NULL,
    permite_web     BIT            NOT NULL,
    permite_fisico  BIT            NOT NULL
);

IF OBJECT_ID(N'ref.estado_vuelo', N'U') IS NULL
CREATE TABLE ref.estado_vuelo (
    codigo_estado       VARCHAR(15)    NOT NULL CONSTRAINT pk_estado_vuelo PRIMARY KEY,
    descripcion         NVARCHAR(100)  NOT NULL,
    es_estado_inicial   BIT            NOT NULL,
    es_final            BIT            NOT NULL
);

IF OBJECT_ID(N'ref.estado_tiquete', N'U') IS NULL
CREATE TABLE ref.estado_tiquete (
    codigo_estado       VARCHAR(15)    NOT NULL CONSTRAINT pk_estado_tiquete PRIMARY KEY,
    descripcion         NVARCHAR(100)  NOT NULL,
    es_estado_inicial   BIT            NOT NULL,
    es_final            BIT            NOT NULL,
    ocupa_inventario    BIT            NOT NULL        -- 1 = consume una plaza del vuelo
);

IF OBJECT_ID(N'ref.estado_pago', N'U') IS NULL
CREATE TABLE ref.estado_pago (
    codigo_estado       VARCHAR(15)    NOT NULL CONSTRAINT pk_estado_pago PRIMARY KEY,
    descripcion         NVARCHAR(100)  NOT NULL,
    es_estado_inicial   BIT            NOT NULL,
    es_final            BIT            NOT NULL,
    es_cobro            BIT            NOT NULL        -- 1 = el dinero fue recibido (cuenta como cobro)
);

IF OBJECT_ID(N'ref.transicion_vuelo', N'U') IS NULL
CREATE TABLE ref.transicion_vuelo (
    estado_origen   VARCHAR(15) NOT NULL,
    estado_destino  VARCHAR(15) NOT NULL,
    CONSTRAINT pk_transicion_vuelo PRIMARY KEY (estado_origen, estado_destino)
);

IF OBJECT_ID(N'ref.transicion_tiquete', N'U') IS NULL
CREATE TABLE ref.transicion_tiquete (
    estado_origen   VARCHAR(15) NOT NULL,
    estado_destino  VARCHAR(15) NOT NULL,
    CONSTRAINT pk_transicion_tiquete PRIMARY KEY (estado_origen, estado_destino)
);

IF OBJECT_ID(N'ref.transicion_pago', N'U') IS NULL
CREATE TABLE ref.transicion_pago (
    estado_origen   VARCHAR(15) NOT NULL,
    estado_destino  VARCHAR(15) NOT NULL,
    CONSTRAINT pk_transicion_pago PRIMARY KEY (estado_origen, estado_destino)
);

IF OBJECT_ID(N'ref.motivo_cancelacion', N'U') IS NULL
CREATE TABLE ref.motivo_cancelacion (
    codigo_motivo   VARCHAR(15)    NOT NULL CONSTRAINT pk_motivo_cancelacion PRIMARY KEY,
    descripcion     NVARCHAR(150)  NOT NULL,
    iniciado_por    VARCHAR(10)    NOT NULL,       -- CLIENTE, AEROLINEA, SISTEMA
    reembolso_total BIT            NOT NULL
);

IF OBJECT_ID(N'ref.parametro', N'U') IS NULL
CREATE TABLE ref.parametro (
    clave           VARCHAR(40)    NOT NULL CONSTRAINT pk_parametro PRIMARY KEY,
    valor           VARCHAR(100)   NOT NULL,
    tipo_dato       VARCHAR(10)    NOT NULL,
    descripcion     NVARCHAR(200)  NOT NULL
);

IF OBJECT_ID(N'ref.mensaje_error', N'U') IS NULL
CREATE TABLE ref.mensaje_error (
    numero_error    INT            NOT NULL CONSTRAINT pk_mensaje_error PRIMARY KEY,
    mensaje         NVARCHAR(250)  NOT NULL,
    regla           VARCHAR(10)    NULL           -- regla de negocio asociada (RN-xx)
);
GO

/* ================================================================= rh ===== */
IF OBJECT_ID(N'rh.departamento', N'U') IS NULL
CREATE TABLE rh.departamento (
    codigo_departamento VARCHAR(10)   NOT NULL CONSTRAINT pk_departamento PRIMARY KEY,
    nombre              NVARCHAR(60)  NOT NULL
);

IF OBJECT_ID(N'rh.cargo', N'U') IS NULL
CREATE TABLE rh.cargo (
    codigo_cargo            VARCHAR(15)   NOT NULL CONSTRAINT pk_cargo PRIMARY KEY,
    nombre                  NVARCHAR(60)  NOT NULL,
    codigo_departamento     VARCHAR(10)   NOT NULL,
    categoria_tripulacion   VARCHAR(7)    NULL          -- TECNICA (pilotos), CABINA; NULL = personal de tierra
);

IF OBJECT_ID(N'rh.empleado', N'U') IS NULL
CREATE TABLE rh.empleado (
    id_empleado             INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_empleado PRIMARY KEY,
    numero_empleado         CHAR(6)        NOT NULL,
    nombres                 NVARCHAR(60)   NOT NULL,
    apellidos               NVARCHAR(60)   NOT NULL,
    fecha_nacimiento        DATE           NOT NULL,
    email_corporativo       VARCHAR(120)   NOT NULL,
    telefono                VARCHAR(20)    NULL,
    fecha_contratacion      DATE           NOT NULL,
    fecha_terminacion       DATE           NULL,
    codigo_cargo            VARCHAR(15)    NOT NULL,
    id_localizacion_base    INT            NOT NULL,
    id_supervisor           INT            NULL,
    salario_anual_usd       DECIMAL(12,2)  NOT NULL,     -- dato confidencial: no se expone en rpt
    creado_utc              DATETIME2(0)   NOT NULL CONSTRAINT df_empleado_creado DEFAULT (SYSUTCDATETIME())
);
GO

/* ================================================================ ops ===== */
IF OBJECT_ID(N'ops.configuracion_asientos', N'U') IS NULL
CREATE TABLE ops.configuracion_asientos (
    id_configuracion        SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_configuracion_asientos PRIMARY KEY,
    codigo_configuracion    VARCHAR(20)    NOT NULL,
    id_modelo               SMALLINT       NOT NULL,
    descripcion             NVARCHAR(150)  NOT NULL
);

IF OBJECT_ID(N'ops.asiento_configuracion', N'U') IS NULL
CREATE TABLE ops.asiento_configuracion (
    id_configuracion        SMALLINT    NOT NULL,
    codigo_asiento          VARCHAR(4)  NOT NULL,       -- fila + letra, p. ej. 12A
    fila                    TINYINT     NOT NULL,
    letra                   CHAR(1)     NOT NULL,
    codigo_cabina           CHAR(3)     NOT NULL,
    es_ventana              BIT         NOT NULL,
    es_pasillo              BIT         NOT NULL,
    es_salida_emergencia    BIT         NOT NULL CONSTRAINT df_asiento_salida DEFAULT (0),
    CONSTRAINT pk_asiento_configuracion PRIMARY KEY (id_configuracion, codigo_asiento)
);

IF OBJECT_ID(N'ops.avion', N'U') IS NULL
CREATE TABLE ops.avion (
    id_avion                SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_avion PRIMARY KEY,
    matricula               VARCHAR(10)    NOT NULL,     -- registro FAA (N-number), sintético
    numero_serie            VARCHAR(20)    NOT NULL,     -- MSN del fabricante, sintético
    id_configuracion        SMALLINT       NOT NULL,
    fecha_fabricacion       DATE           NOT NULL,
    fecha_incorporacion     DATE           NOT NULL,
    estado_operativo        VARCHAR(15)    NOT NULL CONSTRAINT df_avion_estado DEFAULT ('ACTIVO'),
    id_aeropuerto_base      INT            NOT NULL,
    creado_utc              DATETIME2(0)   NOT NULL CONSTRAINT df_avion_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ops.ruta', N'U') IS NULL
CREATE TABLE ops.ruta (
    id_ruta                 SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_ruta PRIMARY KEY,
    id_aeropuerto_origen    INT            NOT NULL,
    id_aeropuerto_destino   INT            NOT NULL,
    distancia_millas        SMALLINT       NOT NULL,
    activa                  BIT            NOT NULL CONSTRAINT df_ruta_activa DEFAULT (1),
    fecha_inicio_operacion  DATE           NULL,
    creado_utc              DATETIME2(0)   NOT NULL CONSTRAINT df_ruta_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ops.programacion', N'U') IS NULL
CREATE TABLE ops.programacion (
    id_programacion         INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_programacion PRIMARY KEY,
    numero_vuelo            SMALLINT       NOT NULL,
    id_ruta                 SMALLINT       NOT NULL,
    hora_salida_local       TIME(0)        NOT NULL,     -- hora local del aeropuerto de origen
    duracion_programada_min SMALLINT       NOT NULL,
    vigente_desde           DATE           NOT NULL,
    vigente_hasta           DATE           NULL,         -- NULL = sin fecha de fin
    activa                  BIT            NOT NULL CONSTRAINT df_programacion_activa DEFAULT (1),
    creado_utc              DATETIME2(0)   NOT NULL CONSTRAINT df_programacion_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ops.programacion_dia', N'U') IS NULL
CREATE TABLE ops.programacion_dia (
    id_programacion         INT            NOT NULL,
    dia_semana              TINYINT        NOT NULL,     -- ISO 8601: 1 = lunes ... 7 = domingo
    CONSTRAINT pk_programacion_dia PRIMARY KEY (id_programacion, dia_semana)
);

IF OBJECT_ID(N'ops.vuelo', N'U') IS NULL
CREATE TABLE ops.vuelo (
    id_vuelo                INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_vuelo PRIMARY KEY,
    id_programacion         INT                NOT NULL,
    salida_programada       DATETIMEOFFSET(0)  NOT NULL,   -- hora local del origen con su desfase
    llegada_programada      DATETIMEOFFSET(0)  NOT NULL,   -- hora local del destino con su desfase
    fecha_salida_local      AS CAST(salida_programada AS DATE) PERSISTED,   -- fecha operativa del vuelo
    salida_estimada         DATETIMEOFFSET(0)  NULL,       -- solo en demoras
    salida_real             DATETIMEOFFSET(0)  NULL,
    llegada_real            DATETIMEOFFSET(0)  NULL,
    id_avion                SMALLINT           NULL,       -- NULL hasta la asignación
    codigo_estado           VARCHAR(15)        NOT NULL CONSTRAINT df_vuelo_estado DEFAULT ('PROGRAMADO'),
    puerta_salida           VARCHAR(5)         NULL,
    motivo_cancelacion      NVARCHAR(200)      NULL,
    creado_utc              DATETIME2(0)       NOT NULL CONSTRAINT df_vuelo_creado DEFAULT (SYSUTCDATETIME()),
    version_fila            ROWVERSION         NOT NULL    -- control de concurrencia optimista
);

IF OBJECT_ID(N'ops.vuelo_cabina', N'U') IS NULL
CREATE TABLE ops.vuelo_cabina (
    id_vuelo                INT        NOT NULL,
    codigo_cabina           CHAR(3)    NOT NULL,
    capacidad               SMALLINT   NOT NULL,           -- asientos de la cabina en la configuración del avión
    plazas_ocupadas         SMALLINT   NOT NULL CONSTRAINT df_vuelo_cabina_ocupadas DEFAULT (0),  -- mantenido por trigger
    CONSTRAINT pk_vuelo_cabina PRIMARY KEY (id_vuelo, codigo_cabina)
);

IF OBJECT_ID(N'ops.asignacion_tripulacion', N'U') IS NULL
CREATE TABLE ops.asignacion_tripulacion (
    id_vuelo        INT           NOT NULL,
    id_empleado     INT           NOT NULL,
    rol_vuelo       VARCHAR(15)   NOT NULL,     -- CAPITAN, PRIMER_OFICIAL, JEFE_CABINA, AUXILIAR_VUELO
    asignado_utc    DATETIME2(0)  NOT NULL CONSTRAINT df_asignacion_asignado DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT pk_asignacion_tripulacion PRIMARY KEY (id_vuelo, id_empleado)
);
GO

/* ================================================================ ven ===== */
IF OBJECT_ID(N'ven.persona', N'U') IS NULL
CREATE TABLE ven.persona (
    id_persona                  INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_persona PRIMARY KEY,
    nombres                     NVARCHAR(60)   NOT NULL,
    apellidos                   NVARCHAR(60)   NOT NULL,
    fecha_nacimiento            DATE           NULL,     -- obligatorio para pasajeros (trigger)
    genero                      CHAR(1)        NULL,     -- F, M, X (como en el documento de identidad)
    email_contacto              VARCHAR(120)   NULL,
    telefono                    VARCHAR(20)    NULL,
    codigo_pais_nacionalidad    CHAR(2)        NULL,
    tipo_documento              VARCHAR(10)    NULL,
    numero_documento            VARCHAR(20)    NULL,
    codigo_pais_documento       CHAR(2)        NULL,
    creado_utc                  DATETIME2(0)   NOT NULL CONSTRAINT df_persona_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ven.cliente', N'U') IS NULL
CREATE TABLE ven.cliente (                     -- subtipo de persona: cliente registrado
    id_persona                  INT            NOT NULL CONSTRAINT pk_cliente PRIMARY KEY,
    numero_viajero              CHAR(10)       NOT NULL,
    email_acceso                VARCHAR(120)   NOT NULL,
    fecha_registro_utc          DATETIME2(0)   NOT NULL CONSTRAINT df_cliente_registro DEFAULT (SYSUTCDATETIME()),
    nivel_lealtad               VARCHAR(10)    NOT NULL CONSTRAINT df_cliente_nivel DEFAULT ('BASICO'),
    acepta_marketing            BIT            NOT NULL CONSTRAINT df_cliente_marketing DEFAULT (0),
    estado_cuenta               VARCHAR(10)    NOT NULL CONSTRAINT df_cliente_estado DEFAULT ('ACTIVA'),
    id_aeropuerto_preferido     INT            NULL
);

IF OBJECT_ID(N'ven.compra', N'U') IS NULL
CREATE TABLE ven.compra (
    id_compra               INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_compra PRIMARY KEY,
    codigo_reserva          CHAR(6)        NOT NULL,      -- localizador (PNR)
    id_persona_comprador    INT            NOT NULL,
    id_localizacion_venta   INT            NOT NULL,      -- canal: tipo de la localización (AER/OFI = físico, WEB)
    id_empleado_vendedor    INT            NULL,          -- obligatorio en venta física, nulo en web (trigger)
    fecha_compra_utc        DATETIME2(0)   NOT NULL CONSTRAINT df_compra_fecha DEFAULT (SYSUTCDATETIME()),
    email_confirmacion      VARCHAR(120)   NULL
);

IF OBJECT_ID(N'ven.tarifa', N'U') IS NULL
CREATE TABLE ven.tarifa (
    id_tarifa           INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_tarifa PRIMARY KEY,
    id_ruta             SMALLINT       NOT NULL,
    codigo_cabina       CHAR(3)        NOT NULL,
    precio_base_usd     DECIMAL(10,2)  NOT NULL,
    vigente_desde       DATE           NOT NULL,          -- período de venta
    vigente_hasta       DATE           NULL,
    creado_utc          DATETIME2(0)   NOT NULL CONSTRAINT df_tarifa_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ven.descuento', N'U') IS NULL
CREATE TABLE ven.descuento (
    id_descuento                SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_descuento PRIMARY KEY,
    codigo_descuento            VARCHAR(20)    NOT NULL,
    descripcion                 NVARCHAR(150)  NOT NULL,
    porcentaje                  DECIMAL(5,2)   NOT NULL,
    vigente_desde               DATE           NOT NULL,   -- por fecha de compra
    vigente_hasta               DATE           NOT NULL,
    solo_clientes_registrados   BIT            NOT NULL CONSTRAINT df_descuento_registrados DEFAULT (0),
    codigo_cabina               CHAR(3)        NULL,       -- NULL = cualquier cabina
    dias_anticipacion_min       SMALLINT       NULL,       -- NULL = sin requisito de anticipación
    activo                      BIT            NOT NULL CONSTRAINT df_descuento_activo DEFAULT (1),
    creado_utc                  DATETIME2(0)   NOT NULL CONSTRAINT df_descuento_creado DEFAULT (SYSUTCDATETIME())
);

IF OBJECT_ID(N'ven.politica_cancelacion', N'U') IS NULL
CREATE TABLE ven.politica_cancelacion (
    id_politica             SMALLINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_politica_cancelacion PRIMARY KEY,
    codigo_cabina           CHAR(3)        NOT NULL,
    horas_antes_min         SMALLINT       NOT NULL,      -- aplica si faltan al menos estas horas para la salida
    porcentaje_reembolso    DECIMAL(5,2)   NOT NULL
);

IF OBJECT_ID(N'ven.tiquete', N'U') IS NULL
CREATE TABLE ven.tiquete (
    id_tiquete                  INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_tiquete PRIMARY KEY,
    numero_tiquete              CHAR(13)       NOT NULL,      -- 3 dígitos de prefijo + 10 de serie
    id_compra                   INT            NOT NULL,
    id_vuelo                    INT            NOT NULL,
    codigo_cabina               CHAR(3)        NOT NULL,
    id_persona_pasajero         INT            NOT NULL,
    codigo_asiento              VARCHAR(4)     NULL,          -- puede asignarse después de la compra
    id_tarifa                   INT            NOT NULL,
    precio_base_usd             DECIMAL(10,2)  NOT NULL,      -- precio pactado en la venta (hecho histórico)
    id_descuento                SMALLINT       NULL,
    porcentaje_descuento        DECIMAL(5,2)   NOT NULL CONSTRAINT df_tiquete_porcentaje DEFAULT (0),
    monto_descuento_usd         AS CAST(ROUND(precio_base_usd * porcentaje_descuento / 100.0, 2) AS DECIMAL(10,2)) PERSISTED,
    precio_final_usd            AS CAST(precio_base_usd - ROUND(precio_base_usd * porcentaje_descuento / 100.0, 2) AS DECIMAL(10,2)) PERSISTED,
    codigo_estado               VARCHAR(15)    NOT NULL CONSTRAINT df_tiquete_estado DEFAULT ('RESERVADO'),
    fecha_limite_pago_utc       DATETIME2(0)   NOT NULL,
    fecha_emision_utc           DATETIME2(0)   NULL,
    fecha_cancelacion_utc       DATETIME2(0)   NULL,
    codigo_motivo_cancelacion   VARCHAR(15)    NULL,
    creado_utc                  DATETIME2(0)   NOT NULL CONSTRAINT df_tiquete_creado DEFAULT (SYSUTCDATETIME()),
    version_fila                ROWVERSION     NOT NULL
);

IF OBJECT_ID(N'ven.pago', N'U') IS NULL
CREATE TABLE ven.pago (
    id_pago                     INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_pago PRIMARY KEY,
    id_tiquete                  INT            NOT NULL,
    codigo_metodo               VARCHAR(15)    NOT NULL,
    id_localizacion_cobro       INT            NOT NULL,
    monto_usd                   DECIMAL(10,2)  NOT NULL,
    codigo_estado               VARCHAR(15)    NOT NULL CONSTRAINT df_pago_estado DEFAULT ('PENDIENTE'),
    fecha_creacion_utc          DATETIME2(0)   NOT NULL CONSTRAINT df_pago_creacion DEFAULT (SYSUTCDATETIME()),
    fecha_resolucion_utc        DATETIME2(0)   NULL,          -- confirmación, rechazo o anulación
    referencia_autorizacion     VARCHAR(30)    NULL,
    ultimos4_tarjeta            CHAR(4)        NULL,          -- nunca el número completo (minimización de datos)
    marca_tarjeta               VARCHAR(15)    NULL,
    motivo_rechazo              NVARCHAR(100)  NULL
);

IF OBJECT_ID(N'ven.reembolso', N'U') IS NULL
CREATE TABLE ven.reembolso (
    id_reembolso            INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_reembolso PRIMARY KEY,
    id_pago                 INT            NOT NULL,
    monto_usd               DECIMAL(10,2)  NOT NULL,
    fecha_reembolso_utc     DATETIME2(0)   NOT NULL CONSTRAINT df_reembolso_fecha DEFAULT (SYSUTCDATETIME()),
    codigo_motivo           VARCHAR(15)    NOT NULL,
    porcentaje_aplicado     DECIMAL(5,2)   NOT NULL,
    regla_aplicada          VARCHAR(20)    NOT NULL,          -- REEMBOLSO_TOTAL, REGLA_24H, POLITICA_CABINA
    referencia              VARCHAR(30)    NULL
);
GO

/* ================================================================ aud ===== */
IF OBJECT_ID(N'aud.cambio_estado', N'U') IS NULL
CREATE TABLE aud.cambio_estado (
    id_cambio           BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_cambio_estado PRIMARY KEY,
    entidad             VARCHAR(10)    NOT NULL,      -- VUELO, TIQUETE, PAGO
    id_entidad          INT            NOT NULL,
    estado_anterior     VARCHAR(15)    NULL,          -- NULL en la creación
    estado_nuevo        VARCHAR(15)    NOT NULL,
    registrado_utc      DATETIME2(3)   NOT NULL CONSTRAINT df_cambio_estado_registrado DEFAULT (SYSUTCDATETIME()),
    usuario             NVARCHAR(128)  NOT NULL CONSTRAINT df_cambio_estado_usuario DEFAULT (SUSER_SNAME()),
    aplicacion          NVARCHAR(128)  NULL CONSTRAINT df_cambio_estado_aplicacion DEFAULT (APP_NAME())
);
GO

/* ================================================================ tst ===== */
IF OBJECT_ID(N'tst.resultado_prueba', N'U') IS NULL
CREATE TABLE tst.resultado_prueba (
    id_resultado    INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_resultado_prueba PRIMARY KEY,
    id_ejecucion    UNIQUEIDENTIFIER NOT NULL,
    id_prueba       VARCHAR(20)    NOT NULL,
    regla           VARCHAR(20)    NULL,
    descripcion     NVARCHAR(300)  NOT NULL,
    resultado       VARCHAR(10)    NOT NULL,          -- SUPERADA, FALLIDA
    detalle         NVARCHAR(1000) NULL,
    ejecutado_utc   DATETIME2(3)   NOT NULL CONSTRAINT df_resultado_prueba_ejecutado DEFAULT (SYSUTCDATETIME())
);
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '02_esquemas_y_tablas')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('02_esquemas_y_tablas', N'Esquemas, secuencias y tablas');
GO
SET NOEXEC OFF;
GO
