/* =============================================================================
   09_datos_referencia.sql
   Propósito : catálogos, red, flota, programación, tarifas, descuentos,
               políticas y empleados. Son datos maestros, no transacciones.
   Fuentes   : códigos IATA/ICAO, nombres, coordenadas y zonas horarias de los
               aeropuertos son datos públicos. Matrículas, números de serie,
               configuraciones de cabina, horarios, precios, descuentos,
               políticas y empleados son SINTÉTICOS y no representan a ninguna
               aerolínea real. El designador "XX" y el dominio
               "aerolinea-ejemplo.test" son ficticios (.test está reservado,
               RFC 2606); los teléfonos usan el rango 555-01xx reservado para
               ficción.
   Reinicio  : idempotente: cada fila se inserta solo si su clave natural no
               existe. No actualiza filas existentes.
   Depende de: 08_seguridad.sql
   ============================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ======================================================== CATÁLOGOS ====== */
INSERT ref.pais (codigo_pais, nombre)
SELECT v.codigo, v.nombre
FROM (VALUES ('US', N'Estados Unidos'), ('MX', N'México'), ('CA', N'Canadá'), ('CO', N'Colombia'), ('PE', N'Perú'),
             ('ES', N'España'), ('GB', N'Reino Unido'), ('DE', N'Alemania'), ('BR', N'Brasil'), ('AR', N'Argentina'),
             ('CL', N'Chile'), ('FR', N'Francia'), ('JP', N'Japón'), ('IN', N'India'), ('CN', N'China'),
             ('PH', N'Filipinas'), ('KR', N'Corea del Sur'), ('DO', N'República Dominicana'), ('EC', N'Ecuador'),
             ('VE', N'Venezuela')) AS v (codigo, nombre)
WHERE NOT EXISTS (SELECT 1 FROM ref.pais AS p WHERE p.codigo_pais = v.codigo);

INSERT ref.estado_eeuu (codigo_estado, nombre)
SELECT v.codigo, v.nombre
FROM (VALUES ('AL', N'Alabama'), ('AK', N'Alaska'), ('AZ', N'Arizona'), ('AR', N'Arkansas'), ('CA', N'California'),
             ('CO', N'Colorado'), ('CT', N'Connecticut'), ('DE', N'Delaware'), ('DC', N'District of Columbia'),
             ('FL', N'Florida'), ('GA', N'Georgia'), ('HI', N'Hawaii'), ('ID', N'Idaho'), ('IL', N'Illinois'),
             ('IN', N'Indiana'), ('IA', N'Iowa'), ('KS', N'Kansas'), ('KY', N'Kentucky'), ('LA', N'Louisiana'),
             ('ME', N'Maine'), ('MD', N'Maryland'), ('MA', N'Massachusetts'), ('MI', N'Michigan'), ('MN', N'Minnesota'),
             ('MS', N'Mississippi'), ('MO', N'Missouri'), ('MT', N'Montana'), ('NE', N'Nebraska'), ('NV', N'Nevada'),
             ('NH', N'New Hampshire'), ('NJ', N'New Jersey'), ('NM', N'New Mexico'), ('NY', N'New York'),
             ('NC', N'North Carolina'), ('ND', N'North Dakota'), ('OH', N'Ohio'), ('OK', N'Oklahoma'), ('OR', N'Oregon'),
             ('PA', N'Pennsylvania'), ('RI', N'Rhode Island'), ('SC', N'South Carolina'), ('SD', N'South Dakota'),
             ('TN', N'Tennessee'), ('TX', N'Texas'), ('UT', N'Utah'), ('VT', N'Vermont'), ('VA', N'Virginia'),
             ('WA', N'Washington'), ('WV', N'West Virginia'), ('WI', N'Wisconsin'), ('WY', N'Wyoming')) AS v (codigo, nombre)
WHERE NOT EXISTS (SELECT 1 FROM ref.estado_eeuu AS e WHERE e.codigo_estado = v.codigo);

INSERT ref.zona_horaria (nombre_windows, nombre_iana, descripcion, observa_horario_verano)
SELECT v.w, v.i, v.d, v.dst
FROM (VALUES ('Eastern Standard Time',     'America/New_York',    N'Hora del Este (ET)', 1),
             ('Central Standard Time',     'America/Chicago',     N'Hora del Centro (CT)', 1),
             ('Mountain Standard Time',    'America/Denver',      N'Hora de la Montaña (MT)', 1),
             ('US Mountain Standard Time', 'America/Phoenix',     N'Hora de la Montaña sin horario de verano (Arizona)', 0),
             ('Pacific Standard Time',     'America/Los_Angeles', N'Hora del Pacífico (PT)', 1),
             ('Alaskan Standard Time',     'America/Anchorage',   N'Hora de Alaska (AKT)', 1),
             ('Hawaiian Standard Time',    'Pacific/Honolulu',    N'Hora de Hawái-Aleutianas sin horario de verano', 0)) AS v (w, i, d, dst)
WHERE NOT EXISTS (SELECT 1 FROM ref.zona_horaria AS z WHERE z.nombre_windows = v.w);

INSERT ref.cabina (codigo_cabina, nombre, descripcion, piezas_equipaje_bodega, peso_max_equipaje_kg, acceso_sala_vip, orden_abordaje)
SELECT v.c, v.n, v.d, v.p, v.k, v.s, v.o
FROM (VALUES ('VIP', N'Cabina VIP', N'Asientos amplios, embarque prioritario, comida a bordo y acceso a sala VIP', 2, 32, 1, 1),
             ('ECO', N'Cabina económica', N'Asiento estándar; equipaje de bodega con cargo adicional', 0, 23, 0, 2)) AS v (c, n, d, p, k, s, o)
WHERE NOT EXISTS (SELECT 1 FROM ref.cabina AS c WHERE c.codigo_cabina = v.c);

INSERT ref.metodo_pago (codigo_metodo, nombre, es_tarjeta, permite_web, permite_fisico)
SELECT v.c, v.n, v.t, v.w, v.f
FROM (VALUES ('TC', N'Tarjeta de crédito', 1, 1, 1), ('TD', N'Tarjeta de débito', 1, 1, 1),
             ('EFECTIVO', N'Efectivo', 0, 0, 1), ('BILLETERA', N'Billetera digital', 0, 1, 1)) AS v (c, n, t, w, f)
WHERE NOT EXISTS (SELECT 1 FROM ref.metodo_pago AS m WHERE m.codigo_metodo = v.c);

INSERT ref.estado_vuelo (codigo_estado, descripcion, es_estado_inicial, es_final)
SELECT v.c, v.d, v.i, v.f
FROM (VALUES ('PROGRAMADO', N'Vuelo generado, aún no ha salido', 1, 0),
             ('DEMORADO',   N'Salida retrasada respecto de la hora programada', 0, 0),
             ('EN_VUELO',   N'Vuelo en el aire', 0, 0),
             ('ATERRIZADO', N'Vuelo completado', 0, 1),
             ('CANCELADO',  N'Vuelo cancelado por la aerolínea', 0, 1)) AS v (c, d, i, f)
WHERE NOT EXISTS (SELECT 1 FROM ref.estado_vuelo AS e WHERE e.codigo_estado = v.c);

INSERT ref.estado_tiquete (codigo_estado, descripcion, es_estado_inicial, es_final, ocupa_inventario)
SELECT v.c, v.d, v.i, v.f, v.o
FROM (VALUES ('RESERVADO',     N'Plaza retenida; pago pendiente o parcial', 1, 0, 1),
             ('EMITIDO',       N'Pagado en su totalidad', 0, 0, 1),
             ('USADO',         N'El pasajero voló', 0, 1, 1),
             ('NO_PRESENTADO', N'El pasajero no se presentó', 0, 1, 1),
             ('CANCELADO',     N'Tiquete cancelado; la plaza se libera', 0, 1, 0)) AS v (c, d, i, f, o)
WHERE NOT EXISTS (SELECT 1 FROM ref.estado_tiquete AS e WHERE e.codigo_estado = v.c);

INSERT ref.estado_pago (codigo_estado, descripcion, es_estado_inicial, es_final, es_cobro)
SELECT v.c, v.d, v.i, v.f, v.k
FROM (VALUES ('PENDIENTE',  N'En espera de la respuesta de la pasarela', 1, 0, 0),
             ('CONFIRMADO', N'Cobro aprobado', 1, 1, 1),
             ('FALLIDO',    N'Cobro rechazado', 1, 1, 0),
             ('ANULADO',    N'Pago pendiente anulado (p. ej., por cancelación)', 0, 1, 0)) AS v (c, d, i, f, k)
WHERE NOT EXISTS (SELECT 1 FROM ref.estado_pago AS e WHERE e.codigo_estado = v.c);

INSERT ref.transicion_vuelo (estado_origen, estado_destino)
SELECT v.o, v.d
FROM (VALUES ('PROGRAMADO', 'DEMORADO'), ('PROGRAMADO', 'EN_VUELO'), ('PROGRAMADO', 'CANCELADO'),
             ('DEMORADO', 'DEMORADO'), ('DEMORADO', 'EN_VUELO'), ('DEMORADO', 'CANCELADO'),
             ('EN_VUELO', 'ATERRIZADO')) AS v (o, d)
WHERE NOT EXISTS (SELECT 1 FROM ref.transicion_vuelo AS t WHERE t.estado_origen = v.o AND t.estado_destino = v.d);

INSERT ref.transicion_tiquete (estado_origen, estado_destino)
SELECT v.o, v.d
FROM (VALUES ('RESERVADO', 'EMITIDO'), ('RESERVADO', 'CANCELADO'), ('EMITIDO', 'USADO'),
             ('EMITIDO', 'NO_PRESENTADO'), ('EMITIDO', 'CANCELADO')) AS v (o, d)
WHERE NOT EXISTS (SELECT 1 FROM ref.transicion_tiquete AS t WHERE t.estado_origen = v.o AND t.estado_destino = v.d);

INSERT ref.transicion_pago (estado_origen, estado_destino)
SELECT v.o, v.d
FROM (VALUES ('PENDIENTE', 'CONFIRMADO'), ('PENDIENTE', 'FALLIDO'), ('PENDIENTE', 'ANULADO')) AS v (o, d)
WHERE NOT EXISTS (SELECT 1 FROM ref.transicion_pago AS t WHERE t.estado_origen = v.o AND t.estado_destino = v.d);

INSERT ref.motivo_cancelacion (codigo_motivo, descripcion, iniciado_por, reembolso_total)
SELECT v.c, v.d, v.i, v.r
FROM (VALUES ('VOLUNTARIA',      N'Cancelación solicitada por el cliente', 'CLIENTE', 0),
             ('VUELO_CANCELADO', N'La aerolínea canceló el vuelo', 'AEROLINEA', 1),
             ('VENCIMIENTO',     N'La reserva no se pagó dentro del plazo', 'SISTEMA', 1)) AS v (c, d, i, r)
WHERE NOT EXISTS (SELECT 1 FROM ref.motivo_cancelacion AS m WHERE m.codigo_motivo = v.c);

INSERT ref.parametro (clave, valor, tipo_dato, descripcion)
SELECT v.k, v.v, v.t, v.d
FROM (VALUES ('CODIGO_AEROLINEA',          'XX',   'TEXT', N'Designador ficticio usado en los códigos de vuelo'),
             ('PREFIJO_TIQUETE',           '000',  'TEXT', N'Prefijo ficticio de 3 dígitos del número de tiquete'),
             ('MONEDA',                    'USD',  'TEXT', N'Moneda base de todos los importes'),
             ('MIN_ROTACION_AVION',        '40',   'INT',  N'Minutos mínimos en tierra entre dos vuelos del mismo avión'),
             ('MIN_DESCANSO_TRIPULACION',  '30',   'INT',  N'Minutos mínimos entre dos vuelos del mismo tripulante'),
             ('ASIENTOS_POR_TRIPULANTE_CABINA', '50', 'INT', N'Supuesto académico: un tripulante de cabina por cada 50 asientos'),
             ('HORAS_LIMITE_PAGO',         '72',   'INT',  N'Horas para completar el pago de una reserva'),
             ('HORAS_CIERRE_VENTA',        '3',    'INT',  N'Horas antes de la salida en que cierra la venta y vence la reserva'),
             ('INICIO_VENTAS',             '2026-07-01', 'DATE', N'Fecha de apertura de ventas'),
             ('INICIO_OPERACIONES',        '2026-09-01', 'DATE', N'Fecha del primer vuelo')) AS v (k, v, t, d)
WHERE NOT EXISTS (SELECT 1 FROM ref.parametro AS p WHERE p.clave = v.k);

INSERT ref.mensaje_error (numero_error, mensaje, regla)
SELECT v.n, v.m, v.r
FROM (VALUES
 (50001, N'Vigencias solapadas de un mismo número de vuelo', 'RN-03'),
 (50002, N'Tarifas con vigencias solapadas para la misma ruta y cabina', 'RN-18'),
 (50003, N'Tarifa ya usada: no se modifican ruta, cabina, precio ni inicio de vigencia', 'RN-20'),
 (50004, N'La vigencia de una tarifa no puede terminar antes de ventas realizadas', 'RN-20'),
 (50005, N'Descuento ya aplicado: no se modifican sus condiciones', 'RN-21'),
 (50010, N'Los datos de una compra son inmutables', NULL),
 (50011, N'Localización no habilitada para vender', NULL),
 (50012, N'Venta web sin vendedor; venta física con vendedor', 'RN-32'),
 (50013, N'El vendedor no estaba vigente en la fecha de la compra', 'RN-32'),
 (50020, N'Sin disponibilidad en la cabina (sobreventa)', 'RN-11'),
 (50021, N'Estado inicial de vuelo no válido', 'RN-08'),
 (50022, N'El vuelo no corresponde a la programación', 'RN-04'),
 (50023, N'Transición de vuelo no válida', 'RN-08'),
 (50024, N'La programación de un vuelo no puede cambiar', NULL),
 (50025, N'Cambio de avión con tiquetes activos hacia otra configuración', 'SUP-03'),
 (50026, N'Desfase horario distinto al de la zona del aeropuerto', 'RN-06'),
 (50027, N'Avión no activo', 'RN-10'),
 (50028, N'Solape de vuelos del mismo avión', 'RN-09'),
 (50029, N'Tripulación incompleta para iniciar el vuelo', 'RN-35'),
 (50031, N'Rol de tripulación incompatible con el cargo', 'RN-33'),
 (50032, N'Empleado no vigente en la fecha del vuelo', 'RN-33'),
 (50033, N'El vuelo no admite cambios de tripulación', 'RN-33'),
 (50034, N'Solape de vuelos del mismo tripulante', 'RN-33'),
 (50039, N'Los tiquetes no se eliminan', 'RN-29'),
 (50040, N'Datos comerciales del tiquete inmutables', 'RN-19'),
 (50041, N'Estado inicial de tiquete no válido', 'RN-08'),
 (50042, N'Transición de tiquete no válida', 'RN-08'),
 (50043, N'Vuelo cerrado a la venta o venta posterior a la salida', 'RN-31'),
 (50044, N'Tarifa no aplicable al vuelo o a la fecha de venta', 'RN-17'),
 (50045, N'Descuento no aplicable', 'RN-21'),
 (50046, N'Pasajero sin datos obligatorios', 'RN-41'),
 (50047, N'Emisión sin pago total', 'RN-24'),
 (50048, N'Cambio de estado del tiquete incompatible con el vuelo', 'RN-08'),
 (50049, N'Asiento inexistente, de otra cabina o fuera de plazo', 'RN-13'),
 (50050, N'Datos del pago inmutables', NULL),
 (50051, N'Transición de pago no válida', 'RN-08'),
 (50052, N'Estado inicial de pago no válido', 'RN-08'),
 (50053, N'Pago sobre un tiquete que no está reservado', 'RN-42'),
 (50054, N'Pagos confirmados superiores al precio final', 'RN-23'),
 (50055, N'Método de pago no permitido en la localización', 'RN-25'),
 (50056, N'Pago anterior a la venta', NULL),
 (50059, N'Los pagos no se eliminan', 'RN-29'),
 (50060, N'Los reembolsos son inmutables', 'RN-29'),
 (50061, N'Reembolso sobre un pago o tiquete no válido', 'RN-28'),
 (50062, N'Reembolsos superiores al pago', 'RN-28'),
 (50069, N'Los reembolsos no se eliminan', 'RN-29'),
 (50101, N'Nombres y apellidos obligatorios', NULL),
 (50102, N'La persona no existe', NULL),
 (50103, N'La persona ya es cliente', NULL),
 (50104, N'Correo de acceso duplicado', 'RN-38'),
 (50110, N'Fecha de venta en el futuro', NULL),
 (50111, N'El vuelo no existe', NULL),
 (50112, N'Vuelo cerrado a la venta', 'RN-31'),
 (50113, N'Cabina inexistente en el vuelo', 'RN-15'),
 (50114, N'Sin tarifa vigente', 'RN-17'),
 (50115, N'Descuento inexistente o no aplicable', 'RN-21'),
 (50116, N'No se pudo generar un localizador único', NULL),
 (50117, N'El comprador no existe', NULL),
 (50118, N'Compra no válida para agregar el tiquete', NULL),
 (50119, N'Ventas cerradas antes de la salida', 'SUP-07'),
 (50120, N'Asiento ocupado', 'RN-12'),
 (50121, N'Pasajero con tiquete activo en el vuelo', 'RN-14'),
 (50122, N'El tiquete no existe', NULL),
 (50123, N'Estado del tiquete no admite asiento', NULL),
 (50124, N'Sin asientos libres en la cabina', NULL),
 (50130, N'Resultado de pago no válido', NULL),
 (50131, N'Monto de pago no válido', NULL),
 (50132, N'El tiquete no existe', NULL),
 (50133, N'El tiquete no tiene saldo pendiente', NULL),
 (50134, N'Reserva vencida', 'SUP-07'),
 (50135, N'Monto superior al saldo pendiente', 'RN-37'),
 (50136, N'Resultado de resolución no válido', NULL),
 (50137, N'El pago no existe', NULL),
 (50140, N'Motivo de cancelación inexistente', NULL),
 (50141, N'El tiquete no existe', NULL),
 (50142, N'Estado del tiquete no admite cancelación', NULL),
 (50143, N'Sin política de reembolso aplicable', 'RN-36'),
 (50144, N'El tiquete no existe', NULL),
 (50150, N'Rango de fechas no válido', NULL),
 (50151, N'Rango de generación demasiado amplio', NULL),
 (50160, N'El avión no existe', NULL),
 (50161, N'El vuelo no existe', NULL),
 (50162, N'Estado del vuelo no admite asignación', NULL),
 (50163, N'Capacidad menor que las plazas vendidas', 'RN-11'),
 (50170, N'El vuelo no existe', NULL),
 (50171, N'Demora sin hora estimada', NULL),
 (50172, N'Cancelación de vuelo sin motivo', NULL),
 (50173, N'Estado de destino no válido', 'RN-08'),
 (50190, N'La carga sintética requiere tablas transaccionales vacías', NULL)) AS v (n, m, r)
WHERE NOT EXISTS (SELECT 1 FROM ref.mensaje_error AS e WHERE e.numero_error = v.n);
GO

/* ===================================================== LOCALIZACIONES ===== */
INSERT ref.localizacion (codigo_localizacion, tipo_localizacion, nombre, ciudad, codigo_estado, zona_horaria, url, vende_tiquetes, fecha_apertura)
SELECT v.cod, v.tipo, v.nombre, v.ciudad, v.estado, v.zona, v.url, v.vende, '20260601'
FROM (VALUES
 ('AER-JFK', 'AER', N'John F. Kennedy International Airport',            N'New York',          'NY', 'Eastern Standard Time',     NULL, 1),
 ('AER-BOS', 'AER', N'Boston Logan International Airport',               N'Boston',            'MA', 'Eastern Standard Time',     NULL, 1),
 ('AER-ATL', 'AER', N'Hartsfield-Jackson Atlanta International Airport', N'Atlanta',           'GA', 'Eastern Standard Time',     NULL, 1),
 ('AER-MIA', 'AER', N'Miami International Airport',                      N'Miami',             'FL', 'Eastern Standard Time',     NULL, 1),
 ('AER-MCO', 'AER', N'Orlando International Airport',                    N'Orlando',           'FL', 'Eastern Standard Time',     NULL, 1),
 ('AER-ORD', 'AER', N'Chicago O''Hare International Airport',            N'Chicago',           'IL', 'Central Standard Time',     NULL, 1),
 ('AER-DFW', 'AER', N'Dallas Fort Worth International Airport',          N'Dallas-Fort Worth', 'TX', 'Central Standard Time',     NULL, 1),
 ('AER-DEN', 'AER', N'Denver International Airport',                     N'Denver',            'CO', 'Mountain Standard Time',    NULL, 1),
 ('AER-PHX', 'AER', N'Phoenix Sky Harbor International Airport',         N'Phoenix',           'AZ', 'US Mountain Standard Time', NULL, 1),
 ('AER-LAS', 'AER', N'Harry Reid International Airport',                 N'Las Vegas',         'NV', 'Pacific Standard Time',     NULL, 1),
 ('AER-LAX', 'AER', N'Los Angeles International Airport',                N'Los Angeles',       'CA', 'Pacific Standard Time',     NULL, 1),
 ('AER-SEA', 'AER', N'Seattle-Tacoma International Airport',             N'Seattle',           'WA', 'Pacific Standard Time',     NULL, 1),
 ('AER-HNL', 'AER', N'Daniel K. Inouye International Airport',           N'Honolulu',          'HI', 'Hawaiian Standard Time',    NULL, 1),
 ('OFI-NYC', 'OFI', N'Oficina de ventas Nueva York (centro)',            N'New York',          'NY', 'Eastern Standard Time',     NULL, 1),
 ('OFI-CHI', 'OFI', N'Oficina de ventas Chicago (centro)',               N'Chicago',           'IL', 'Central Standard Time',     NULL, 1),
 ('OFI-MIA', 'OFI', N'Oficina de ventas Miami (centro)',                 N'Miami',             'FL', 'Eastern Standard Time',     NULL, 1),
 ('OFI-HQ',  'OFI', N'Sede corporativa',                                 N'Dallas',            'TX', 'Central Standard Time',     NULL, 0),
 ('WEB-SITIO','WEB', N'Sitio web de ventas',                             NULL, NULL, NULL, 'https://www.aerolinea-ejemplo.test', 1),
 ('WEB-APP', 'WEB', N'Aplicación móvil',                                 NULL, NULL, NULL, 'https://app.aerolinea-ejemplo.test', 1)
) AS v (cod, tipo, nombre, ciudad, estado, zona, url, vende)
WHERE NOT EXISTS (SELECT 1 FROM ref.localizacion AS l WHERE l.codigo_localizacion = v.cod);

INSERT ref.aeropuerto (id_localizacion, codigo_iata, codigo_icao, latitud, longitud, es_base_operaciones)
SELECT l.id_localizacion, v.iata, v.icao, v.lat, v.lon, v.base
FROM (VALUES ('JFK', 'KJFK', 40.641300,  -73.778100, 1), ('BOS', 'KBOS', 42.365600,  -71.009600, 0),
             ('ATL', 'KATL', 33.640700,  -84.427700, 0), ('MIA', 'KMIA', 25.795900,  -80.287000, 0),
             ('MCO', 'KMCO', 28.431200,  -81.308100, 0), ('ORD', 'KORD', 41.974200,  -87.907300, 1),
             ('DFW', 'KDFW', 32.899800,  -97.040300, 0), ('DEN', 'KDEN', 39.856100, -104.673700, 0),
             ('PHX', 'KPHX', 33.434200, -112.011600, 0), ('LAS', 'KLAS', 36.084000, -115.153700, 0),
             ('LAX', 'KLAX', 33.941600, -118.408500, 1), ('SEA', 'KSEA', 47.450200, -122.308800, 0),
             ('HNL', 'PHNL', 21.324500, -157.925100, 0)) AS v (iata, icao, lat, lon, base)
JOIN ref.localizacion AS l ON l.codigo_localizacion = CONCAT('AER-', v.iata)
WHERE NOT EXISTS (SELECT 1 FROM ref.aeropuerto AS a WHERE a.codigo_iata = v.iata);
GO

/* ============================================ FLOTA Y CONFIGURACIONES ==== */
INSERT ref.modelo_avion (fabricante, modelo, alcance_millas, velocidad_crucero_mph)
SELECT v.f, v.m, v.a, v.s
FROM (VALUES (N'Airbus', N'A321neo', 4000, 540), (N'Airbus', N'A320neo', 3900, 540),
             (N'Boeing', N'737-800', 3300, 530), (N'Embraer', N'E175', 2500, 515)) AS v (f, m, a, s)
WHERE NOT EXISTS (SELECT 1 FROM ref.modelo_avion AS x WHERE x.fabricante = v.f AND x.modelo = v.m);

INSERT ops.configuracion_asientos (codigo_configuracion, id_modelo, descripcion)
SELECT v.c, m.id_modelo, v.d
FROM (VALUES ('A21N-20V168E', N'A321neo', N'20 VIP (2-2) + 168 económica (3-3)'),
             ('A20N-12V150E', N'A320neo', N'12 VIP (2-2) + 150 económica (3-3)'),
             ('B738-16V144E', N'737-800', N'16 VIP (2-2) + 144 económica (3-3)'),
             ('E175-12V64E',  N'E175',    N'12 VIP (1-2) + 64 económica (2-2)')) AS v (c, modelo, d)
JOIN ref.modelo_avion AS m ON m.modelo = v.modelo
WHERE NOT EXISTS (SELECT 1 FROM ops.configuracion_asientos AS x WHERE x.codigo_configuracion = v.c);

/* Asientos generados por conjuntos a partir de la definición de cada cabina.
   La fila 13 se omite, como es habitual en la industria. */
DECLARE @definicion TABLE (codigo_configuracion VARCHAR(20), codigo_cabina CHAR(3), fila_desde TINYINT, fila_hasta TINYINT,
                           letras VARCHAR(8), ventanas VARCHAR(8), pasillos VARCHAR(8), filas_salida VARCHAR(20));
INSERT @definicion VALUES
 ('A21N-20V168E', 'VIP',  1,  5, 'ACDF',   'AF', 'CD', ''),
 ('A21N-20V168E', 'ECO', 10, 38, 'ABCDEF', 'AF', 'CD', '|12|25|'),
 ('A20N-12V150E', 'VIP',  1,  3, 'ACDF',   'AF', 'CD', ''),
 ('A20N-12V150E', 'ECO', 10, 35, 'ABCDEF', 'AF', 'CD', '|12|14|'),
 ('B738-16V144E', 'VIP',  1,  4, 'ACDF',   'AF', 'CD', ''),
 ('B738-16V144E', 'ECO', 10, 34, 'ABCDEF', 'AF', 'CD', '|15|16|'),
 ('E175-12V64E',  'VIP',  1,  4, 'ACD',    'AD', 'AC', ''),
 ('E175-12V64E',  'ECO', 10, 26, 'ABCD',   'AD', 'BC', '|12|');

WITH numeros AS (SELECT TOP (60) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS TINYINT) AS n FROM sys.all_columns),
     asientos AS (
        SELECT c.id_configuracion, d.codigo_cabina, f.n AS fila, SUBSTRING(d.letras, k.n, 1) AS letra, d.ventanas, d.pasillos, d.filas_salida
        FROM @definicion AS d
        JOIN ops.configuracion_asientos AS c ON c.codigo_configuracion = d.codigo_configuracion
        JOIN numeros AS f ON f.n BETWEEN d.fila_desde AND d.fila_hasta AND f.n <> 13
        JOIN numeros AS k ON k.n <= LEN(d.letras))
INSERT ops.asiento_configuracion (id_configuracion, codigo_asiento, fila, letra, codigo_cabina, es_ventana, es_pasillo, es_salida_emergencia)
SELECT a.id_configuracion, CONCAT(a.fila, a.letra), a.fila, a.letra, a.codigo_cabina,
       CASE WHEN CHARINDEX(a.letra, a.ventanas) > 0 THEN 1 ELSE 0 END,
       CASE WHEN CHARINDEX(a.letra, a.pasillos) > 0 THEN 1 ELSE 0 END,
       CASE WHEN CHARINDEX(CONCAT('|', a.fila, '|'), a.filas_salida) > 0 THEN 1 ELSE 0 END
FROM asientos AS a
WHERE NOT EXISTS (SELECT 1 FROM ops.asiento_configuracion AS s
                  WHERE s.id_configuracion = a.id_configuracion AND s.codigo_asiento = CONCAT(a.fila, a.letra));

INSERT ops.avion (matricula, numero_serie, id_configuracion, fecha_fabricacion, fecha_incorporacion, estado_operativo, id_aeropuerto_base)
SELECT v.mat, v.msn, c.id_configuracion, v.fab, v.inc, v.estado, a.id_localizacion
FROM (VALUES
 ('N321XA', 'MSN-A21N-0101', 'A21N-20V168E', '20220315', '20260601', 'ACTIVO', 'JFK'),
 ('N322XA', 'MSN-A21N-0102', 'A21N-20V168E', '20220610', '20260601', 'ACTIVO', 'JFK'),
 ('N323XA', 'MSN-A21N-0103', 'A21N-20V168E', '20230120', '20260615', 'ACTIVO', 'LAX'),
 ('N324XA', 'MSN-A21N-0104', 'A21N-20V168E', '20230505', '20260615', 'ACTIVO', 'JFK'),
 ('N325XA', 'MSN-A21N-0105', 'A21N-20V168E', '20240212', '20260701', 'ACTIVO', 'LAX'),
 ('N201XA', 'MSN-A20N-0201', 'A20N-12V150E', '20210908', '20260601', 'ACTIVO', 'JFK'),
 ('N202XA', 'MSN-A20N-0202', 'A20N-12V150E', '20211122', '20260601', 'ACTIVO', 'JFK'),
 ('N203XA', 'MSN-A20N-0203', 'A20N-12V150E', '20220704', '20260615', 'ACTIVO', 'JFK'),
 ('N204XA', 'MSN-A20N-0204', 'A20N-12V150E', '20230830', '20260701', 'ACTIVO', 'ORD'),
 ('N801XA', 'MSN-B738-0801', 'B738-16V144E', '20160412', '20260601', 'ACTIVO', 'ORD'),
 ('N802XA', 'MSN-B738-0802', 'B738-16V144E', '20170219', '20260601', 'ACTIVO', 'ORD'),
 ('N803XA', 'MSN-B738-0803', 'B738-16V144E', '20180611', '20260615', 'ACTIVO', 'ORD'),
 ('N804XA', 'MSN-B738-0804', 'B738-16V144E', '20181025', '20260701', 'ACTIVO', 'ORD'),
 ('N805XA', 'MSN-B738-0805', 'B738-16V144E', '20150930', '20260701', 'MANTENIMIENTO', 'ORD'),
 ('N175XA', 'MSN-E175-1751', 'E175-12V64E',  '20190514', '20260601', 'ACTIVO', 'JFK'),
 ('N176XA', 'MSN-E175-1752', 'E175-12V64E',  '20191203', '20260615', 'ACTIVO', 'JFK'),
 ('N177XA', 'MSN-E175-1753', 'E175-12V64E',  '20200716', '20260701', 'ACTIVO', 'ORD')
) AS v (mat, msn, cfg, fab, inc, estado, base)
JOIN ops.configuracion_asientos AS c ON c.codigo_configuracion = v.cfg
JOIN ref.aeropuerto AS a ON a.codigo_iata = v.base
WHERE NOT EXISTS (SELECT 1 FROM ops.avion AS x WHERE x.matricula = v.mat);
GO

/* ============================================== RED Y PROGRAMACIÓN ===== */
/* Rutas dirigidas. La distancia es la ortodrómica calculada con el tipo geography (WGS 84). */
INSERT ops.ruta (id_aeropuerto_origen, id_aeropuerto_destino, distancia_millas, activa, fecha_inicio_operacion)
SELECT o.id_localizacion, d.id_localizacion,
       CAST(ROUND(geography::Point(o.latitud, o.longitud, 4326).STDistance(geography::Point(d.latitud, d.longitud, 4326)) / 1609.344, 0) AS SMALLINT),
       v.activa, CASE WHEN v.activa = 1 THEN CAST('20260901' AS DATE) END
FROM (VALUES ('JFK','LAX',1), ('LAX','JFK',1), ('JFK','MIA',1), ('MIA','JFK',1), ('BOS','MCO',1), ('MCO','BOS',1),
             ('JFK','ORD',1), ('ORD','JFK',1), ('ORD','DFW',1), ('DFW','ORD',1), ('ATL','DEN',1), ('DEN','ATL',1),
             ('ATL','MIA',1), ('MIA','ATL',1), ('DFW','PHX',1), ('PHX','DFW',1), ('DEN','SEA',1), ('SEA','DEN',1),
             ('LAX','HNL',1), ('HNL','LAX',1), ('JFK','LAS',1), ('LAS','JFK',1),
             ('BOS','ORD',0), ('ORD','BOS',0)) AS v (o, d, activa)       -- BOS-ORD: ruta en evaluación, sin programación
JOIN ref.aeropuerto AS o ON o.codigo_iata = v.o
JOIN ref.aeropuerto AS d ON d.codigo_iata = v.d
WHERE NOT EXISTS (SELECT 1 FROM ops.ruta AS r WHERE r.id_aeropuerto_origen = o.id_localizacion AND r.id_aeropuerto_destino = d.id_localizacion);

/* Programación semanal: hora local de salida en el origen y duración de bloque.
   Días: 'D' = diario; en otro caso, lista de días ISO. XX703/XX704 cambian de
   horario desde el 1-dic-2026 (dos vigencias del mismo número de vuelo). */
DECLARE @programa TABLE (numero SMALLINT, o CHAR(3), d CHAR(3), hora TIME(0), duracion SMALLINT, desde DATE, hasta DATE NULL, dias VARCHAR(14));
INSERT @programa VALUES
 (101, 'JFK','LAX','07:00',370,'20260901',NULL,'D'), (102, 'LAX','JFK','13:00',315,'20260901',NULL,'D'),
 (112, 'JFK','LAX','08:30',370,'20260901',NULL,'D'), (111, 'LAX','JFK','22:30',315,'20260901',NULL,'D'),
 (201, 'JFK','MIA','06:30',170,'20260901',NULL,'D'), (202, 'MIA','JFK','10:30',165,'20260901',NULL,'D'),
 (203, 'JFK','MIA','15:00',170,'20260901',NULL,'D'), (204, 'MIA','JFK','19:00',165,'20260901',NULL,'D'),
 (301, 'BOS','MCO','07:15',180,'20260901',NULL,'1,4,5,6,7'), (302, 'MCO','BOS','11:45',165,'20260901',NULL,'1,4,5,6,7'),
 (401, 'JFK','ORD','07:00',130,'20260901',NULL,'D'), (402, 'ORD','JFK','10:15',115,'20260901',NULL,'D'),
 (403, 'JFK','ORD','14:30',130,'20260901',NULL,'D'), (404, 'ORD','JFK','18:00',115,'20260901',NULL,'D'),
 (501, 'ORD','DFW','08:00',135,'20260901',NULL,'D'), (502, 'DFW','ORD','12:00',125,'20260901',NULL,'D'),
 (601, 'ATL','DEN','09:00',195,'20260901',NULL,'D'), (602, 'DEN','ATL','13:30',170,'20260901',NULL,'D'),
 (701, 'ATL','MIA','07:30',105,'20260901',NULL,'D'), (702, 'MIA','ATL','10:30',105,'20260901',NULL,'D'),
 (703, 'ATL','MIA','16:00',105,'20260901','20261130','D'), (704, 'MIA','ATL','19:15',105,'20260901','20261130','D'),
 (703, 'ATL','MIA','16:30',105,'20261201',NULL,'D'), (704, 'MIA','ATL','19:45',105,'20261201',NULL,'D'),
 (801, 'DFW','PHX','09:30',145,'20260901',NULL,'D'), (802, 'PHX','DFW','13:30',130,'20260901',NULL,'D'),
 (901, 'DEN','SEA','08:15',170,'20260901',NULL,'D'), (902, 'SEA','DEN','12:45',150,'20260901',NULL,'D'),
 (1001,'LAX','HNL','08:00',380,'20260901',NULL,'D'), (1002,'HNL','LAX','13:00',325,'20260901',NULL,'D'),
 (1101,'JFK','LAS','09:00',340,'20260901',NULL,'D'), (1102,'LAS','JFK','14:30',290,'20260901',NULL,'D');

INSERT ops.programacion (numero_vuelo, id_ruta, hora_salida_local, duracion_programada_min, vigente_desde, vigente_hasta)
SELECT p.numero, r.id_ruta, p.hora, p.duracion, p.desde, p.hasta
FROM @programa AS p
JOIN ref.aeropuerto AS o ON o.codigo_iata = p.o
JOIN ref.aeropuerto AS d ON d.codigo_iata = p.d
JOIN ops.ruta AS r ON r.id_aeropuerto_origen = o.id_localizacion AND r.id_aeropuerto_destino = d.id_localizacion
WHERE NOT EXISTS (SELECT 1 FROM ops.programacion AS x WHERE x.numero_vuelo = p.numero AND x.vigente_desde = p.desde);

WITH dias AS (SELECT CAST(n AS TINYINT) AS dia FROM (VALUES (1),(2),(3),(4),(5),(6),(7)) AS v (n))
INSERT ops.programacion_dia (id_programacion, dia_semana)
SELECT x.id_programacion, dias.dia
FROM @programa AS p
JOIN ops.programacion AS x ON x.numero_vuelo = p.numero AND x.vigente_desde = p.desde
JOIN dias ON p.dias = 'D' OR CHARINDEX(CONCAT(',', dias.dia, ','), CONCAT(',', p.dias, ',')) > 0
WHERE NOT EXISTS (SELECT 1 FROM ops.programacion_dia AS pd WHERE pd.id_programacion = x.id_programacion AND pd.dia_semana = dias.dia);
GO

/* ============================================================ TARIFAS ===== */
/* Precio por ruta y cabina con tres períodos de venta (versiones):
   v1 01-jul a 15-sep; v2 desde 16-sep (ajuste por ruta);
   v3 desde 20-oct solo en rutas transcontinentales y Hawái. Precios terminados en ,99. */
DECLARE @factor TABLE (o CHAR(3), d CHAR(3), f2 DECIMAL(5,3), f3 DECIMAL(5,3) NULL);
INSERT @factor VALUES
 ('JFK','LAX',1.080,1.150), ('LAX','JFK',1.080,1.150), ('LAX','HNL',1.080,1.150), ('HNL','LAX',1.080,1.150),
 ('ATL','MIA',0.950,NULL),  ('MIA','ATL',0.950,NULL);

WITH base AS (
    SELECT r.id_ruta, ao.codigo_iata AS o, ad.codigo_iata AS d,
           CAST(ROUND(49 + 0.105 * r.distancia_millas, 0) - 0.01 AS DECIMAL(10,2)) AS eco_v1
    FROM ops.ruta AS r
    JOIN ref.aeropuerto AS ao ON ao.id_localizacion = r.id_aeropuerto_origen
    JOIN ref.aeropuerto AS ad ON ad.id_localizacion = r.id_aeropuerto_destino
    WHERE r.activa = 1
), versiones AS (
    SELECT b.id_ruta, c.cabina, v.version,
           CASE v.version WHEN 1 THEN '20260701' WHEN 2 THEN '20260916' ELSE '20261020' END AS desde,
           CASE WHEN v.version = 1 THEN CAST('20260915' AS DATE)
                WHEN v.version = 2 AND f.f3 IS NOT NULL THEN CAST('20261019' AS DATE) END AS hasta,
           CASE c.cabina WHEN 'ECO' THEN b.eco_v1 ELSE CAST(ROUND(b.eco_v1 * 2.75, 0) - 0.01 AS DECIMAL(10,2)) END AS p1,
           CASE v.version WHEN 1 THEN 1.000
                          WHEN 2 THEN ISNULL(f.f2, CASE c.cabina WHEN 'ECO' THEN 1.080 ELSE 1.050 END)
                          ELSE f.f3 END AS factor
    FROM base AS b
    CROSS JOIN (VALUES ('ECO'), ('VIP')) AS c (cabina)
    CROSS JOIN (VALUES (1), (2), (3)) AS v (version)
    LEFT JOIN @factor AS f ON f.o = b.o AND f.d = b.d
    WHERE v.version < 3 OR f.f3 IS NOT NULL
)
INSERT ven.tarifa (id_ruta, codigo_cabina, precio_base_usd, vigente_desde, vigente_hasta)
SELECT v.id_ruta, v.cabina,
       CASE WHEN v.version = 1 THEN v.p1 ELSE CAST(ROUND(v.p1 * v.factor, 0) - 0.01 AS DECIMAL(10,2)) END,
       v.desde, v.hasta
FROM versiones AS v
WHERE NOT EXISTS (SELECT 1 FROM ven.tarifa AS t WHERE t.id_ruta = v.id_ruta AND t.codigo_cabina = v.cabina AND t.vigente_desde = v.desde)
ORDER BY v.id_ruta, v.cabina, v.version;
GO

/* ==================================================== DESCUENTOS ======== */
INSERT ven.descuento (codigo_descuento, descripcion, porcentaje, vigente_desde, vigente_hasta, solo_clientes_registrados, codigo_cabina, dias_anticipacion_min)
SELECT v.c, v.d, v.p, v.desde, v.hasta, v.reg, v.cab, v.ant
FROM (VALUES
 ('LANZAMIENTO20', N'Promoción de lanzamiento en cabina económica',            20.00, '20260701', '20260731', 0, 'ECO', NULL),
 ('CLIENTE10',     N'Beneficio para clientes registrados',                       10.00, '20260701', '20261231', 1, NULL,  NULL),
 ('ANTICIPA15',    N'Compra anticipada (30 días o más) en económica',            15.00, '20260701', '20261231', 0, 'ECO', 30),
 ('VIPPLUS5',      N'Beneficio VIP para clientes registrados',                    5.00, '20260801', '20261231', 1, 'VIP', NULL),
 ('OTONO12',       N'Campaña de otoño',                                          12.00, '20260920', '20261010', 0, NULL,  NULL),
 ('INVIERNO25',    N'Campaña de invierno (aún no vigente en los datos)',         25.00, '20261201', '20270131', 0, NULL,  NULL)
) AS v (c, d, p, desde, hasta, reg, cab, ant)
WHERE NOT EXISTS (SELECT 1 FROM ven.descuento AS x WHERE x.codigo_descuento = v.c);

INSERT ven.politica_cancelacion (codigo_cabina, horas_antes_min, porcentaje_reembolso)
SELECT v.c, v.h, v.p
FROM (VALUES ('ECO', 0, 0.00), ('ECO', 72, 50.00), ('ECO', 336, 80.00),
             ('VIP', 0, 30.00), ('VIP', 24, 70.00), ('VIP', 168, 90.00)) AS v (c, h, p)
WHERE NOT EXISTS (SELECT 1 FROM ven.politica_cancelacion AS x WHERE x.codigo_cabina = v.c AND x.horas_antes_min = v.h);
GO

/* ===================================================== PERSONAL ========= */
INSERT rh.departamento (codigo_departamento, nombre)
SELECT v.c, v.n
FROM (VALUES ('OPS', N'Operaciones de vuelo'), ('CAB', N'Servicio a bordo'), ('COM', N'Comercial y ventas'),
             ('MNT', N'Mantenimiento'), ('ADM', N'Administración y finanzas'), ('TEC', N'Tecnología')) AS v (c, n)
WHERE NOT EXISTS (SELECT 1 FROM rh.departamento AS d WHERE d.codigo_departamento = v.c);

INSERT rh.cargo (codigo_cargo, nombre, codigo_departamento, categoria_tripulacion)
SELECT v.c, v.n, v.d, v.t
FROM (VALUES ('GERENTE', N'Gerente', 'ADM', NULL), ('PILOTO_CAP', N'Capitán', 'OPS', 'TECNICA'),
             ('PILOTO_FO', N'Primer oficial', 'OPS', 'TECNICA'), ('TCP_JEFE', N'Jefe de cabina', 'CAB', 'CABINA'),
             ('TCP', N'Auxiliar de vuelo', 'CAB', 'CABINA'), ('AGENTE_VTA', N'Agente de ventas', 'COM', NULL),
             ('SUP_VTA', N'Supervisor de ventas', 'COM', NULL), ('PLANIF', N'Planificador de operaciones', 'OPS', NULL),
             ('TEC_MNT', N'Técnico de mantenimiento', 'MNT', NULL), ('ANALISTA', N'Analista comercial', 'COM', NULL),
             ('DBA', N'Administrador de base de datos', 'TEC', NULL)) AS v (c, n, d, t)
WHERE NOT EXISTS (SELECT 1 FROM rh.cargo AS x WHERE x.codigo_cargo = v.c);

/* 349 empleados sintéticos generados de forma determinista (sin aleatoriedad):
   4 gerentes, 52 capitanes, 52 primeros oficiales, 52 jefes de cabina,
   136 auxiliares, 32 agentes (2 por punto de venta físico), 3 supervisores,
   4 planificadores, 10 técnicos, 3 analistas y 1 DBA.
   Dimensionamiento de tripulación: 12 líneas x 4 equipos (bloques de 3 días),
   de modo que ningún piloto supere 100 h de vuelo en 672 h consecutivas
   (14 CFR 117.23(b)); se verifica con la consulta Q18. */
IF NOT EXISTS (SELECT 1 FROM rh.empleado)
BEGIN
    DECLARE @nombres TABLE (k INT PRIMARY KEY, nombre NVARCHAR(30));
    INSERT @nombres VALUES (0,N'James'),(1,N'María'),(2,N'Robert'),(3,N'Patricia'),(4,N'John'),(5,N'Jennifer'),(6,N'Michael'),
        (7,N'Linda'),(8,N'David'),(9,N'Elizabeth'),(10,N'William'),(11,N'Barbara'),(12,N'Richard'),(13,N'Susan'),(14,N'José'),
        (15,N'Jessica'),(16,N'Thomas'),(17,N'Sarah'),(18,N'Carlos'),(19,N'Ana'),(20,N'Luis'),(21,N'Carmen'),(22,N'Juan'),
        (23,N'Sofía'),(24,N'Miguel'),(25,N'Lucía'),(26,N'Daniel'),(27,N'Valentina'),(28,N'Emily'),(29,N'Andrew'),(30,N'Olivia'),
        (31,N'Ethan'),(32,N'Grace'),(33,N'Noah'),(34,N'Chloe'),(35,N'Kevin'),(36,N'Isabella'),(37,N'Brian'),(38,N'Ming'),(39,N'Priya');
    DECLARE @apellidos TABLE (k INT PRIMARY KEY, apellido NVARCHAR(30));
    INSERT @apellidos VALUES (0,N'Smith'),(1,N'Johnson'),(2,N'Williams'),(3,N'Brown'),(4,N'Jones'),(5,N'García'),(6,N'Miller'),
        (7,N'Davis'),(8,N'Rodríguez'),(9,N'Martínez'),(10,N'Hernández'),(11,N'López'),(12,N'González'),(13,N'Wilson'),
        (14,N'Anderson'),(15,N'Thomas'),(16,N'Taylor'),(17,N'Moore'),(18,N'Jackson'),(19,N'Martin'),(20,N'Lee'),(21,N'Pérez'),
        (22,N'Thompson'),(23,N'White'),(24,N'Harris'),(25,N'Sánchez'),(26,N'Clark'),(27,N'Ramírez'),(28,N'Lewis'),
        (29,N'Robinson'),(30,N'Walker'),(31,N'Young'),(32,N'Allen'),(33,N'King'),(34,N'Wright'),(35,N'Scott'),(36,N'Torres'),
        (37,N'Nguyen'),(38,N'Hill'),(39,N'Flores');

    -- Puntos de venta físicos ordenados (16): reciben 2 agentes cada uno.
    DECLARE @puntos TABLE (orden INT PRIMARY KEY, id_localizacion INT);
    INSERT @puntos SELECT ROW_NUMBER() OVER (ORDER BY codigo_localizacion), id_localizacion
    FROM ref.localizacion WHERE tipo_localizacion IN ('AER', 'OFI') AND vende_tiquetes = 1;
    DECLARE @bases TABLE (orden INT PRIMARY KEY, id_localizacion INT);
    INSERT @bases SELECT v.o, l.id_localizacion
    FROM (VALUES (0,'AER-JFK'),(1,'AER-ORD'),(2,'AER-LAX'),(3,'AER-ATL'),(4,'AER-DFW'),(5,'AER-DEN')) AS v (o, c)
    JOIN ref.localizacion AS l ON l.codigo_localizacion = v.c;
    DECLARE @hq INT = (SELECT id_localizacion FROM ref.localizacion WHERE codigo_localizacion = 'OFI-HQ');

    WITH n AS (SELECT TOP (353) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_columns),
    plan_cargo AS (
        SELECT i,
               CASE WHEN i <= 4 THEN 'GERENTE' WHEN i <= 56 THEN 'PILOTO_CAP' WHEN i <= 108 THEN 'PILOTO_FO'
                    WHEN i <= 160 THEN 'TCP_JEFE' WHEN i <= 300 THEN 'TCP' WHEN i <= 332 THEN 'AGENTE_VTA'
                    WHEN i <= 335 THEN 'SUP_VTA' WHEN i <= 339 THEN 'PLANIF' WHEN i <= 349 THEN 'TEC_MNT'
                    WHEN i <= 352 THEN 'ANALISTA' ELSE 'DBA' END AS cargo
        FROM n)
    INSERT rh.empleado (numero_empleado, nombres, apellidos, fecha_nacimiento, email_corporativo, telefono,
                        fecha_contratacion, fecha_terminacion, codigo_cargo, id_localizacion_base, salario_anual_usd)
    SELECT CONCAT('E', RIGHT(CONCAT('00000', p.i), 5)),
           nm.nombre, ap.apellido,
           DATEADD(DAY, -(9500 + (p.i * 137) % 9000 + CASE WHEN p.cargo LIKE 'PILOTO%' OR p.cargo = 'GERENTE' THEN 2500 ELSE 0 END), CAST('20260101' AS DATE)),
           CONCAT('e', RIGHT(CONCAT('00000', p.i), 5), '@aerolinea-ejemplo.test'),
           CONCAT('+1-202-555-01', RIGHT(CONCAT('0', p.i % 100), 2)),
           DATEADD(DAY, (p.i * 13) % 120, CAST('20260301' AS DATE)),
           CASE WHEN p.i IN (330, 332) THEN CAST('20260831' AS DATE) END,      -- dos agentes (de puntos distintos) que dejaron la empresa
           p.cargo,
           CASE WHEN p.cargo = 'AGENTE_VTA' THEN (SELECT id_localizacion FROM @puntos WHERE orden = (p.i - 301) / 2 + 1)
                WHEN p.cargo IN ('PILOTO_CAP', 'PILOTO_FO', 'TCP_JEFE', 'TCP', 'TEC_MNT') THEN (SELECT id_localizacion FROM @bases WHERE orden = p.i % 6)
                WHEN p.cargo = 'SUP_VTA' THEN (SELECT id_localizacion FROM ref.localizacion
                                               WHERE codigo_localizacion = CASE p.i WHEN 333 THEN 'OFI-NYC' WHEN 334 THEN 'OFI-CHI' ELSE 'OFI-MIA' END)
                ELSE @hq END,
           CASE p.cargo WHEN 'GERENTE' THEN 180000 WHEN 'PILOTO_CAP' THEN 210000 WHEN 'PILOTO_FO' THEN 120000
                        WHEN 'TCP_JEFE' THEN 62000 WHEN 'TCP' THEN 48000 WHEN 'AGENTE_VTA' THEN 42000
                        WHEN 'SUP_VTA' THEN 58000 WHEN 'PLANIF' THEN 75000 WHEN 'TEC_MNT' THEN 70000
                        WHEN 'ANALISTA' THEN 80000 ELSE 115000 END + (p.i % 7) * 1000
    FROM plan_cargo AS p
    JOIN @nombres   AS nm ON nm.k = (p.i * 7) % 40
    JOIN @apellidos AS ap ON ap.k = (p.i * 11 + p.i / 40) % 40
    ORDER BY p.i;

    -- Jerarquía: E00001 gerente general; tripulación y planificación reportan a E00002; ventas a su supervisor o a E00003.
    UPDATE e SET id_supervisor = CASE
        WHEN e.numero_empleado = 'E00001' THEN NULL
        WHEN e.codigo_cargo IN ('GERENTE', 'SUP_VTA', 'ANALISTA', 'DBA') THEN (SELECT id_empleado FROM rh.empleado WHERE numero_empleado = CASE WHEN e.codigo_cargo = 'GERENTE' THEN 'E00001' ELSE 'E00003' END)
        WHEN e.codigo_cargo IN ('PILOTO_CAP', 'PILOTO_FO', 'TCP_JEFE', 'TCP', 'PLANIF', 'TEC_MNT') THEN (SELECT id_empleado FROM rh.empleado WHERE numero_empleado = 'E00002')
        WHEN e.codigo_cargo = 'AGENTE_VTA' THEN (SELECT id_empleado FROM rh.empleado WHERE numero_empleado = CONCAT('E00', 333 + (CAST(RIGHT(e.numero_empleado, 3) AS INT) % 3)))
        END
    FROM rh.empleado AS e;
END;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '09_datos_referencia')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('09_datos_referencia', N'Catálogos, red, flota, programación, tarifas y personal');
GO
SET NOEXEC OFF;
GO
