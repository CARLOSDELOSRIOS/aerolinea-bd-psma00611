# Diccionario de datos

Generado por `python -m aerolinea documentar` a partir del catálogo de SQL Server (tipos, nulabilidad, predeterminados, claves, restricciones y enmascaramiento) y de `docs/02_modelo/definiciones_atributos.csv` (definición y dominio de negocio). No editar a mano.

Tablas: 41 · Columnas: 269 · Esquema `stg` (área de carga) excluido.

Convenciones: **PK** clave primaria · **FK** clave foránea · **UQ** restricción única · **UX** índice único (filtrado cuando se indica) · CHECK = restricciones de comprobación que mencionan la columna.

## Esquema `adm`

### `adm.registro_despliegue`

Bitácora de scripts desplegados y cargas aplicadas en la base  
Filas al generar el documento: 12

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_registro | int | No |  | PK |  | IDENTITY | Identificador del registro | Entero autoincremental |
| script | varchar(80) | No |  |  |  |  | Nombre del script o proceso ejecutado | Nombre de archivo sin extensión o CARGA_SINTETICA |
| descripcion | nvarchar(400) | Sí |  |  |  |  | Descripción del despliegue o parámetros de la carga | Texto libre |
| ejecutado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de ejecución | UTC |
| usuario | nvarchar(128) | No | (suser_sname()) |  |  |  | Inicio de sesión que ejecutó el script | SUSER_SNAME() |
| version_motor | nvarchar(128) | No | (CONVERT(nvarchar(128),serverproperty('ProductVersion'))) |  |  |  | Versión del motor en el momento de la ejecución | SERVERPROPERTY('ProductVersion') |

## Esquema `aud`

### `aud.cambio_estado`

Historial técnico de cambios de estado de vuelos, tiquetes y pagos (lo alimentan los triggers)  
Filas al generar el documento: 1.248.064

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_cambio | bigint | No |  | PK |  | IDENTITY | Identificador del cambio | Entero grande autoincremental |
| entidad | varchar(10) | No |  |  | ck_cambio_estado_entidad |  | Tipo de entidad que cambió de estado | VUELO, TIQUETE, PAGO |
| id_entidad | int | No |  |  |  |  | Identificador de la fila que cambió | Clave de la entidad indicada |
| estado_anterior | varchar(15) | Sí |  |  |  |  | Estado previo (NULL en la creación) | Código de estado de la entidad |
| estado_nuevo | varchar(15) | No |  |  |  |  | Estado resultante | Código de estado de la entidad |
| registrado_utc | datetime2(3) | No | (sysutcdatetime()) |  |  |  | Instante en que la base registró el cambio (no la fecha de negocio) | UTC con milisegundos |
| usuario | nvarchar(128) | No | (suser_sname()) |  |  |  | Inicio de sesión que provocó el cambio | SUSER_SNAME() |
| aplicacion | nvarchar(128) | Sí | (app_name()) |  |  |  | Aplicación cliente que provocó el cambio | APP_NAME() |

Restricciones CHECK:

- `ck_cambio_estado_entidad`: `(entidad='PAGO' OR entidad='TIQUETE' OR entidad='VUELO')`

## Esquema `ops`

### `ops.asiento_configuracion`

Asientos de cada configuración de cabina (mapa de asientos)  
Filas al generar el documento: 586

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_configuracion | smallint | No |  | PK; UQ uq_asiento_fila_letra; FK → ops.configuracion_asientos.id_configuracion |  |  | Configuración a la que pertenece el asiento | FK a ops.configuracion_asientos |
| codigo_asiento | varchar(4) | No |  | PK | ck_asiento_codigo |  | Código visible del asiento (fila + letra) | p. ej. 12A |
| fila | tinyint | No |  | UQ uq_asiento_fila_letra | ck_asiento_codigo, ck_asiento_fila_letra |  | Número de fila | 1 a 60 |
| letra | char(1) | No |  | UQ uq_asiento_fila_letra | ck_asiento_codigo, ck_asiento_fila_letra |  | Letra del asiento en la fila | A a K mayúscula |
| codigo_cabina | char(3) | No |  | FK → ref.cabina.codigo_cabina |  |  | Cabina a la que pertenece el asiento | VIP o ECO |
| es_ventana | bit | No |  |  |  |  | Indica asiento de ventana | 0/1 |
| es_pasillo | bit | No |  |  |  |  | Indica asiento de pasillo | 0/1 |
| es_salida_emergencia | bit | No | ((0)) |  |  |  | Indica fila de salida de emergencia | 0/1 |

Restricciones CHECK:

- `ck_asiento_codigo`: `(codigo_asiento=concat(fila,letra))`
- `ck_asiento_fila_letra`: `(fila>=(1) AND fila<=(60) AND (letra) collate Latin1_General_BIN like 'A-K')`

### `ops.asignacion_tripulacion`

Asignación de un empleado de tripulación a un vuelo con un rol  
Filas al generar el documento: 20.064

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_vuelo | int | No |  | PK; UX ux_asignacion_capitan (filtrado: (rol_vuelo='CAPITAN')); UX ux_asignacion_jefe_cabina (filtrado: (rol_vuelo='JEFE_CABINA')); UX ux_asignacion_primer_oficial (filtrado: (rol_vuelo='PRIMER_OFICIAL')); FK → ops.vuelo.id_vuelo |  |  | Vuelo asignado | FK a ops.vuelo |
| id_empleado | int | No |  | PK; FK → rh.empleado.id_empleado |  |  | Tripulante asignado | FK a rh.empleado |
| rol_vuelo | varchar(15) | No |  |  | ck_asignacion_rol |  | Rol que desempeña en el vuelo | CAPITAN, PRIMER_OFICIAL, JEFE_CABINA, AUXILIAR_VUELO |
| asignado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de la asignación | UTC |

Restricciones CHECK:

- `ck_asignacion_rol`: `(rol_vuelo='AUXILIAR_VUELO' OR rol_vuelo='JEFE_CABINA' OR rol_vuelo='PRIMER_OFICIAL' OR rol_vuelo='CAPITAN')`

### `ops.avion`

Aeronave de la flota (datos sintéticos)  
Filas al generar el documento: 17

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_avion | smallint | No |  | PK |  | IDENTITY | Identificador del avión | Entero pequeño autoincremental |
| matricula | varchar(10) | No |  | UQ uq_avion_matricula | ck_avion_matricula |  | Matrícula de registro (N-number) | N + 1-5 caracteres |
| numero_serie | varchar(20) | No |  | UQ uq_avion_numero_serie |  |  | Número de serie del fabricante (MSN) | Sintético |
| id_configuracion | smallint | No |  | FK → ops.configuracion_asientos.id_configuracion |  |  | Configuración de asientos instalada | FK a ops.configuracion_asientos |
| fecha_fabricacion | date | No |  |  | ck_avion_fechas |  | Fecha de fabricación | Fecha |
| fecha_incorporacion | date | No |  |  | ck_avion_fechas |  | Fecha de incorporación a la flota | Igual o posterior a la fabricación |
| estado_operativo | varchar(15) | No | ('ACTIVO') |  | ck_avion_estado |  | Situación operativa del avión | ACTIVO, MANTENIMIENTO, RETIRADO |
| id_aeropuerto_base | int | No |  | FK → ref.aeropuerto.id_localizacion |  |  | Aeropuerto base del avión | FK a ref.aeropuerto |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_avion_estado`: `(estado_operativo='RETIRADO' OR estado_operativo='MANTENIMIENTO' OR estado_operativo='ACTIVO')`
- `ck_avion_fechas`: `(fecha_incorporacion>=fecha_fabricacion)`
- `ck_avion_matricula`: `((matricula) collate Latin1_General_BIN like 'N1-9%' AND (len(matricula)>=(3) AND len(matricula)<=(6)))`

### `ops.configuracion_asientos`

Distribución de cabinas y asientos de un modelo de avión  
Filas al generar el documento: 4

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_configuracion | smallint | No |  | PK |  | IDENTITY | Identificador de la configuración | Entero pequeño autoincremental |
| codigo_configuracion | varchar(20) | No |  | UQ uq_configuracion_codigo |  |  | Código legible de la configuración | Único |
| id_modelo | smallint | No |  | FK → ref.modelo_avion.id_modelo |  |  | Modelo de avión al que corresponde | FK a ref.modelo_avion |
| descripcion | nvarchar(150) | No |  |  |  |  | Resumen de asientos por cabina | Texto |

### `ops.programacion`

Programación recurrente de un número de vuelo sobre una ruta con hora local y vigencia  
Filas al generar el documento: 32

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_programacion | int | No |  | PK |  | IDENTITY | Identificador de la programación | Entero autoincremental |
| numero_vuelo | smallint | No |  | UQ uq_programacion_numero_vigencia | ck_programacion_numero |  | Número comercial del vuelo (se muestra como XX + número) | 1 a 9999 |
| id_ruta | smallint | No |  | FK → ops.ruta.id_ruta |  |  | Ruta que opera | FK a ops.ruta |
| hora_salida_local | time(0) | No |  |  |  |  | Hora prevista de salida en la hora local del origen | Hora sin segundos |
| duracion_programada_min | smallint | No |  |  | ck_programacion_duracion |  | Duración de bloque programada | 20 a 1080 minutos |
| vigente_desde | date | No |  | UQ uq_programacion_numero_vigencia | ck_programacion_vigencia |  | Primer día de vigencia | Fecha local |
| vigente_hasta | date | Sí |  |  | ck_programacion_vigencia |  | Último día de vigencia (NULL = sin fin) | Igual o posterior a vigente_desde |
| activa | bit | No | ((1)) |  |  |  | Indica si la programación genera vuelos | 0/1 |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_programacion_duracion`: `(duracion_programada_min>=(20) AND duracion_programada_min<=(1080))`
- `ck_programacion_numero`: `(numero_vuelo>=(1) AND numero_vuelo<=(9999))`
- `ck_programacion_vigencia`: `(vigente_hasta IS NULL OR vigente_hasta>=vigente_desde)`

### `ops.programacion_dia`

Días de la semana en que opera cada programación (1FN: un día por fila)  
Filas al generar el documento: 220

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_programacion | int | No |  | PK; FK → ops.programacion.id_programacion |  |  | Programación | FK a ops.programacion |
| dia_semana | tinyint | No |  | PK | ck_programacion_dia_semana |  | Día de la semana ISO 8601 | 1 = lunes … 7 = domingo |

Restricciones CHECK:

- `ck_programacion_dia_semana`: `(dia_semana>=(1) AND dia_semana<=(7))`

### `ops.ruta`

Par dirigido origen-destino que la aerolínea puede operar  
Filas al generar el documento: 24

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_ruta | smallint | No |  | PK |  | IDENTITY | Identificador de la ruta | Entero pequeño autoincremental |
| id_aeropuerto_origen | int | No |  | UQ uq_ruta_origen_destino; FK → ref.aeropuerto.id_localizacion | ck_ruta_origen_destino |  | Aeropuerto de salida | FK a ref.aeropuerto |
| id_aeropuerto_destino | int | No |  | UQ uq_ruta_origen_destino; FK → ref.aeropuerto.id_localizacion | ck_ruta_origen_destino |  | Aeropuerto de llegada | FK a ref.aeropuerto |
| distancia_millas | smallint | No |  |  | ck_ruta_distancia |  | Distancia ortodrómica entre aeropuertos | 50 a 6000 millas |
| activa | bit | No | ((1)) |  |  |  | Indica si la ruta está en operación | 0/1 |
| fecha_inicio_operacion | date | Sí |  |  |  |  | Fecha de inicio de operación (NULL si está en evaluación) | Fecha |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_ruta_distancia`: `(distancia_millas>=(50) AND distancia_millas<=(6000))`
- `ck_ruta_origen_destino`: `(id_aeropuerto_origen<>id_aeropuerto_destino)`

### `ops.vuelo`

Ocurrencia de una programación en una fecha concreta  
Filas al generar el documento: 3.588

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_vuelo | int | No |  | PK |  | IDENTITY | Identificador del vuelo | Entero autoincremental |
| id_programacion | int | No |  | UQ uq_vuelo_programacion_fecha; FK → ops.programacion.id_programacion |  |  | Programación que generó el vuelo | FK a ops.programacion |
| salida_programada | datetimeoffset(0) | No |  |  | ck_vuelo_estado_horas, ck_vuelo_horario, ck_vuelo_salida_real |  | Hora programada de salida con el desfase del aeropuerto de origen | datetimeoffset coherente con la zona horaria del origen |
| llegada_programada | datetimeoffset(0) | No |  |  | ck_vuelo_horario |  | Hora programada de llegada con el desfase del aeropuerto de destino | Posterior a la salida |
| fecha_salida_local | date | Sí |  | UQ uq_vuelo_programacion_fecha |  | calculada persistida: (CONVERT(date,salida_programada)) | Fecha operativa (fecha local de salida) | Calculada: CAST(salida_programada AS date) |
| salida_estimada | datetimeoffset(0) | Sí |  |  | ck_vuelo_estado_horas |  | Nueva hora estimada en caso de demora | Posterior a la salida programada |
| salida_real | datetimeoffset(0) | Sí |  |  | ck_vuelo_estado_horas, ck_vuelo_salida_real |  | Hora real de despegue | Desde 30 min antes hasta 24 h después de la programada |
| llegada_real | datetimeoffset(0) | Sí |  |  | ck_vuelo_estado_horas |  | Hora real de aterrizaje | Posterior a la salida real |
| id_avion | smallint | Sí |  | FK → ops.avion.id_avion |  |  | Avión asignado (NULL hasta la asignación) | FK a ops.avion |
| codigo_estado | varchar(15) | No | ('PROGRAMADO') | FK → ref.estado_vuelo.codigo_estado | ck_vuelo_estado_horas |  | Estado del vuelo | PROGRAMADO, DEMORADO, EN_VUELO, ATERRIZADO, CANCELADO |
| puerta_salida | varchar(5) | Sí |  |  |  |  | Puerta de embarque | Texto corto |
| motivo_cancelacion | nvarchar(200) | Sí |  |  | ck_vuelo_estado_horas |  | Motivo informado si el vuelo se cancela | Obligatorio solo en CANCELADO |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de generación del vuelo | UTC |
| version_fila | timestamp | No |  |  |  |  | Versión de fila para control de concurrencia optimista | rowversion automático |

Restricciones CHECK:

- `ck_vuelo_estado_horas`: `(codigo_estado='PROGRAMADO' AND salida_estimada IS NULL AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL OR codigo_estado='DEMORADO' AND salida_estimada>salida_programada AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL OR codigo_estado='EN_VUELO' AND salida_real IS NOT NULL AND llegada_real IS NULL AND motivo_cancelacion IS NULL OR codigo_estado='ATERRIZADO' AND salida_real IS NOT NULL AND llegada_real>salida_real AND motivo_cancelacion IS NULL OR codigo_estado='CANCELADO' AND salida_real IS NULL AND llegada_real IS NULL AND motivo_cancelacion IS NOT NULL)`
- `ck_vuelo_horario`: `(llegada_programada>salida_programada AND (datediff(minute,salida_programada,llegada_programada)>=(20) AND datediff(minute,salida_programada,llegada_programada)<=(1080)))`
- `ck_vuelo_salida_real`: `(salida_real IS NULL OR salida_real>=dateadd(minute,(-30),salida_programada) AND salida_real<=dateadd(hour,(24),salida_programada))`

### `ops.vuelo_cabina`

Inventario por vuelo y cabina: capacidad y plazas ocupadas (desnormalización controlada)  
Filas al generar el documento: 7.176

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_vuelo | int | No |  | PK; FK → ops.vuelo.id_vuelo |  |  | Vuelo | FK a ops.vuelo |
| codigo_cabina | char(3) | No |  | PK; FK → ref.cabina.codigo_cabina |  |  | Cabina | FK a ref.cabina |
| capacidad | smallint | No |  |  | ck_vuelo_cabina_capacidad |  | Asientos de la cabina en la configuración del avión asignado | Mayor que 0 |
| plazas_ocupadas | smallint | No | ((0)) |  | ck_vuelo_cabina_capacidad |  | Tiquetes que ocupan plaza (estados con ocupa_inventario = 1) | 0 a capacidad |

Restricciones CHECK:

- `ck_vuelo_cabina_capacidad`: `(capacidad>(0) AND plazas_ocupadas>=(0) AND plazas_ocupadas<=capacidad)`

## Esquema `ref`

### `ref.aeropuerto`

Subtipo de localización: aeropuerto donde salen y llegan los vuelos  
Filas al generar el documento: 13

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_localizacion | int | No |  | PK; FK → ref.localizacion.id_localizacion |  |  | Localización de la que es subtipo | PK y FK a ref.localizacion |
| tipo_localizacion | char(3) | No |  | FK → ref.localizacion.tipo_localizacion |  | calculada persistida: (CONVERT(char(3),'AER')) | Tipo fijo del subtipo, para la FK compuesta | Calculada: AER |
| codigo_iata | char(3) | No |  | UQ uq_aeropuerto_iata | ck_aeropuerto_iata |  | Código IATA del aeropuerto | 3 letras mayúsculas |
| codigo_icao | char(4) | No |  | UQ uq_aeropuerto_icao | ck_aeropuerto_icao |  | Código OACI (ICAO) del aeropuerto | 4 letras mayúsculas |
| latitud | decimal(9,6) | No |  |  | ck_aeropuerto_coordenadas |  | Latitud geográfica | -90 a 90 grados (WGS 84) |
| longitud | decimal(9,6) | No |  |  | ck_aeropuerto_coordenadas |  | Longitud geográfica | -180 a 180 grados (WGS 84) |
| es_base_operaciones | bit | No | ((0)) |  |  |  | Indica si es base de la aerolínea | 0/1 |

Restricciones CHECK:

- `ck_aeropuerto_coordenadas`: `(latitud>=(-90) AND latitud<=(90) AND (longitud>=(-180) AND longitud<=(180)))`
- `ck_aeropuerto_iata`: `((codigo_iata) collate Latin1_General_BIN like 'A-ZA-ZA-Z')`
- `ck_aeropuerto_icao`: `((codigo_icao) collate Latin1_General_BIN like 'A-ZA-ZA-ZA-Z')`

### `ref.cabina`

Clase de servicio a bordo  
Filas al generar el documento: 2

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_cabina | char(3) | No |  | PK | ck_cabina_codigo |  | Código de cabina | VIP, ECO |
| nombre | nvarchar(40) | No |  | UQ uq_cabina_nombre |  |  | Nombre comercial | Texto único |
| descripcion | nvarchar(200) | No |  |  |  |  | Beneficios de la cabina | Texto |
| piezas_equipaje_bodega | tinyint | No |  |  | ck_cabina_equipaje |  | Piezas de equipaje de bodega incluidas | 0 a 5 |
| peso_max_equipaje_kg | tinyint | No |  |  | ck_cabina_equipaje |  | Peso máximo por pieza | 1 a 50 kg |
| acceso_sala_vip | bit | No |  |  |  |  | Indica acceso a sala VIP | 0/1 |
| orden_abordaje | tinyint | No |  | UQ uq_cabina_orden_abordaje |  |  | Prioridad de abordaje | Entero único |

Restricciones CHECK:

- `ck_cabina_codigo`: `((codigo_cabina) collate Latin1_General_BIN like 'A-ZA-ZA-Z')`
- `ck_cabina_equipaje`: `(piezas_equipaje_bodega<=(5) AND (peso_max_equipaje_kg>=(1) AND peso_max_equipaje_kg<=(50)))`

### `ref.estado_eeuu`

Estados de EE. UU. y Distrito de Columbia  
Filas al generar el documento: 51

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_estado | char(2) | No |  | PK | ck_estado_eeuu_codigo |  | Código postal USPS | 2 letras mayúsculas |
| nombre | nvarchar(40) | No |  | UQ uq_estado_eeuu_nombre |  |  | Nombre del estado | Texto único |

Restricciones CHECK:

- `ck_estado_eeuu_codigo`: `((codigo_estado) collate Latin1_General_BIN like 'A-ZA-Z')`

### `ref.estado_pago`

Catálogo de estados de pago  
Filas al generar el documento: 4

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_estado | varchar(15) | No |  | PK |  |  | Código del estado | PENDIENTE, CONFIRMADO, FALLIDO, ANULADO |
| descripcion | nvarchar(100) | No |  |  |  |  | Significado del estado | Texto |
| es_estado_inicial | bit | No |  |  |  |  | Indica si un pago puede crearse en este estado | 0/1 |
| es_final | bit | No |  |  |  |  | Indica si el estado no admite transiciones | 0/1 |
| es_cobro | bit | No |  |  |  |  | Indica si el pago cuenta como dinero recibido | 0/1 |

### `ref.estado_tiquete`

Catálogo de estados de tiquete  
Filas al generar el documento: 5

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_estado | varchar(15) | No |  | PK |  |  | Código del estado | RESERVADO, EMITIDO, USADO, NO_PRESENTADO, CANCELADO |
| descripcion | nvarchar(100) | No |  |  |  |  | Significado del estado | Texto |
| es_estado_inicial | bit | No |  |  |  |  | Indica si un tiquete puede crearse en este estado | 0/1 |
| es_final | bit | No |  |  |  |  | Indica si el estado no admite transiciones | 0/1 |
| ocupa_inventario | bit | No |  |  |  |  | Indica si el tiquete consume una plaza del vuelo | 0/1 |

### `ref.estado_vuelo`

Catálogo de estados de vuelo  
Filas al generar el documento: 5

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_estado | varchar(15) | No |  | PK |  |  | Código del estado | PROGRAMADO, DEMORADO, EN_VUELO, ATERRIZADO, CANCELADO |
| descripcion | nvarchar(100) | No |  |  |  |  | Significado del estado | Texto |
| es_estado_inicial | bit | No |  |  |  |  | Indica si un vuelo puede crearse en este estado | 0/1 |
| es_final | bit | No |  |  |  |  | Indica si el estado no admite transiciones | 0/1 |

### `ref.localizacion`

Generalización de áreas físicas (aeropuertos y oficinas) y ubicaciones web de venta  
Filas al generar el documento: 19

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_localizacion | int | No |  | PK; UQ uq_localizacion_id_tipo |  | IDENTITY | Identificador de la localización | Entero autoincremental |
| codigo_localizacion | varchar(12) | No |  | UQ uq_localizacion_codigo |  |  | Código interno legible | Único |
| tipo_localizacion | char(3) | No |  | UQ uq_localizacion_id_tipo | ck_localizacion_datos_tipo, ck_localizacion_tipo |  | Tipo de localización | AER aeropuerto, OFI oficina física, WEB canal web |
| nombre | nvarchar(100) | No |  |  |  |  | Nombre de la localización | Texto |
| ciudad | nvarchar(60) | Sí |  |  | ck_localizacion_datos_tipo |  | Ciudad (solo físicas) | Obligatoria en AER y OFI |
| codigo_estado | char(2) | Sí |  | FK → ref.estado_eeuu.codigo_estado | ck_localizacion_datos_tipo |  | Estado de EE. UU. (solo físicas) | FK a ref.estado_eeuu |
| direccion | nvarchar(150) | Sí |  |  | ck_localizacion_datos_tipo |  | Dirección postal (opcional, solo físicas) | Texto |
| codigo_postal | varchar(10) | Sí |  |  | ck_localizacion_codigo_postal, ck_localizacion_datos_tipo |  | Código ZIP (opcional, solo físicas) | 5 dígitos |
| zona_horaria | varchar(50) | Sí |  | FK → ref.zona_horaria.nombre_windows | ck_localizacion_datos_tipo |  | Zona horaria (solo físicas) | FK a ref.zona_horaria |
| url | varchar(200) | Sí |  | UX ux_localizacion_url (filtrado: (url IS NOT NULL)) | ck_localizacion_datos_tipo, ck_localizacion_url |  | Dirección web (solo WEB) | https://… única |
| vende_tiquetes | bit | No | ((1)) |  |  |  | Indica si es canal de venta | 0/1 |
| activa | bit | No | ((1)) |  |  |  | Indica si está en operación | 0/1 |
| fecha_apertura | date | No |  |  |  |  | Fecha de apertura | Fecha |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_localizacion_codigo_postal`: `(codigo_postal IS NULL OR codigo_postal like '0-90-90-90-90-9')`
- `ck_localizacion_datos_tipo`: `((tipo_localizacion='OFI' OR tipo_localizacion='AER') AND ciudad IS NOT NULL AND codigo_estado IS NOT NULL AND zona_horaria IS NOT NULL AND url IS NULL OR tipo_localizacion='WEB' AND url IS NOT NULL AND ciudad IS NULL AND codigo_estado IS NULL AND direccion IS NULL AND codigo_postal IS NULL AND zona_horaria IS NULL)`
- `ck_localizacion_tipo`: `(tipo_localizacion='WEB' OR tipo_localizacion='OFI' OR tipo_localizacion='AER')`
- `ck_localizacion_url`: `(url IS NULL OR url like 'https://_%')`

### `ref.mensaje_error`

Catálogo de errores de negocio lanzados con THROW  
Filas al generar el documento: 89

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| numero_error | int | No |  | PK | ck_mensaje_error_numero |  | Número del error | 50000 a 50999 |
| mensaje | nvarchar(250) | No |  |  |  |  | Descripción del error | Texto |
| regla | varchar(10) | Sí |  |  |  |  | Regla de negocio asociada | RN-xx o SUP-xx |

Restricciones CHECK:

- `ck_mensaje_error_numero`: `(numero_error>=(50000) AND numero_error<=(50999))`

### `ref.metodo_pago`

Medios de pago aceptados  
Filas al generar el documento: 4

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_metodo | varchar(15) | No |  | PK |  |  | Código del medio de pago | TC, TD, EFECTIVO, BILLETERA |
| nombre | nvarchar(40) | No |  | UQ uq_metodo_pago_nombre |  |  | Nombre del medio de pago | Texto único |
| es_tarjeta | bit | No |  |  |  |  | Indica si requiere últimos 4 dígitos y marca | 0/1 |
| permite_web | bit | No |  |  | ck_metodo_pago_canal |  | Indica si se acepta en canales web | 0/1 |
| permite_fisico | bit | No |  |  | ck_metodo_pago_canal |  | Indica si se acepta en puntos físicos | 0/1 |

Restricciones CHECK:

- `ck_metodo_pago_canal`: `(permite_web=(1) OR permite_fisico=(1))`

### `ref.modelo_avion`

Modelos de aeronave de la flota (valores aproximados de referencia)  
Filas al generar el documento: 4

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_modelo | smallint | No |  | PK |  | IDENTITY | Identificador del modelo | Entero pequeño autoincremental |
| fabricante | nvarchar(40) | No |  | UQ uq_modelo_avion |  |  | Fabricante | Texto |
| modelo | nvarchar(40) | No |  | UQ uq_modelo_avion |  |  | Designación del modelo | Único por fabricante |
| alcance_millas | smallint | No |  |  | ck_modelo_avion_datos |  | Alcance aproximado | Mayor que 0 |
| velocidad_crucero_mph | smallint | No |  |  | ck_modelo_avion_datos |  | Velocidad de crucero aproximada | 200 a 700 mph |

Restricciones CHECK:

- `ck_modelo_avion_datos`: `(alcance_millas>(0) AND (velocidad_crucero_mph>=(200) AND velocidad_crucero_mph<=(700)))`

### `ref.motivo_cancelacion`

Causas de cancelación de tiquetes  
Filas al generar el documento: 3

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_motivo | varchar(15) | No |  | PK |  |  | Código de la causa | VOLUNTARIA, VUELO_CANCELADO, VENCIMIENTO |
| descripcion | nvarchar(150) | No |  |  |  |  | Significado | Texto |
| iniciado_por | varchar(10) | No |  |  | ck_motivo_cancelacion_iniciador |  | Quién origina la cancelación | CLIENTE, AEROLINEA, SISTEMA |
| reembolso_total | bit | No |  |  |  |  | Indica si la causa da derecho al 100 % de lo cobrado | 0/1 |

Restricciones CHECK:

- `ck_motivo_cancelacion_iniciador`: `(iniciado_por='SISTEMA' OR iniciado_por='AEROLINEA' OR iniciado_por='CLIENTE')`

### `ref.pais`

Países (ISO 3166-1)  
Filas al generar el documento: 20

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_pais | char(2) | No |  | PK | ck_pais_codigo |  | Código alfa-2 | 2 letras mayúsculas |
| nombre | nvarchar(60) | No |  | UQ uq_pais_nombre |  |  | Nombre del país | Texto único |

Restricciones CHECK:

- `ck_pais_codigo`: `((codigo_pais) collate Latin1_General_BIN like 'A-ZA-Z')`

### `ref.parametro`

Parámetros configurables del negocio  
Filas al generar el documento: 11

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| clave | varchar(40) | No |  | PK |  |  | Nombre del parámetro | Texto en mayúsculas |
| valor | varchar(100) | No |  |  |  |  | Valor como texto | Se convierte según tipo_dato |
| tipo_dato | varchar(10) | No |  |  | ck_parametro_tipo |  | Tipo del valor | INT, DECIMAL, DATE, DATETIME, TEXT |
| descripcion | nvarchar(200) | No |  |  |  |  | Significado y uso | Texto |

Restricciones CHECK:

- `ck_parametro_tipo`: `(tipo_dato='TEXT' OR tipo_dato='DATETIME' OR tipo_dato='DATE' OR tipo_dato='DECIMAL' OR tipo_dato='INT')`

### `ref.transicion_pago`

Transiciones permitidas entre estados de pago (reglas como datos)  
Filas al generar el documento: 3

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| estado_origen | varchar(15) | No |  | PK; FK → ref.estado_pago.codigo_estado |  |  | Estado de partida | FK a ref.estado_pago |
| estado_destino | varchar(15) | No |  | PK; FK → ref.estado_pago.codigo_estado |  |  | Estado de llegada | FK a ref.estado_pago |

### `ref.transicion_tiquete`

Transiciones permitidas entre estados de tiquete  
Filas al generar el documento: 5

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| estado_origen | varchar(15) | No |  | PK; FK → ref.estado_tiquete.codigo_estado |  |  | Estado de partida | FK a ref.estado_tiquete |
| estado_destino | varchar(15) | No |  | PK; FK → ref.estado_tiquete.codigo_estado |  |  | Estado de llegada | FK a ref.estado_tiquete |

### `ref.transicion_vuelo`

Transiciones permitidas entre estados de vuelo  
Filas al generar el documento: 7

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| estado_origen | varchar(15) | No |  | PK; FK → ref.estado_vuelo.codigo_estado |  |  | Estado de partida | FK a ref.estado_vuelo |
| estado_destino | varchar(15) | No |  | PK; FK → ref.estado_vuelo.codigo_estado |  |  | Estado de llegada | FK a ref.estado_vuelo |

### `ref.zona_horaria`

Zonas horarias de EE. UU. usadas por las localizaciones físicas  
Filas al generar el documento: 7

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| nombre_windows | varchar(50) | No |  | PK |  |  | Nombre que acepta AT TIME ZONE en SQL Server | Debe existir en sys.time_zone_info |
| nombre_iana | varchar(50) | No |  |  |  |  | Nombre equivalente IANA (tz database) | Texto |
| descripcion | nvarchar(100) | No |  |  |  |  | Descripción | Texto |
| observa_horario_verano | bit | No |  |  |  |  | Indica si aplica horario de verano | 0/1 (Phoenix y Honolulu: 0) |

## Esquema `rh`

### `rh.cargo`

Puestos de trabajo  
Filas al generar el documento: 11

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_cargo | varchar(15) | No |  | PK |  |  | Código del cargo | Texto en mayúsculas |
| nombre | nvarchar(60) | No |  | UQ uq_cargo_nombre |  |  | Nombre del cargo | Texto único |
| codigo_departamento | varchar(10) | No |  | FK → rh.departamento.codigo_departamento |  |  | Departamento al que pertenece | FK a rh.departamento |
| categoria_tripulacion | varchar(7) | Sí |  |  | ck_cargo_categoria |  | Tipo de tripulación (NULL = personal de tierra) | TECNICA (pilotos) o CABINA |

Restricciones CHECK:

- `ck_cargo_categoria`: `(categoria_tripulacion IS NULL OR (categoria_tripulacion='CABINA' OR categoria_tripulacion='TECNICA'))`

### `rh.departamento`

Unidades organizativas  
Filas al generar el documento: 6

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| codigo_departamento | varchar(10) | No |  | PK |  |  | Código del departamento | Texto corto |
| nombre | nvarchar(60) | No |  | UQ uq_departamento_nombre |  |  | Nombre del departamento | Texto único |

### `rh.empleado`

Personas que trabajan en la aerolínea (datos sintéticos)  
Filas al generar el documento: 353

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_empleado | int | No |  | PK | ck_empleado_supervisor | IDENTITY | Identificador del empleado | Entero autoincremental |
| numero_empleado | char(6) | No |  | UQ uq_empleado_numero | ck_empleado_numero |  | Número de nómina | E + 5 dígitos |
| nombres | nvarchar(60) | No |  |  |  |  | Nombres | Texto Unicode |
| apellidos | nvarchar(60) | No |  |  |  |  | Apellidos | Texto Unicode |
| fecha_nacimiento | date | No |  |  | ck_empleado_mayor_edad |  | Fecha de nacimiento | Mayor de 18 años al contratarse |
| email_corporativo | varchar(120) | No |  | UQ uq_empleado_email | ck_empleado_email |  | Correo corporativo | Único |
| telefono | varchar(20) | Sí |  |  |  |  | Teléfono | Rango ficticio 555-01xx |
| fecha_contratacion | date | No |  |  | ck_empleado_mayor_edad, ck_empleado_terminacion |  | Fecha de ingreso | Fecha |
| fecha_terminacion | date | Sí |  |  | ck_empleado_terminacion |  | Fecha de salida (NULL = activo) | Igual o posterior a la contratación |
| codigo_cargo | varchar(15) | No |  | FK → rh.cargo.codigo_cargo |  |  | Cargo | FK a rh.cargo |
| id_localizacion_base | int | No |  | FK → ref.localizacion.id_localizacion |  |  | Base de trabajo | FK a ref.localizacion |
| id_supervisor | int | Sí |  | FK → rh.empleado.id_empleado | ck_empleado_supervisor |  | Jefe directo | FK a rh.empleado (jerarquía) |
| salario_anual_usd | decimal(12,2) | No |  |  | ck_empleado_salario | enmascarada: default() | Salario anual bruto (confidencial |  enmascarado) |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_empleado_email`: `(email_corporativo like '%_@_%._%')`
- `ck_empleado_mayor_edad`: `(dateadd(year,(18),fecha_nacimiento)<=fecha_contratacion)`
- `ck_empleado_numero`: `((numero_empleado) collate Latin1_General_BIN like 'E0-90-90-90-90-9')`
- `ck_empleado_salario`: `(salario_anual_usd>(0))`
- `ck_empleado_supervisor`: `(id_supervisor IS NULL OR id_supervisor<>id_empleado)`
- `ck_empleado_terminacion`: `(fecha_terminacion IS NULL OR fecha_terminacion>=fecha_contratacion)`

## Esquema `tst`

### `tst.resultado_prueba`

Resultados de las ejecuciones de la suite de pruebas  
Filas al generar el documento: 69

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_resultado | int | No |  | PK |  | IDENTITY | Identificador del resultado | Entero autoincremental |
| id_ejecucion | uniqueidentifier | No |  |  |  |  | Identificador de la ejecución de la suite | GUID |
| id_prueba | varchar(20) | No |  |  |  |  | Identificador de la prueba | PR-xx |
| regla | varchar(20) | Sí |  |  |  |  | Regla verificada | RN-xx, SUP-xx u otro |
| descripcion | nvarchar(300) | No |  |  |  |  | Qué se prueba | Texto |
| resultado | varchar(10) | No |  |  | ck_resultado_prueba_resultado |  | Resultado observado | SUPERADA, FALLIDA |
| detalle | nvarchar(1000) | Sí |  |  |  |  | Valores observados | Texto |
| ejecutado_utc | datetime2(3) | No | (sysutcdatetime()) |  |  |  | Instante de ejecución | UTC |

Restricciones CHECK:

- `ck_resultado_prueba_resultado`: `(resultado='FALLIDA' OR resultado='SUPERADA')`

## Esquema `ven`

### `ven.cliente`

Subtipo de persona: cliente registrado con cuenta  
Filas al generar el documento: 30.000

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_persona | int | No |  | PK; FK → ven.persona.id_persona |  |  | Persona registrada | PK y FK a ven.persona (relación 1:0..1) |
| numero_viajero | char(10) | No |  | UQ uq_cliente_numero_viajero | ck_cliente_numero_viajero |  | Número de viajero frecuente | VF + 8 dígitos |
| email_acceso | varchar(120) | No |  | UQ uq_cliente_email_acceso | ck_cliente_email | enmascarada: email() | Correo de inicio de sesión (enmascarado) | Único |
| fecha_registro_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de creación de la cuenta | UTC |
| nivel_lealtad | varchar(10) | No | ('BASICO') |  | ck_cliente_nivel |  | Nivel del programa de clientes | BASICO, PLATA, ORO, PLATINO |
| acepta_marketing | bit | No | ((0)) |  |  |  | Consentimiento de comunicaciones comerciales | 0/1 |
| estado_cuenta | varchar(10) | No | ('ACTIVA') |  | ck_cliente_estado |  | Estado de la cuenta | ACTIVA, SUSPENDIDA, CERRADA |
| id_aeropuerto_preferido | int | Sí |  | FK → ref.aeropuerto.id_localizacion |  |  | Aeropuerto preferido (opcional) | FK a ref.aeropuerto |

Restricciones CHECK:

- `ck_cliente_email`: `(email_acceso like '%_@_%._%')`
- `ck_cliente_estado`: `(estado_cuenta='CERRADA' OR estado_cuenta='SUSPENDIDA' OR estado_cuenta='ACTIVA')`
- `ck_cliente_nivel`: `(nivel_lealtad='PLATINO' OR nivel_lealtad='ORO' OR nivel_lealtad='PLATA' OR nivel_lealtad='BASICO')`
- `ck_cliente_numero_viajero`: `((numero_viajero) collate Latin1_General_BIN like 'VF0-90-90-90-90-90-90-90-9')`

### `ven.compra`

Transacción de venta: un comprador, un canal y uno o más tiquetes  
Filas al generar el documento: 168.928

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_compra | int | No |  | PK |  | IDENTITY | Identificador de la compra | Entero autoincremental |
| codigo_reserva | char(6) | No |  | UQ uq_compra_codigo_reserva | ck_compra_codigo_reserva |  | Localizador (PNR) | 6 caracteres A-Z y 2-9 sin O, I, 0 ni 1 |
| id_persona_comprador | int | No |  | FK → ven.persona.id_persona |  |  | Persona que compra (registrada o no) | FK a ven.persona |
| id_localizacion_venta | int | No |  | FK → ref.localizacion.id_localizacion |  |  | Canal de venta | FK a ref.localizacion con vende_tiquetes = 1 |
| id_empleado_vendedor | int | Sí |  | FK → rh.empleado.id_empleado |  |  | Agente que vendió (solo venta física) | FK a rh.empleado |
| fecha_compra_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de la compra | UTC |
| email_confirmacion | varchar(120) | Sí |  |  |  |  | Correo al que se envió la confirmación | Texto |

Restricciones CHECK:

- `ck_compra_codigo_reserva`: `(len(codigo_reserva)=(6) AND NOT (codigo_reserva) collate Latin1_General_BIN like '%^A-Z0-9%')`

### `ven.descuento`

Descuentos porcentuales sobre el precio original  
Filas al generar el documento: 6

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_descuento | smallint | No |  | PK |  | IDENTITY | Identificador del descuento | Entero pequeño autoincremental |
| codigo_descuento | varchar(20) | No |  | UQ uq_descuento_codigo |  |  | Código promocional | Único |
| descripcion | nvarchar(150) | No |  |  |  |  | Descripción de la campaña | Texto |
| porcentaje | decimal(5,2) | No |  |  | ck_descuento_porcentaje |  | Porcentaje sobre el precio base | Mayor que 0 y hasta 100 |
| vigente_desde | date | No |  |  | ck_descuento_vigencia |  | Primer día de venta en que aplica | Fecha (UTC) |
| vigente_hasta | date | No |  |  | ck_descuento_vigencia |  | Último día de venta en que aplica | Igual o posterior a vigente_desde |
| solo_clientes_registrados | bit | No | ((0)) |  |  |  | Exige que el comprador tenga cuenta | 0/1 |
| codigo_cabina | char(3) | Sí |  | FK → ref.cabina.codigo_cabina |  |  | Cabina a la que se limita (NULL = cualquiera) | FK a ref.cabina |
| dias_anticipacion_min | smallint | Sí |  |  | ck_descuento_anticipacion |  | Días mínimos entre venta y vuelo (NULL = sin requisito) | 0 a 365 |
| activo | bit | No | ((1)) |  |  |  | Indica si puede aplicarse | 0/1 |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_descuento_anticipacion`: `(dias_anticipacion_min IS NULL OR dias_anticipacion_min>=(0) AND dias_anticipacion_min<=(365))`
- `ck_descuento_porcentaje`: `(porcentaje>(0) AND porcentaje<=(100))`
- `ck_descuento_vigencia`: `(vigente_hasta>=vigente_desde)`

### `ven.pago`

Movimiento de cobro asociado a un tiquete (uno o más por tiquete)  
Filas al generar el documento: 388.003

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_pago | int | No |  | PK |  | IDENTITY | Identificador del pago | Entero autoincremental |
| id_tiquete | int | No |  | FK → ven.tiquete.id_tiquete |  |  | Tiquete que se paga | FK a ven.tiquete |
| codigo_metodo | varchar(15) | No |  | FK → ref.metodo_pago.codigo_metodo | ck_pago_tarjeta |  | Medio de pago | FK a ref.metodo_pago |
| id_localizacion_cobro | int | No |  | FK → ref.localizacion.id_localizacion |  |  | Lugar donde se cobró | FK a ref.localizacion |
| monto_usd | decimal(10,2) | No |  |  | ck_pago_monto |  | Importe del pago | Mayor que 0 USD |
| codigo_estado | varchar(15) | No | ('PENDIENTE') | FK → ref.estado_pago.codigo_estado | ck_pago_estado_datos |  | Estado del pago | PENDIENTE, CONFIRMADO, FALLIDO, ANULADO |
| fecha_creacion_utc | datetime2(0) | No | (sysutcdatetime()) |  | ck_pago_fechas |  | Instante del intento de pago | UTC |
| fecha_resolucion_utc | datetime2(0) | Sí |  |  | ck_pago_estado_datos, ck_pago_fechas |  | Instante de confirmación, rechazo o anulación | UTC |
| referencia_autorizacion | varchar(30) | Sí |  |  | ck_pago_estado_datos |  | Código de autorización de la pasarela | Obligatorio si está confirmado |
| ultimos4_tarjeta | char(4) | Sí |  |  | ck_pago_tarjeta, ck_pago_ultimos4 |  | Últimos 4 dígitos de la tarjeta (nunca el número completo) | 4 dígitos |
| marca_tarjeta | varchar(15) | Sí |  |  | ck_pago_marca, ck_pago_tarjeta |  | Marca de la tarjeta | VISA, MASTERCARD, AMEX, DISCOVER |
| motivo_rechazo | nvarchar(100) | Sí |  |  | ck_pago_estado_datos |  | Causa informada del rechazo | Obligatorio si falló |

Restricciones CHECK:

- `ck_pago_estado_datos`: `(codigo_estado='PENDIENTE' AND fecha_resolucion_utc IS NULL AND motivo_rechazo IS NULL OR codigo_estado='CONFIRMADO' AND fecha_resolucion_utc IS NOT NULL AND referencia_autorizacion IS NOT NULL AND motivo_rechazo IS NULL OR codigo_estado='FALLIDO' AND fecha_resolucion_utc IS NOT NULL AND motivo_rechazo IS NOT NULL OR codigo_estado='ANULADO' AND fecha_resolucion_utc IS NOT NULL)`
- `ck_pago_fechas`: `(fecha_resolucion_utc IS NULL OR fecha_resolucion_utc>=fecha_creacion_utc)`
- `ck_pago_marca`: `(marca_tarjeta IS NULL OR (marca_tarjeta='DISCOVER' OR marca_tarjeta='AMEX' OR marca_tarjeta='MASTERCARD' OR marca_tarjeta='VISA'))`
- `ck_pago_monto`: `(monto_usd>(0))`
- `ck_pago_tarjeta`: `((codigo_metodo='TD' OR codigo_metodo='TC') AND ultimos4_tarjeta IS NOT NULL AND marca_tarjeta IS NOT NULL OR NOT (codigo_metodo='TD' OR codigo_metodo='TC') AND ultimos4_tarjeta IS NULL AND marca_tarjeta IS NULL)`
- `ck_pago_ultimos4`: `(ultimos4_tarjeta IS NULL OR ultimos4_tarjeta like '0-90-90-90-9')`

### `ven.persona`

Individuo identificado en una compra: comprador o pasajero  
Filas al generar el documento: 232.096

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_persona | int | No |  | PK |  | IDENTITY | Identificador de la persona | Entero autoincremental |
| nombres | nvarchar(60) | No |  |  |  |  | Nombres como en el documento | Texto Unicode |
| apellidos | nvarchar(60) | No |  |  |  |  | Apellidos como en el documento | Texto Unicode |
| fecha_nacimiento | date | Sí |  |  | ck_persona_fecha_nacimiento | enmascarada: default() | Fecha de nacimiento (obligatoria para pasajeros |  enmascarada) |
| genero | char(1) | Sí |  |  | ck_persona_genero |  | Género como figura en el documento (obligatorio para pasajeros) | F, M, X |
| email_contacto | varchar(120) | Sí |  |  | ck_persona_email | enmascarada: email() | Correo de contacto (enmascarado) | Formato de correo |
| telefono | varchar(20) | Sí |  |  |  | enmascarada: partial(0, "XXX-XXX-", 4) | Teléfono de contacto (enmascarado) | Texto |
| codigo_pais_nacionalidad | char(2) | Sí |  | FK → ref.pais.codigo_pais |  |  | Nacionalidad | FK a ref.pais |
| tipo_documento | varchar(10) | Sí |  |  | ck_persona_documento |  | Tipo de documento de identidad | PASAPORTE, LICENCIA, ID_ESTATAL |
| numero_documento | varchar(20) | Sí |  |  | ck_persona_documento | enmascarada: partial(0, "XXXXXX", 3) | Número del documento (enmascarado) | Obligatorio si hay tipo de documento |
| codigo_pais_documento | char(2) | Sí |  | FK → ref.pais.codigo_pais | ck_persona_documento |  | País emisor del documento | FK a ref.pais |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  | ck_persona_fecha_nacimiento |  | Instante de alta de la persona | UTC |

Restricciones CHECK:

- `ck_persona_documento`: `(tipo_documento IS NULL AND numero_documento IS NULL AND codigo_pais_documento IS NULL OR (tipo_documento='ID_ESTATAL' OR tipo_documento='LICENCIA' OR tipo_documento='PASAPORTE') AND numero_documento IS NOT NULL AND codigo_pais_documento IS NOT NULL)`
- `ck_persona_email`: `(email_contacto IS NULL OR email_contacto like '%_@_%._%')`
- `ck_persona_fecha_nacimiento`: `(fecha_nacimiento IS NULL OR fecha_nacimiento>='19000101' AND fecha_nacimiento<=CONVERT(date,creado_utc))`
- `ck_persona_genero`: `(genero IS NULL OR (genero='X' OR genero='M' OR genero='F'))`

### `ven.politica_cancelacion`

Porcentaje de reembolso por cabina según las horas que faltan para la salida  
Filas al generar el documento: 6

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_politica | smallint | No |  | PK |  | IDENTITY | Identificador del tramo de la política | Entero pequeño autoincremental |
| codigo_cabina | char(3) | No |  | UQ uq_politica_cabina_horas; FK → ref.cabina.codigo_cabina |  |  | Cabina | FK a ref.cabina |
| horas_antes_min | smallint | No |  | UQ uq_politica_cabina_horas | ck_politica_valores |  | Horas mínimas antes de la salida para aplicar el tramo | 0 o más |
| porcentaje_reembolso | decimal(5,2) | No |  |  | ck_politica_valores |  | Porcentaje de lo cobrado que se reembolsa | 0 a 100 |

Restricciones CHECK:

- `ck_politica_valores`: `(horas_antes_min>=(0) AND (porcentaje_reembolso>=(0) AND porcentaje_reembolso<=(100)))`

### `ven.reembolso`

Devolución de dinero sobre un pago confirmado de un tiquete cancelado  
Filas al generar el documento: 18.182

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_reembolso | int | No |  | PK |  | IDENTITY | Identificador del reembolso | Entero autoincremental |
| id_pago | int | No |  | FK → ven.pago.id_pago |  |  | Pago que se reembolsa | FK a ven.pago (confirmado) |
| monto_usd | decimal(10,2) | No |  |  | ck_reembolso_valores |  | Importe devuelto | Mayor que 0 |
| fecha_reembolso_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante del reembolso | No anterior a la cancelación |
| codigo_motivo | varchar(15) | No |  | FK → ref.motivo_cancelacion.codigo_motivo |  |  | Causa de la cancelación | Igual al motivo del tiquete |
| porcentaje_aplicado | decimal(5,2) | No |  |  | ck_reembolso_valores |  | Porcentaje de la política aplicado | Mayor que 0 y hasta 100 |
| regla_aplicada | varchar(20) | No |  |  | ck_reembolso_regla |  | Regla que determinó el porcentaje | REEMBOLSO_TOTAL, REGLA_24H, POLITICA_CABINA |
| referencia | varchar(30) | Sí |  |  |  |  | Referencia del movimiento | Texto |

Restricciones CHECK:

- `ck_reembolso_regla`: `(regla_aplicada='POLITICA_CABINA' OR regla_aplicada='REGLA_24H' OR regla_aplicada='REEMBOLSO_TOTAL')`
- `ck_reembolso_valores`: `(monto_usd>(0) AND porcentaje_aplicado>(0) AND porcentaje_aplicado<=(100))`

### `ven.tarifa`

Precio base por ruta y cabina en un período de venta (versionado)  
Filas al generar el documento: 96

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_tarifa | int | No |  | PK; UQ uq_tarifa_id_cabina |  | IDENTITY | Identificador de la versión de tarifa | Entero autoincremental |
| id_ruta | smallint | No |  | UQ uq_tarifa_ruta_cabina_desde; FK → ops.ruta.id_ruta |  |  | Ruta | FK a ops.ruta |
| codigo_cabina | char(3) | No |  | UQ uq_tarifa_id_cabina; UQ uq_tarifa_ruta_cabina_desde; FK → ref.cabina.codigo_cabina |  |  | Cabina | FK a ref.cabina |
| precio_base_usd | decimal(10,2) | No |  |  | ck_tarifa_precio |  | Precio base antes de descuentos | Mayor que 0 USD |
| vigente_desde | date | No |  | UQ uq_tarifa_ruta_cabina_desde | ck_tarifa_vigencia |  | Primer día de venta | Fecha (UTC) |
| vigente_hasta | date | Sí |  |  | ck_tarifa_vigencia |  | Último día de venta (NULL = abierta) | Igual o posterior a vigente_desde |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  |  |  | Instante de alta del registro | UTC |

Restricciones CHECK:

- `ck_tarifa_precio`: `(precio_base_usd>(0))`
- `ck_tarifa_vigencia`: `(vigente_hasta IS NULL OR vigente_hasta>=vigente_desde)`

### `ven.tiquete`

Derecho de un pasajero a viajar en un vuelo y cabina (un tramo)  
Filas al generar el documento: 323.718

| Columna | Tipo | Nulo | Predeterminado | Claves | CHECK | Notas | Definición | Dominio |
|---|---|---|---|---|---|---|---|---|
| id_tiquete | int | No |  | PK |  | IDENTITY | Identificador del tiquete | Entero autoincremental |
| numero_tiquete | char(13) | No |  | UQ uq_tiquete_numero | ck_tiquete_numero |  | Número del documento de transporte | 13 dígitos (prefijo ficticio 000) |
| id_compra | int | No |  | FK → ven.compra.id_compra |  |  | Compra a la que pertenece | FK a ven.compra |
| id_vuelo | int | No |  | UX ux_tiquete_vuelo_asiento (filtrado: (codigo_asiento IS NOT NULL AND (codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO')))); UX ux_tiquete_vuelo_pasajero (filtrado: (codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO'))); FK → ops.vuelo_cabina.id_vuelo |  |  | Vuelo | FK compuesta (id_vuelo, codigo_cabina) a ops.vuelo_cabina |
| codigo_cabina | char(3) | No |  | FK → ven.tarifa.codigo_cabina; FK → ops.vuelo_cabina.codigo_cabina |  |  | Cabina | VIP o ECO |
| id_persona_pasajero | int | No |  | UX ux_tiquete_vuelo_pasajero (filtrado: (codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO'))); FK → ven.persona.id_persona |  |  | Pasajero (registrado o no) | FK a ven.persona |
| codigo_asiento | varchar(4) | Sí |  | UX ux_tiquete_vuelo_asiento (filtrado: (codigo_asiento IS NOT NULL AND (codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO')))) |  |  | Asiento asignado (opcional al comprar) | Debe existir en la configuración del avión y en la cabina |
| id_tarifa | int | No |  | FK → ven.tarifa.id_tarifa |  |  | Versión de tarifa aplicada | FK compuesta (id_tarifa, codigo_cabina) a ven.tarifa |
| precio_base_usd | decimal(10,2) | No |  |  | ck_tiquete_precio |  | Precio base pactado en la venta (hecho histórico) | Igual al de la tarifa vigente en la venta |
| id_descuento | smallint | Sí |  | FK → ven.descuento.id_descuento | ck_tiquete_descuento |  | Descuento aplicado (como máximo uno) | FK a ven.descuento |
| porcentaje_descuento | decimal(5,2) | No | ((0)) |  | ck_tiquete_descuento |  | Porcentaje aplicado en la venta (copia histórica) | 0 sin descuento |
| monto_descuento_usd | decimal(10,2) | Sí |  |  |  | calculada persistida: (CONVERT(decimal(10,2),round((precio_base_usd*porcentaje_descuento)/(100.0),(2)))) | Importe descontado | Calculada: ROUND(base × % / 100, 2) |
| precio_final_usd | decimal(10,2) | Sí |  |  |  | calculada persistida: (CONVERT(decimal(10,2),precio_base_usd-round((precio_base_usd*porcentaje_descuento)/(100.0),(2)))) | Importe a pagar | Calculada: base − descuento |
| codigo_estado | varchar(15) | No | ('RESERVADO') | FK → ref.estado_tiquete.codigo_estado | ck_tiquete_cancelacion, ck_tiquete_emision |  | Estado del tiquete | RESERVADO, EMITIDO, USADO, NO_PRESENTADO, CANCELADO |
| fecha_limite_pago_utc | datetime2(0) | No |  |  | ck_tiquete_fechas |  | Vencimiento de la reserva | Mínimo entre venta + 72 h y salida − 3 h |
| fecha_emision_utc | datetime2(0) | Sí |  |  | ck_tiquete_emision, ck_tiquete_fechas |  | Instante en que quedó pagado | Obligatoria en EMITIDO, USADO y NO_PRESENTADO |
| fecha_cancelacion_utc | datetime2(0) | Sí |  |  | ck_tiquete_cancelacion, ck_tiquete_fechas |  | Instante de cancelación | Obligatoria solo en CANCELADO |
| codigo_motivo_cancelacion | varchar(15) | Sí |  | FK → ref.motivo_cancelacion.codigo_motivo | ck_tiquete_cancelacion |  | Causa de la cancelación | FK a ref.motivo_cancelacion |
| creado_utc | datetime2(0) | No | (sysutcdatetime()) |  | ck_tiquete_fechas |  | Instante de la venta del tiquete | UTC |
| version_fila | timestamp | No |  |  |  |  | Versión de fila para control de concurrencia optimista | rowversion automático |

Restricciones CHECK:

- `ck_tiquete_cancelacion`: `(codigo_estado='CANCELADO' AND fecha_cancelacion_utc IS NOT NULL AND codigo_motivo_cancelacion IS NOT NULL OR codigo_estado<>'CANCELADO' AND fecha_cancelacion_utc IS NULL AND codigo_motivo_cancelacion IS NULL)`
- `ck_tiquete_descuento`: `(id_descuento IS NULL AND porcentaje_descuento=(0) OR id_descuento IS NOT NULL AND porcentaje_descuento>(0) AND porcentaje_descuento<=(100))`
- `ck_tiquete_emision`: `((codigo_estado='NO_PRESENTADO' OR codigo_estado='USADO' OR codigo_estado='EMITIDO') AND fecha_emision_utc IS NOT NULL OR codigo_estado='RESERVADO' AND fecha_emision_utc IS NULL OR codigo_estado='CANCELADO')`
- `ck_tiquete_fechas`: `(fecha_limite_pago_utc>creado_utc AND (fecha_emision_utc IS NULL OR fecha_emision_utc>=creado_utc) AND (fecha_cancelacion_utc IS NULL OR fecha_cancelacion_utc>=creado_utc))`
- `ck_tiquete_numero`: `(len(numero_tiquete)=(13) AND NOT numero_tiquete like '%^0-9%')`
- `ck_tiquete_precio`: `(precio_base_usd>(0))`
