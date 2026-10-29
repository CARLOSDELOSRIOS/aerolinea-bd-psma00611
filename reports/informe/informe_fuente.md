::: {custom-style="Portada Institucion"}
UNIVERSIDAD CONTINENTAL

Escuela de Posgrado

Maestría en Ciencia de Datos
:::

::: {custom-style="Portada Curso"}
Gestión de datos y bases de datos con SQL (PSMA00611)
:::

::: {custom-style="Portada Titulo"}
Base de datos para una aerolínea comercial en Estados Unidos: requisitos, modelado, implementación en SQL Server, integración con Python y preparación para Azure SQL Database
:::

::: {custom-style="Portada Curso"}
Producto Académico Colaborativo
:::

::: {custom-style="Portada Datos"}
Integrantes que participaron activamente:

Carlos Veliz de Villa Aguirre

Elias Sifuentes Valles

Carlos De los Ríos De la Roca

Docentes: Walter Alejandro Silva Sotillo y Max Leoncio Mucha Morales

Sección / NRC: [POR COMPLETAR]

Líder del equipo (entrega en el aula virtual): Carlos De los Ríos De la Roca

Lugar y fecha: [POR COMPLETAR], noviembre de 2026
:::

```{=openxml}
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
```

::: {custom-style="Titulo Indice"}
Índice
:::

```{=openxml}
<w:sdt><w:sdtPr><w:docPartObj><w:docPartGallery w:val="Table of Contents"/><w:docPartUnique/></w:docPartObj></w:sdtPr><w:sdtContent><w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-2" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Actualice el índice: clic derecho y «Actualizar campo».</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:sdtContent></w:sdt>
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
```

# Resumen ejecutivo

Este informe presenta el diseño, la implementación y la validación de una base de datos relacional para una aerolínea comercial nueva que operará vuelos domésticos en Estados Unidos. El encargo del curso pide una base de datos en la nube que cubra la definición de requisitos, el modelo de datos, la creación de tablas, la carga de datos, la definición de consultas y su ejecución desde un lenguaje de programación. El equipo añadió como metas propias la reproducibilidad completa, el control de concurrencia, la seguridad por roles y un conjunto de pruebas automatizadas.

La solución tiene 39 tablas de negocio en cinco esquemas temáticos, más un esquema de vistas de reporte, y aplica 70 restricciones `CHECK`, 53 claves foráneas, 29 restricciones de unicidad, 6 índices únicos filtrados y 12 triggers que garantizan en el propio motor 42 reglas de negocio: entre otras, que no haya sobreventa ni asientos duplicados, que el precio pactado de un tiquete no cambie aunque cambie la tarifa, que los pagos no superen el precio y que los reembolsos sigan la política de cancelación. Dieciséis procedimientos almacenados orquestan las operaciones críticas (emitir, pagar, cancelar, generar vuelos), otros cuatro automatizan las pruebas y nueve vistas concentran las fórmulas de análisis para que todas las consultas usen las mismas definiciones.

Una aplicación de consola en Python (pyodbc y pandas) despliega los scripts en orden, genera y carga datos sintéticos deterministas, ejecuta 20 consultas analíticas con parámetros enlazados, exporta los resultados a CSV, produce los gráficos, documenta el modelo desde el catálogo del motor y ejecuta las pruebas. Con una semilla fija se generan 3 588 vuelos, 232 096 personas, 323 718 tiquetes, 388 003 pagos y 18 182 reembolsos, que se cargan en una sola transacción con todas las reglas activas en unos 90 segundos.

La validación se ejecutó en un contenedor Linux con SQL Server 2022 Developer: 23 de 23 pruebas de reglas de negocio, 4 de 4 pruebas de concurrencia con sesiones simultáneas reales y 23 de 23 pruebas de la aplicación superadas; los controles de conciliación devolvieron cero diferencias, incluida la identidad de caja al centavo. Las mismas pruebas y consultas se repitieron con el nivel de compatibilidad de SQL Server 2016 con los mismos resultados. Durante el desarrollo las pruebas detectaron 20 defectos reales, documentados con su causa y corrección.

Dos resultados quedan **pendientes** y se declaran como tales: la ejecución en la laptop Windows del equipo y el despliegue en Azure SQL Database, que es el requisito de nube del encargo. Para ambos se entregan guías, scripts y listas de evidencias; ninguna prueba local se presenta como sustituto de la evidencia en la nube. Todos los datos analizados son sintéticos, por lo que las cifras validan el modelo y las consultas, pero no describen ningún mercado real.

# Problema, objetivos y alcance

## Problema

Una aerolínea nueva necesita registrar de forma confiable qué vuelos ofrece, quién compra y quién viaja, cuánto se cobró y cuánto se devolvió, y qué avión y qué tripulación operan cada vuelo. Los errores en ese registro tienen consecuencias visibles: un asiento vendido dos veces, un vuelo sobrevendido, un cobro duplicado o un reembolso mal calculado afectan a los pasajeros y a la contabilidad. Además, la información debe servir para tomar decisiones (ocupación, canales de venta, cancelaciones, utilización de la flota), lo que exige definiciones de cálculo consistentes.

El enunciado del curso enumera las relaciones mínimas —clientes, empleados, rutas, vuelos, localizaciones, tiquetes, aviones, cabinas, pagos y descuentos— y pide «ser exhaustivo con los atributos» para que la información pueda usarse después en la toma de decisiones (Universidad Continental, 2026). El enunciado deja abiertas varias ambigüedades que el diseño debía resolver de forma explícita, por ejemplo la diferencia entre pasajero y comprador, entre horario y vuelo fechado, o cómo se combinan descuentos y pagos parciales.

## Objetivos

**Objetivo general.** Diseñar, implementar y validar una base de datos relacional para la gestión comercial y operativa de una aerolínea, desplegable en SQL Server local y en Azure SQL Database, con consultas analíticas ejecutables desde Python y resultados reproducibles.

**Objetivos específicos.**

1. **OE1 · Requisitos.** Identificar los requisitos del negocio, resolver sus ambigüedades y expresarlos como reglas verificables.
2. **OE2 · Modelo.** Construir los modelos conceptual, lógico y físico en tercera forma normal y justificar cualquier desnormalización.
3. **OE3 · Integridad.** Implementar en T-SQL las tablas y las reglas, priorizando las restricciones declarativas, de modo que la base rechace los datos inválidos y resista operaciones concurrentes.
4. **OE4 · Datos y consultas.** Cargar datos sintéticos coherentes y reproducibles, y responder preguntas de negocio con al menos quince consultas documentadas, ejecutadas desde Python.
5. **OE5 · Validación y nube.** Verificar con pruebas automatizadas y controles de conciliación, y preparar el despliegue en Azure SQL Database.

## Alcance

**Dentro del alcance:** red doméstica de Estados Unidos con 13 aeropuertos y 22 rutas activas; dos cabinas (VIP y económica); tiquetes de un tramo; compras con varios tiquetes (familias, ida y vuelta); pagos múltiples con distintos métodos; un descuento por tiquete; cancelación y reembolso; flota con configuraciones de asientos; tripulación con roles; estados y auditoría de cambios.

**Fuera del alcance:** impuestos y tasas, gestión dinámica de ingresos, sobreventa deliberada (*overbooking*) y compensaciones, equipaje y abordaje, programa de millas, conexiones con tarifa combinada, mantenimiento de aeronaves, cumplimiento normativo completo y sistemas reales de distribución. Los costos de operación tampoco se registran; por eso el informe **no** calcula rentabilidad.

# Requisitos y reglas de negocio

## Fuentes y discrepancias

Se revisaron cuatro documentos: el enunciado del producto en el aula virtual, el sílabo y dos guías de aprendizaje (una general y otra identificada como «VIERNES»). Las guías añaden dos requisitos que no figuran en el texto del aula virtual: subir los scripts a GitHub y exponer de 10 a 15 diapositivas en 20 minutos con participación aleatoria de todos los integrantes. Se registraron doce discrepancias entre documentos; las más relevantes son la semana de entrega del avance (semana 2, 3 o 4 según el documento), un resultado de aprendizaje de otra asignatura copiado en ambas guías, años de edición incorrectos en dos libros de lectura y la ausencia de un número mínimo de páginas, que la rúbrica menciona pero ningún documento fija. No se asumió que la guía «VIERNES» fuera la vigente; cada discrepancia queda anotada con su tratamiento en el anexo y en `docs/00_fuentes/revision_fuentes.md`.

## Actores y casos de uso

Los actores son el cliente registrado, el comprador sin registro, el agente de ventas (mostrador de aeropuerto u oficina de ciudad), el planificador de operaciones, el analista y el administrador de la base de datos. Se definieron trece casos de uso, desde «registrar persona» y «emitir tiquete» hasta «cancelar vuelo», «asignar tripulación» y «consultar indicadores».

## Decisiones de dominio

Las ambigüedades del enunciado se resolvieron con decisiones explícitas, que son también las primeras preguntas de cualquier defensa:

Table: Decisiones de dominio adoptadas

| Ambigüedad | Decisión | Consecuencia en el modelo |
|----------|----------------|--------------|
| Pasajero, comprador y cliente | Toda persona puede comprar o viajar; «cliente» es la persona con cuenta registrada | `ven.persona` (supertipo) y `ven.cliente` (subtipo 1:0..1) |
| Compra sin registro | Se registra la persona sin cuenta | El comprador no registrado es una `persona` sin fila en `cliente` |
| Ruta, horario y vuelo | La ruta es el par origen-destino; la programación fija número, hora y días; el vuelo es una salida fechada | `ops.ruta`, `ops.programacion`, `ops.programacion_dia`, `ops.vuelo` |
| Localizaciones físicas y web | Aeropuertos, oficinas y canales web son localizaciones; el aeropuerto es un subtipo | `ref.localizacion` y `ref.aeropuerto` con clave foránea compuesta |
| Capacidad y asientos | La capacidad es por vuelo y cabina; el asiento es opcional al reservar | `ops.vuelo_cabina` (inventario) y asiento validado contra el mapa del avión |
| Precio histórico | El tiquete conserva el precio y el porcentaje de descuento de la venta | Copia inmutable en `ven.tiquete`; tarifas versionadas por vigencia |
| Descuentos | Un solo descuento por tiquete: el de mayor porcentaje aplicable | Sin acumulación; reglas de cabina, vigencia, anticipación y registro |
| Pagos | Varios pagos por tiquete; estados pendiente, confirmado, rechazado y anulado | Emisión automática al completar el pago; vencimiento a las 72 h |
| Cancelación y reembolso | Política por cabina y antelación, regla de 24 horas y reembolso total si cancela la aerolínea | `ven.fn_politica_reembolso` y reembolsos ligados al pago |
| Estados | Transiciones válidas como datos | `ref.estado_*` y `ref.transicion_*` |
| Zonas horarias | Horas locales con desfase; transacciones en UTC | `datetimeoffset` en vuelos, `datetime2` en UTC en ventas |
| Asignación de avión y tripulación | Sin solapes y con tiempo mínimo en tierra; tripulación completa para despegar | Triggers con bloqueo del recurso |

La regla de 24 horas sigue la exigencia del Departamento de Transporte de Estados Unidos: para reservas hechas con al menos siete días de antelación, la aerolínea debe permitir mantenerlas sin pago o cancelarlas sin penalidad durante 24 horas (Customer Service Plan, 2026). Se modeló la segunda opción.

## Reglas verificables

Las reglas se numeraron de RN-01 a RN-42, y cada una indica el mecanismo que la garantiza: restricción declarativa (D), trigger (T), procedimiento (P) o verificación por consulta (A). La tabla siguiente resume la distribución; el detalle completo está en `docs/01_requisitos/analisis_requisitos.md`.

Table: Reglas de negocio según el mecanismo que las garantiza

| Mecanismo | Ejemplos | Reglas |
|------|----------------------|---|
| Declarativo (D) | Origen distinto de destino; asiento único por vuelo (índice filtrado); cabina del tiquete existente en el vuelo (clave foránea compuesta); precio final calculado | 16 |
| Trigger (T) | Transiciones de estado; solapes de avión y tripulación; tarifa vigente; inventario; inmutabilidad del precio; pagos y reembolsos | 20 |
| Procedimiento (P) | Política de reembolso; saldo disponible con mensaje de negocio (respaldado por trigger) | 2 |
| Combinado (D + T, T + P) | Sin sobreventa (CHECK + trigger); descuentos (CHECK + trigger); pagos solo sobre reservas (trigger + procedimiento) | 3 |
| Verificación (A) | Inventario igual a tiquetes activos | 1 |
| **Total** | | **42** |

Trece supuestos (SUP-01 a SUP-13) completan lo que el enunciado no fija: por ejemplo, 72 horas como plazo para pagar una reserva, un tripulante de cabina por cada 50 asientos o que la base no impone los límites de horas de vuelo de la normativa aeronáutica, aunque una consulta los vigila.

Los requisitos no funcionales son: despliegue en Azure SQL Database (RNF-01), consultas desde Python (RNF-02), scripts en GitHub (RNF-03), reproducibilidad con semilla fija (RNF-04), conexiones cifradas sin secretos en el repositorio (RNF-05), compatibilidad desde SQL Server 2016 SP1 (RNF-06), control de concurrencia (RNF-07) y separación de privilegios (RNF-08).

# Fundamentos conceptuales

**Base de datos y modelo relacional.** Una base de datos es una colección organizada de información que un sistema gestor almacena, protege y pone a disposición de las aplicaciones (Microsoft, 2023). Codd (1970) propuso representar los datos como relaciones (tablas) de tuplas, manipuladas con operaciones de conjuntos e independientes de su almacenamiento físico. Las claves identifican cada fila; las claves foráneas expresan las relaciones entre tablas y permiten al motor rechazar referencias inexistentes. Elmasri y Navathe (2011) y Silberschatz et al. (2020) distinguen tres niveles de diseño: el conceptual (entidades y relaciones del negocio), el lógico (relaciones, claves y dependencias, independiente del producto) y el físico (tipos, índices y restricciones de un motor concreto). Este proyecto sigue esa secuencia.

**Normalización.** Una dependencia funcional X → Y indica que el valor de X determina el de Y. La primera forma normal exige atributos atómicos; la segunda elimina las dependencias parciales de una clave compuesta; la tercera elimina las dependencias transitivas entre atributos no clave (Elmasri & Navathe, 2011). El objetivo práctico es evitar anomalías de inserción, actualización y eliminación: que un dato se repita en muchas filas y pueda quedar inconsistente.

**Integridad declarativa y procedimental.** SQL permite expresar reglas como restricciones (`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `NOT NULL`) que el motor aplica a cualquier cliente y en cualquier carga (Yaseen, 2019). Las reglas que involucran varias filas o tablas requieren triggers o procedimientos. Una restricción declarativa es preferible cuando basta, porque es más simple, más rápida y el optimizador la aprovecha. Los índices únicos filtrados de SQL Server permiten imponer unicidad solo sobre un subconjunto de filas, por ejemplo los tiquetes activos (Microsoft, s. f.-b).

**Transacciones y aislamiento.** Una transacción es una unidad atómica: o se aplican todos sus cambios o ninguno. El nivel de aislamiento determina qué ve una transacción de las demás. Berenson et al. (1995) mostraron que las definiciones del estándar no describen todas las anomalías posibles; entre ellas, la escritura sesgada (*write skew*): dos transacciones leen el mismo estado, cada una valida una regla y ambas escriben, de modo que el resultado conjunto viola la regla (Kleppmann, 2017). SQL Server ofrece lectura confirmada con versiones de fila (`READ_COMMITTED_SNAPSHOT`), predeterminada en Azure SQL Database, en la que las lecturas no bloquean a las escrituras (Microsoft, s. f.-e). Con ese nivel, las validaciones que deciden una escritura deben leer con bloqueo para no basarse en una versión antigua.

**Tiempo y zonas horarias.** Un instante se representa sin ambigüedad en UTC; la hora que ve el pasajero es local. El tipo `datetimeoffset` guarda ambas cosas y la función `AT TIME ZONE` convierte entre zonas teniendo en cuenta el horario de verano, a partir de la lista de zonas que publica `sys.time_zone_info` (Microsoft, s. f.-a).

**Protección de datos personales.** El enmascaramiento dinámico de datos oculta parcialmente valores sensibles a los usuarios sin privilegio, sin cambiar los datos almacenados; no es cifrado y debe combinarse con permisos y auditoría (Microsoft, s. f.-d).

# Modelado y normalización

## Modelo conceptual

El modelo conceptual (figura 1) identifica las cosas del negocio que deben recordarse. Simplifica deliberadamente algunos detalles para leerse en una página: la relación aeropuerto-ruta aparece una vez aunque son dos (origen y destino) y la tripulación se muestra como relación muchos a muchos entre empleado y vuelo.

![Modelo conceptual. Fuente: `docs/02_modelo/diagramas/conceptual.mmd`.](../../docs/02_modelo/diagramas/conceptual.png){width=100%}

La entidad clave para el control de inventario es `CUPO_CABINA`: la capacidad de una cabina en un vuelo concreto. Separarla del vuelo permite controlar la venta por cabina y bloquear una sola fila al vender, como se explica en la sección de implementación.

## Modelo lógico

El modelo lógico se presenta en cuatro áreas temáticas (figuras 2 a 5) para que cada diagrama se lea a tamaño de página. Cada relación tiene clave primaria (PK); las claves foráneas (FK) implementan las relaciones del modelo conceptual, las claves únicas (UK) conservan las claves naturales y las entidades asociativas resuelven las relaciones muchos a muchos (asignación de tripulación, días de operación y asientos por configuración). Las entidades que aparecen solo con su clave pertenecen a otra área.

![Modelo lógico: red, horarios y vuelos. Fuente: `docs/02_modelo/diagramas/logico_red_vuelos.mmd`.](../../docs/02_modelo/diagramas/logico_red_vuelos.png){height=21cm}

![Modelo lógico: flota y tripulación. Fuente: `docs/02_modelo/diagramas/logico_flota_tripulacion.mmd`.](../../docs/02_modelo/diagramas/logico_flota_tripulacion.png){width=100%}

![Modelo lógico: personas, compras y tiquetes. Fuente: `docs/02_modelo/diagramas/logico_personas_tiquetes.mmd`.](../../docs/02_modelo/diagramas/logico_personas_tiquetes.png){width=100%}

![Modelo lógico: precios, pagos y reembolsos. Fuente: `docs/02_modelo/diagramas/logico_precios_pagos.mmd`.](../../docs/02_modelo/diagramas/logico_precios_pagos.png){height=19cm}

## Normalización

Se partió de una «planilla de ventas» plana, con una fila por tiquete y columnas para el vuelo, el avión, el comprador, el pasajero, los pagos y los reembolsos. Esa estructura viola la primera forma normal (los pagos y los días de operación son listas) y produce todas las anomalías clásicas: no se puede registrar un avión hasta venderle un tiquete, cambiar la hora de un vuelo exige modificar miles de filas y borrar los tiquetes de un vuelo cancelado elimina la información del avión.

La descomposición siguió las dependencias funcionales:

Table: Descomposición de las dependencias transitivas de la planilla de ventas

| Dependencia transitiva en la planilla | Relaciones resultantes |
|---|---|
| tiquete → vuelo → programación → ruta → aeropuertos | `ven.tiquete`, `ops.vuelo`, `ops.programacion`, `ops.ruta`, `ref.aeropuerto` |
| vuelo → avión → configuración → modelo | `ops.avion`, `ops.configuracion_asientos`, `ref.modelo_avion` |
| código de reserva → comprador, canal, vendedor, fecha | `ven.compra` (agrupa varios tiquetes) |
| documento → nombre de la persona | `ven.persona` |
| cargo → departamento, categoría de tripulación | `rh.cargo`, `rh.departamento` |
| estado → descripción, ocupa inventario, es final | `ref.estado_vuelo`, `ref.estado_tiquete`, `ref.estado_pago` |

Todas las relaciones con clave compuesta se revisaron para la segunda forma normal: en `ops.vuelo_cabina` la capacidad depende del vuelo **y** de la cabina, y en `ops.asignacion_tripulacion` el rol es del empleado **en ese vuelo**. La mayoría de las relaciones cumple además la forma normal de Boyce-Codd: sus únicos determinantes son claves candidatas. Las reglas de no solapamiento (vigencias de tarifas y de horarios) no son dependencias funcionales y se garantizan con triggers.

## Desnormalizaciones controladas

El diseño acepta seis redundancias, cada una con un mecanismo que impide la anomalía correspondiente:

Table: Desnormalizaciones controladas y mecanismo que evita sus anomalías

| Redundancia | Motivo | Control |
|----------|-------------|----------------|
| Precio base y porcentaje de descuento copiados en el tiquete | El precio pactado es un hecho de la venta; si la tarifa cambia, el tiquete vendido no debe cambiar | El trigger verifica que la copia coincide con la tarifa y el descuento vigentes al vender; el precio del tiquete es inmutable y una tarifa usada no se edita: se crea otra versión |
| Contador de plazas ocupadas por vuelo y cabina | Evitar contar tiquetes en cada venta y disponer de una fila que bloquear ante ventas simultáneas | Lo mantiene el trigger en la misma transacción; un `CHECK` impide superar la capacidad; una vista y una prueba concilian el contador con el recuento real |
| Capacidad por vuelo y cabina | El vuelo se vende antes de asignarle avión | Se sincroniza al asignar avión; se prohíbe cambiar a una configuración distinta con ventas activas |
| Fecha local de salida del vuelo | Clave natural «XX101 del 6 de noviembre» | Columna calculada persistida, no editable |
| Tipo de localización constante en aeropuerto | Garantizar que el subtipo solo apunte a localizaciones de tipo aeropuerto | Columna calculada y clave foránea compuesta |
| Cabina en el tiquete junto a la tarifa | Dos claves foráneas compuestas: la cabina existe en el vuelo y la tarifa es de esa cabina | Restricciones declarativas |

Una decisión relacionada es **no** declarar una clave foránea del asiento del tiquete hacia el mapa de asientos: el mapa depende del avión asignado al vuelo, de modo que guardar la configuración en el tiquete crearía una dependencia transitiva que quedaría desactualizada al cambiar de avión. La existencia del asiento en la cabina correcta se valida con un trigger.

# Diccionario de datos

El diccionario se genera desde el catálogo del motor con `python -m aerolinea documentar`: tipos, longitudes, nulabilidad, valores por defecto, claves, restricciones `CHECK`, columnas calculadas y enmascaradas se leen de las vistas del sistema, y las definiciones de negocio se toman de un archivo mantenido por el equipo (`docs/02_modelo/definiciones_atributos.csv`). Así el diccionario coincide con el código por construcción. El resultado cubre 41 tablas y 269 columnas, todas con definición; se publica en Markdown, CSV y Excel, y como propiedades extendidas `MS_Description` visibles en SSMS (`sql/13_descripciones.sql`).

La tabla siguiente muestra, como ejemplo, la tabla central del modelo; el diccionario completo está en `docs/02_modelo/diccionario_datos.md` y el diagrama físico de ventas en el anexo C.

[[TABLA:DICCIONARIO_TIQUETE]]

Convenciones de nombres: tablas y columnas en español, en minúsculas y con guion bajo; claves sustitutas `id_*`; restricciones con prefijo por tipo (`pk_`, `fk_`, `uq_`, `ck_`, `df_`, `ix_`, `ux_`); importes en `decimal(10,2)` con sufijo `_usd`; instantes transaccionales en `datetime2(0)` con sufijo `_utc`.

# Arquitectura local y en la nube

![Arquitectura de la solución. Fuente: `docs/03_arquitectura/arquitectura.mmd`.](../../docs/03_arquitectura/arquitectura.png){width=85%}

La figura 6 resume los componentes y las conexiones. La base se organiza en esquemas temáticos: `ref` (catálogos), `ops` (operación), `rh` (personal), `ven` (ventas), `rpt` (vistas de reporte), `aud` (auditoría), `adm` (registro de despliegue), `stg` (área de carga) y `tst` (pruebas). La separación permite conceder permisos por área —por ejemplo, el analista solo lee `rpt`— y deja visible la frontera entre datos operativos y analíticos.

**Entorno local.** El equipo dispone de una laptop Windows con SQL Server (instancia predeterminada `MSSQLSERVER`, en `localhost`) y usará autenticación de Windows. SSMS se usa para administrar y ejecutar scripts; el motor guarda los datos y garantiza las reglas; Python ejecuta las tareas reproducibles. La conexión local por memoria compartida no requiere habilitar TCP/IP, SQL Server Browser ni SQL Server Agent. El controlador ODBC 18 cifra la conexión por defecto; como la instancia local usa un certificado autofirmado, en desarrollo se acepta ese certificado (`TrustServerCertificate=yes`) solo para `localhost`, manteniendo el cifrado. La verificación de versión, edición, permisos, Python y controlador está automatizada en un script de solo lectura y **queda pendiente de ejecutar en la laptop**.

**Entorno de nube.** El mismo código T-SQL se despliega en Azure SQL Database. Las diferencias relevantes se resolvieron en el diseño: los scripts no usan `USE` (en Azure no cambia de base), la base se crea desde el portal o la CLI, la autenticación es de Microsoft Entra ID, el certificado del servidor se valida siempre y `READ_COMMITTED_SNAPSHOT` está activo por defecto, igual que en la configuración local elegida. Se propone la oferta gratuita de Azure SQL Database (General Purpose serverless con un límite mensual de cómputo y pausa automática al agotarlo) para no generar costos (Microsoft, s. f.-c), con acceso restringido por firewall a la IP del equipo. El script `scripts/azure/crear_recursos_azure.ps1` solo muestra los comandos salvo que se confirme explícitamente, y `sql/azure/verificacion_azure.sql` reúne las evidencias de solo lectura. **No se creó ningún recurso**: el despliegue requiere una suscripción y la autorización del equipo.

**Compatibilidad.** El código evita funciones posteriores a SQL Server 2016 SP1 (por ejemplo `STRING_AGG`, `TRIM` o `GREATEST`). Se ejecutó en SQL Server 2022 con el nivel de compatibilidad 160 y, de nuevo, con el nivel 130 (SQL Server 2016), con los mismos resultados; no se probó en un motor 2016, 2017 o 2019 real.

# Implementación SQL y Python

## Scripts T-SQL

La base se construye con scripts numerados, idempotentes (pueden ejecutarse de nuevo sin error) y protegidos contra la ejecución accidental en bases del sistema:

Table: Scripts T-SQL del despliegue

| Script | Contenido |
|---|-----------------|
| 01 | Creación de la base local con intercalación `SQL_Latin1_General_CP1_CI_AS` y `READ_COMMITTED_SNAPSHOT` |
| 02-04 | Esquemas, secuencias, 41 tablas, restricciones e índices |
| 05 | Funciones (calendario ISO, política de reembolso) y 12 triggers de reglas de negocio |
| 06-07 | 9 vistas de reporte y 16 procedimientos almacenados de negocio |
| 08 | Roles, permisos y enmascaramiento dinámico |
| 09-10 | Datos de referencia y procedimiento de carga sintética |
| 11 | Ejemplos de `INSERT`, `UPDATE` y `DELETE` seguros (fuera del despliegue) |
| 12-13 | Pruebas automatizadas (4 procedimientos del esquema `tst`) y descripciones `MS_Description` |
| 99 | Eliminación de la base local: separado, con confirmación explícita y rechazo de Azure |

`GO` no es una instrucción del motor sino un separador que interpretan SSMS y `sqlcmd`; la aplicación divide los lotes del lado del cliente respetando comentarios anidados y cadenas de texto.

## Reglas en el motor

La mayoría de las reglas se expresa con restricciones declarativas. Algunos ejemplos representativos:

```sql
-- Un asiento no se vende dos veces en el mismo vuelo (solo cuentan los tiquetes activos).
CREATE UNIQUE INDEX ux_tiquete_vuelo_asiento ON ven.tiquete (id_vuelo, codigo_asiento)
WHERE codigo_asiento IS NOT NULL
  AND codigo_estado IN ('RESERVADO', 'EMITIDO', 'USADO', 'NO_PRESENTADO');

-- La cabina del tiquete existe en el vuelo y la tarifa es de esa misma cabina.
ALTER TABLE ven.tiquete ADD
  CONSTRAINT fk_tiquete_vuelo_cabina FOREIGN KEY (id_vuelo, codigo_cabina)
      REFERENCES ops.vuelo_cabina (id_vuelo, codigo_cabina),
  CONSTRAINT fk_tiquete_tarifa_cabina FOREIGN KEY (id_tarifa, codigo_cabina)
      REFERENCES ven.tarifa (id_tarifa, codigo_cabina);
```

Las reglas entre filas o tablas usan triggers escritos en forma de conjuntos: validan todas las filas de `inserted` y `deleted`, de modo que funcionan igual con un tiquete que con una carga de 300 000. Ante una violación lanzan un error numerado (50001-50069) con un mensaje que cita la regla; los procedimientos usan la serie 501xx y traducen los errores del motor a mensajes de negocio. Los estados válidos y sus transiciones son datos (`ref.transicion_*`), no listas fijas en el código.

## Control de concurrencia

Cuatro mecanismos impiden las anomalías de las operaciones simultáneas:

1. **Inventario como semáforo.** Al vender, el trigger lee la fila de `ops.vuelo_cabina` con bloqueo de actualización (`UPDLOCK`): la segunda venta del mismo vuelo y cabina espera a que la primera termine, mientras que las ventas de otros vuelos no se bloquean. Una restricción `CHECK (plazas_ocupadas <= capacidad)` es la última barrera.
2. **Asiento único.** El índice único filtrado garantiza que solo una transacción obtenga un asiento; la otra recibe un error que el procedimiento traduce a «asiento ocupado».
3. **Pagos serializados por tiquete.** El procedimiento y el trigger de pagos bloquean la fila del tiquete antes de sumar lo cobrado.
4. **Solapes de avión y tripulación.** Se bloquea el recurso (avión o empleado) y se revisa su agenda ordenada con la función `LAG`.

Se descartaron `SERIALIZABLE` en todas las transacciones (bloqueos amplios e interbloqueos), `SNAPSHOT` (no evita la escritura sesgada entre filas distintas) y los bloqueos de aplicación (quedan fuera del modelo de datos).

## Procedimientos de negocio

`ven.usp_emitir_tiquete` busca la tarifa vigente en la fecha de venta, valida y aplica el descuento, calcula el plazo de pago (el menor entre 72 horas y tres horas antes de la salida), genera el código de reserva y el número de tiquete, y deja el tiquete en `RESERVADO`. `ven.usp_registrar_pago` bloquea el tiquete, verifica el saldo y, al completarse el pago, emite el tiquete. `ven.usp_cancelar_tiquete` aplica la política mediante `ven.fn_politica_reembolso`, anula los pagos pendientes y reparte el reembolso entre los pagos confirmados. `ops.usp_generar_vuelos` crea los vuelos fechados a partir de la programación semanal, convirtiendo la hora local de salida a la zona del aeropuerto de origen y la llegada a la del destino; es idempotente. Todos usan `SET XACT_ABORT ON`, `TRY/CATCH` y transacción propia solo si no hay una abierta.

## Aplicación de Python

La aplicación (`src/aerolinea`) se ejecuta con `python -m aerolinea <comando>`. Lee la configuración de un archivo `.env` o de variables de entorno, elige el controlador ODBC 18 o 17, admite autenticación de Windows, SQL o Microsoft Entra ID y rechaza configuraciones inseguras para Azure (sin cifrado o sin validar el certificado). Las consultas se ejecutan siempre con parámetros enlazados: los valores de ejemplo de cada consulta se sustituyen por marcadores `?` y se envían por separado, de modo que la entrada del usuario nunca se concatena en el texto SQL. Los procedimientos con parámetros de salida se invocan con un lote `DECLARE … EXEC … SELECT`, porque pyodbc no los admite de forma directa.

Tres detalles de implementación resultaron decisivos y se descubrieron con pruebas: recorrer todos los conjuntos de resultados con `nextset()` para que un error de una sentencia posterior del lote no pase inadvertido; convertir el tipo `datetimeoffset`, que pyodbc no reconoce; y desactivar el *pooling* de conexiones del administrador de controladores, que en Linux reutilizaba sesiones sin restablecerlas y trasladaba una transacción abierta de una conexión a la siguiente (hallazgo H-13).

# Datos y metodología de validación

## Datos sintéticos reproducibles

Los datos de referencia (13 aeropuertos, 19 localizaciones, 24 rutas, 32 programaciones, 17 aviones con 586 asientos en 4 configuraciones, 96 tarifas, 6 descuentos y 353 empleados) se insertan con T-SQL. Los datos transaccionales los genera `generador.py` con una semilla fija (20261106) y una fecha de corte (1 de noviembre de 2026, 00:00 UTC): ventas desde el 1 de julio y operación desde el 1 de septiembre hasta el 31 de diciembre de 2026.

Table: Volumen de datos sintéticos cargados

| Tabla | Filas |
|---|---|
| Vuelos (`ops.vuelo`) | 3 588 |
| Asignaciones de tripulación | 20 064 |
| Personas / clientes registrados | 232 096 / 30 000 |
| Compras | 168 928 |
| Tiquetes | 323 718 |
| Pagos | 388 003 |
| Reembolsos | 18 182 |
| Cambios de estado auditados | 1 248 064 |

El generador incluye a propósito casos difíciles: compras sin registro, viajes de ida y vuelta, pagos en dos o tres partes, pagos rechazados, reservas que vencen, cancelaciones dentro de las 24 horas, cancelaciones de vuelos, demoras propagadas por avión, no presentados, mantenimiento programado con avión de reserva, cambio de horario del 1 de noviembre y llegadas al día siguiente. Los archivos CSV generados tienen una huella SHA-256 registrada en un manifiesto, de modo que cualquier ejecución con la misma semilla puede comprobarse byte a byte.

La carga pasa por tablas de staging y se aplica en **una sola transacción con todas las restricciones y triggers activos**. Si un dato viola una regla, la transacción entera se revierte. Que la carga termine es, por tanto, una prueba de integración: las casi 1,2 millones de filas cargadas cumplen todas las reglas (además, los triggers registran 1,25 millones de cambios de estado en la auditoría).

## Niveles de prueba

Table: Niveles de prueba

| Nivel | Qué verifica | Herramienta |
|----|--------------|--------|
| Aplicación | División de lotes, configuración segura, escape de credenciales, traducción de errores, documentación de consultas, política de reembolso | pytest (23 pruebas) |
| Reglas de la base | Cada regla crítica se intenta violar y se comprueba el rechazo con el número de error esperado; los casos válidos se ejecutan de punta a punta | `tst.usp_ejecutar_pruebas` (PR-01 a PR-23) |
| Concurrencia | Sobreventa, asiento duplicado, doble cobro y asignación automática de asiento con sesiones simultáneas reales | Hilos con una conexión cada uno y una barrera de arranque (PC-01 a PC-04) |
| Integración | Que los datos sintéticos cumplan todas las reglas | Carga transaccional |
| Consultas | Que las consultas midan lo que dicen | Controles de conciliación y recuperación de parámetros conocidos del generador |

Una prueba se declara superada solo si se observó su resultado. Las pruebas crean sus escenarios en vuelos reservados para ese fin y los eliminan al terminar, sin alterar los datos analizados.

**Validación por parámetros conocidos.** Como el generador fija algunas probabilidades (42 % de compradores registrados, 5 % de cancelaciones voluntarias, 4,5 % de no presentados), una consulta correcta debe recuperar valores cercanos. Esto valida las consultas, pero no dice nada sobre el mundo real.

# Resultados y discusión

## Resultados de las pruebas

Todas las pruebas ejecutadas en el contenedor de validación se superaron. La tabla resume cada caso; el detalle observado está en `evidence/contenedor_linux/resultados_pruebas.md`.

[[TABLA:PRUEBAS]]

Las pruebas de concurrencia son las más ilustrativas: con 40 sesiones que intentan comprar a la vez en una cabina VIP de 12 asientos, exactamente 12 tienen éxito y 28 reciben el error de falta de disponibilidad; con 20 sesiones que piden el mismo asiento, solo una lo obtiene; con 10 pagos simultáneos del total, solo uno se confirma. La versión inicial de la asignación automática de asiento falló esta prueba —solo 6 de 30 sesiones tuvieron éxito porque todas elegían a la vez «el primer asiento libre»— y se corrigió serializando la asignación con el semáforo del vuelo y la cabina.

## Hallazgos del desarrollo

Las pruebas y las cargas detectaron 20 defectos reales que se corrigieron antes de entregar. Los más instructivos fueron: el plan de ejecución de los triggers compilado para una fila y reutilizado para cientos de miles (corregido con recompilación); un error de lógica de tres valores que permitía asignar como capitán a un empleado sin categoría (`NOT (x = 'TECNICA')` es desconocido si `x` es nulo); el efecto manada en la asignación de asientos; la transacción heredada por el *pooling* de conexiones; y una planificación sintética de tripulaciones que superaba las 100 horas de vuelo en 28 días, detectada por la propia consulta de control. El registro completo, con causa, corrección y evidencia, está en el anexo B.

## Resultados de las consultas

Se definieron 20 consultas documentadas con su pregunta de negocio, utilidad, granularidad, filtros, fórmulas, técnicas SQL, resultado ejecutado e interpretación (`docs/07_consultas/catalogo_consultas.md`). Cubren uniones internas y externas, filtros temporales, `GROUP BY` con `HAVING` y `GROUPING SETS`, subconsultas y CTE, vistas, funciones de ventana (`RANK`, `DENSE_RANK`, `LAG`, `SUM() OVER`, `PERCENTILE_CONT`), anti-joins y `OUTER APPLY`. La tabla siguiente muestra la ejecución registrada en el manifiesto.

[[TABLA:CONSULTAS]]

**Ventas, cobros y reembolsos.** La figura 7 y la tabla siguiente separan tres magnitudes que suelen confundirse: la venta (precio final de los tiquetes creados en el mes), el cobro (pagos confirmados por su fecha de confirmación) y el reembolso (dinero devuelto por su fecha). Cada una se agrega por su propia fecha en una expresión separada, porque unir pagos y reembolsos antes de agregar multiplicaría los importes: una prueba específica (PR-20) muestra que una unión ingenua infla el cobro de 72,27 a 87,78 millones de USD.

[[TABLA:Q03]]

![Ventas, cobros y reembolsos por mes (Q03). Fuente: `reports/figuras/F02_flujo_mensual.png`.](../figuras/F02_flujo_mensual.png){width=95%}

Los cobros del período (72,27 millones de USD) superan a las ventas vigentes (68,39 millones) sin que haya error: incluyen dinero que luego se devolvió y penalidades retenidas por cancelaciones. La consulta de controles (Q19) verifica la identidad completa —cobros menos reembolsos igual a ventas emitidas más abonos de reservas vigentes más penalidades retenidas— con una diferencia de 0,00 USD. No se calcula rentabilidad, porque el modelo no registra costos.

**Saldos pendientes.** A la fecha de corte quedan 824 reservas por pagar, con 122 943,56 USD de saldo; 118 vencen en menos de 24 horas.

[[TABLA:Q04]]

**Cancelaciones y reembolsos.** Se cancelaron 22 728 tiquetes; de 4,00 millones de USD cobrados en ellos se devolvieron 3,03 millones. La regla de 24 horas y las cancelaciones de vuelo reembolsan el 100 %; las cancelaciones voluntarias fuera de esa regla siguen la política por cabina, con un porcentaje medio aplicado de 56,8 % en económica y 79,9 % en VIP. La regla y el porcentaje se recalculan con la misma función que usa el procedimiento de cancelación, y la prueba PR-22 confirma que coinciden en los 22 728 casos. La tasa de reembolso se define como nula cuando no hubo cobro, para distinguir «no había nada que devolver» de «se devolvió el 0 %».

[[TABLA:Q05]]

**Ocupación.** El factor de ocupación ponderado del período es 68,9 % en económica y 53,0 % en VIP (figura 8). El factor ponderado (asientos usados entre asientos ofrecidos) difiere ligeramente del promedio simple de los factores por vuelo porque los aviones tienen capacidades distintas; para la red corresponde el ponderado. La distribución por vuelo (figura 9) tiene mediana de 67,0 %, con 77 vuelos por encima del 85 % y 92 por debajo del 50 %.

![Ocupación por ruta y cabina (Q02). Fuente: `reports/figuras/F01_ocupacion_ruta_cabina.png`.](../figuras/F01_ocupacion_ruta_cabina.png){width=100%}

![Distribución de la ocupación por vuelo (Q01). Fuente: `reports/figuras/F07_distribucion_ocupacion.png`.](../figuras/F07_distribucion_ocupacion.png){width=90%}

**Demanda en el tiempo.** La ocupación es mayor los viernes y domingos y menor martes y miércoles (figura 10), patrón que reproduce los factores por día de la semana del generador y valida el cálculo del día ISO, independiente de la configuración regional de la sesión. Respecto de la anticipación (figura 11), el precio medio en económica baja de 206,82 USD para compras con menos de siete días a 179,94 USD para compras con 60 días o más, mientras la penetración de descuentos sube de 13,6 % a 47,1 %. La asociación es descriptiva: se explica por cómo se construyeron las tarifas y el descuento por anticipación, y no demuestra que comprar antes cause un precio menor en un mercado real.

![Ocupación por día de la semana y franja de salida (Q11). Fuente: `reports/figuras/F06_demanda_dia_franja.png`.](../figuras/F06_demanda_dia_franja.png){width=95%}

![Anticipación de compra y precio (Q12). Fuente: `reports/figuras/F04_anticipacion_compra.png`.](../figuras/F04_anticipacion_compra.png){width=100%}

[[TABLA:Q12]]

**Canales y clientes.** El canal web concentra el 70,0 % de las ventas vigentes (figura 12). El 41,9 % de las compras las hizo un comprador registrado, valor que recupera el 42 % del generador y valida la lógica de «registrado en el momento de la compra». Las compras sin registro no se pueden atribuir de forma fiable a una misma persona, una limitación inherente a ese tipo de compra. Precio medio, tasa de cancelación y uso del canal web son casi iguales entre registrados y no registrados porque el generador no los diferencia; con datos reales, esta consulta sería el punto de partida para compararlos.

![Ventas por punto de venta y canal (Q07). Fuente: `reports/figuras/F03_ventas_canal.png`.](../figuras/F03_ventas_canal.png){width=90%}

[[TABLA:Q08]]

**Precios y descuentos.** La tasa de descuento efectiva, ponderada por importe, es de 3,4 % a 3,8 % en económica y de 0,9 % a 1,5 % en VIP, muy por debajo de los porcentajes nominales (10 % a 20 %) porque se reparte entre todos los tiquetes. El descuento para clientes VIP registrados (`VIPPLUS5`) nunca se aplica: con la política de un solo descuento, el de mayor porcentaje, todo comprador que califica para él califica también para `CLIENTE10`. No es un error de datos, sino una consecuencia de la regla que convendría revisar al diseñar promociones.

[[TABLA:Q20]]

**Operación.** De 1 767 vuelos operados, el 78,4 % llegó con menos de 15 minutos de demora (figura 13), criterio que usa la estadística oficial de puntualidad de Estados Unidos (Bureau of Transportation Statistics, s. f.); se cancelaron 20 vuelos (1,1 %). Los A321neo de las líneas transcontinentales promedian de 10,0 a 11,2 horas de bloque diarias y los aviones de reserva solo vuelan los días de mantenimiento del titular (figura 14).

![Puntualidad de llegada por ruta (Q15). Fuente: `reports/figuras/F05_puntualidad_ruta.png`.](../figuras/F05_puntualidad_ruta.png){width=90%}

![Utilización de la flota (Q10). Fuente: `reports/figuras/F08_utilizacion_flota.png`.](../figuras/F08_utilizacion_flota.png){width=90%}

**Tripulación.** En la ventana de 672 horas consecutivas del 1 al 28 de octubre, ningún piloto supera las 100 horas de vuelo, la referencia de la normativa estadounidense (Cumulative Limitations, 2026); el máximo es 94,5 horas. La primera versión de los datos sintéticos sí la superaba (188 horas de máximo con dos equipos por línea y 105,8 con cuatro), y fue esta consulta la que lo detectó. La base no impone el límite; la consulta es un control a posteriori sobre una ventana.

[[TABLA:Q18]]

**Integridad.** Los nueve controles de Q19 devuelven cero diferencias:

[[TABLA:Q19]]

## Discusión

Los resultados respaldan la decisión central del diseño: poner las reglas en el motor. La carga masiva, las pruebas de reglas y las de concurrencia ejercen las mismas restricciones y triggers por caminos distintos (sentencias de conjunto, procedimientos y sesiones simultáneas), y en ninguno se pudo introducir un dato inválido. El costo de esa decisión fue de rendimiento y se hizo visible en la carga: los triggers escritos para una fila no escalaban a cientos de miles hasta reescribirlos en forma de conjuntos, con recompilación y sin el «objetivo de filas» del optimizador.

El análisis muestra también por qué importan las definiciones: ventas, cobros y reembolsos difieren legítimamente; el factor ponderado y el promedio simple de ocupación responden a preguntas distintas; un nulo y un cero significan cosas distintas en la tasa de reembolso. Las vistas de reporte fijan esas definiciones una sola vez.

Por último, la mayoría de los patrones analíticos reproduce supuestos del generador. Eso es útil para validar las consultas —si la consulta no recuperara el 42 % de compradores registrados, estaría mal—, pero impide extraer conclusiones de negocio. Con datos reales, las mismas consultas se convertirían en herramientas de decisión.

# Seguridad, limitaciones y trabajo futuro

## Seguridad

Se definieron cuatro roles con privilegio mínimo: el analista solo lee el esquema de reportes, ventas y operaciones ejecutan sus procedimientos, y la cuenta de la aplicación ejecuta procedimientos pero tiene denegada la escritura directa en las tablas de ventas y operaciones. Esto funciona por la cadena de propiedad: como todos los esquemas pertenecen a `dbo`, quien puede ejecutar un procedimiento puede modificar las tablas a través de él sin tener permiso sobre ellas. Seis columnas personales (correos, teléfono, documento, fecha de nacimiento y salario) se enmascaran para usuarios sin privilegio. De las tarjetas solo se guardan los últimos cuatro dígitos y la marca. Las conexiones van siempre cifradas, el repositorio no contiene secretos y los pagos, reembolsos y tiquetes no se eliminan: los errores se corrigen con nuevas filas y cada cambio de estado queda auditado.

## Limitaciones

- **Nube pendiente.** El requisito de base de datos en la nube no está cumplido mientras no se despliegue en Azure SQL Database con evidencia propia.
- **Entorno del equipo pendiente.** La validación se hizo en un contenedor Linux con SQL Server 2022; falta repetirla en la laptop Windows, donde también deben comprobarse la autenticación de Windows y SSMS.
- **Datos sintéticos.** Las cifras no describen un mercado real y varios patrones reproducen supuestos del generador.
- **Versiones del motor.** La compatibilidad con SQL Server 2016 se comprobó con el nivel de compatibilidad 130 en un motor 2022, no en un motor 2016 real.
- **Enmascaramiento no es cifrado.** Un usuario con consultas ad hoc puede inferir valores enmascarados.
- **Normativa.** No se modelan impuestos, límites de servicio de tripulación ni otras obligaciones regulatorias, salvo como controles por consulta.
- **Rendimiento.** Los tiempos medidos son del contenedor y no constituyen una prueba de carga.

## Trabajo futuro

Desplegar en Azure y comparar tiempos y planes con el entorno local; cifrar columnas sensibles con *Always Encrypted*; modelar conexiones y tarifas combinadas; incorporar costos para analizar rentabilidad por ruta; sustituir los datos sintéticos por datos abiertos de operación (por ejemplo, los de puntualidad del Departamento de Transporte) para análisis reales; automatizar las pruebas en un servicio de integración continua con un contenedor de SQL Server; e imponer en la base los límites de servicio de tripulación con ventanas móviles.

# Conclusiones

1. **OE1 · Requisitos.** Los requisitos del enunciado y de las guías se tradujeron en 42 reglas verificables y 13 supuestos explícitos, y las doce discrepancias entre documentos quedaron registradas sin asumir cuál prevalece. Las ambigüedades principales —pasajero frente a comprador, horario frente a vuelo, precio histórico, combinación de descuentos y pagos parciales— tienen una decisión documentada y una consecuencia concreta en el modelo.
2. **OE2 · Modelo.** El modelo conceptual, lógico y físico es coherente por construcción: el diccionario y los diagramas físicos se generan del catálogo del motor. El esquema está en tercera forma normal y las seis redundancias aceptadas tienen un mecanismo que impide sus anomalías, como lo demuestran los controles de conciliación con cero diferencias.
3. **OE3 · Integridad.** La base rechaza los datos inválidos en todos los casos probados: 23 de 23 pruebas de reglas y 4 de 4 de concurrencia superadas, sin sobreventa, asientos duplicados ni cobros dobles con sesiones simultáneas reales. La preferencia por restricciones declarativas y el uso de bloqueos sobre el recurso padre permitieron, además, cargar casi 1,2 millones de filas con todas las reglas activas en unos 90 segundos.
4. **OE4 · Datos y consultas.** Los datos sintéticos son reproducibles con una semilla y verificables por huella. Las 20 consultas documentadas se ejecutan desde Python con parámetros enlazados, exportan CSV y alimentan las figuras del informe; recuperan los parámetros conocidos del generador, lo que valida su lógica, y distinguen ventas, cobros y reembolsos sin multiplicar importes.
5. **OE5 · Validación y nube.** La validación local es amplia y está documentada con evidencias, incluidos 20 defectos reales corregidos. El despliegue en Azure SQL Database está preparado pero **no ejecutado**; hasta que el equipo lo realice con autorización, el requisito de nube del encargo debe considerarse pendiente.

# Recomendaciones

1. Ejecutar la verificación del entorno y la reproducción completa en la laptop Windows (`scripts/windows/verificar_entorno.ps1` y `python -m aerolinea reproducir`) y guardar las evidencias en `evidence/laptop_windows/`.
2. Desplegar en Azure SQL Database con la oferta gratuita y pausa automática, siguiendo `docs/05_azure/guia_azure.md`, y completar la lista de evidencias antes de la entrega.
3. Confirmar con el docente el número mínimo de páginas y la semana de entrega del avance, y completar los campos marcados como [POR COMPLETAR].
4. Invitar a los integrantes al repositorio de GitHub, ya publicado en https://github.com/CARLOSDELOSRIOS/aerolinea-bd-psma00611, y registrar los aportes reales de cada integrante.
5. Preparar la defensa con la guía de estudio común: como la exposición es aleatoria, cada integrante debe poder explicar cualquier sección.
6. Si el proyecto continúa, priorizar el cifrado de columnas sensibles y el uso de datos reales para que las consultas pasen de validar el modelo a apoyar decisiones.

# Referencias

Berenson, H., Bernstein, P., Gray, J., Melton, J., O'Neil, E., & O'Neil, P. (1995). A critique of ANSI SQL isolation levels. En *Proceedings of the 1995 ACM SIGMOD International Conference on Management of Data* (pp. 1–10). Association for Computing Machinery. https://doi.org/10.1145/223784.223785

Bureau of Transportation Statistics. (s. f.). *Flight operations arriving on time: Largest U.S. air carriers*. U.S. Department of Transportation. Recuperado el 27 de octubre de 2026, de https://www.bts.gov/content/flight-operations-arriving-time-largest-us-air-carriersa

Codd, E. F. (1970). A relational model of data for large shared data banks. *Communications of the ACM, 13*(6), 377–387. https://doi.org/10.1145/362384.362685

Cumulative limitations, 14 C.F.R. § 117.23 (2026). https://www.ecfr.gov/current/title-14/chapter-I/subchapter-G/part-117/section-117.23

Customer service plan, 14 C.F.R. § 259.5 (2026). https://www.ecfr.gov/current/title-14/chapter-II/subchapter-A/part-259/section-259.5

Elmasri, R., & Navathe, S. B. (2011). *Fundamentals of database systems* (6th ed.). Addison-Wesley.

Kleppmann, M. (2017). *Designing data-intensive applications: The big ideas behind reliable, scalable, and maintainable systems*. O'Reilly Media.

Microsoft. (s. f.-a). *AT TIME ZONE (Transact-SQL)*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/sql/t-sql/queries/at-time-zone-transact-sql

Microsoft. (s. f.-b). *Create filtered indexes*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes

Microsoft. (s. f.-c). *Deploy Azure SQL Database for free*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer

Microsoft. (s. f.-d). *Dynamic data masking*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/sql/relational-databases/security/dynamic-data-masking

Microsoft. (s. f.-e). *Transaction locking and row versioning guide*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide

Microsoft. (2023). *¿Qué son las bases de datos?* Microsoft Azure. https://azure.microsoft.com/es-es/resources/cloud-computing-dictionary/what-are-databases

Silberschatz, A., Korth, H. F., & Sudarshan, S. (2020). *Database system concepts* (7th ed.). McGraw-Hill Education.

Universidad Continental. (2026). *Producto académico colaborativo: Gestión de datos y bases de datos con SQL (PSMA00611)* [Enunciado del aula virtual]. Escuela de Posgrado.

Yaseen, A. (2019). *Restricciones en SQL Server* [Lectura del curso]. SQL Shack. https://www.sqlshack.com/es/restricciones-en-sql-server-sql-not-null-unique-y-sql-primary-key/

# Anexos

## Anexo A. Matriz de trazabilidad

Requisitos del encargo, documento y página de origen, archivos que los implementan, evidencia y estado. Tipo: OBL = obligatorio según las fuentes; MEJ = mejora propuesta por el equipo. La versión completa está en `docs/00_fuentes/matriz_requisitos.md`.

[[TABLA:MATRIZ]]

## Anexo B. Hallazgos corregidos durante el desarrollo

[[TABLA:HALLAZGOS]]

## Anexo C. Modelo físico del área de ventas

Diagrama generado desde el catálogo del motor. Los diagramas de las demás áreas están en `docs/02_modelo/diagramas/` (formatos PNG y SVG).

![Modelo físico: personas, compras, tiquetes, tarifas, pagos y reembolsos. Fuente: `docs/02_modelo/diagramas/fisico_ventas.mmd`.](../../docs/02_modelo/diagramas/fisico_ventas.png){width=100%}

## Anexo D. Reproducción y archivos

Table: Reproducción y ubicación de los archivos

| Paso | Comando o archivo |
|---|---|
| Verificar el entorno (solo lectura) | `scripts/windows/verificar_entorno.ps1` |
| Instalar dependencias | `pip install -r requirements.txt` |
| Reproducir todo (base local nueva) | `python -m aerolinea reproducir --confirmar-destruccion` |
| Scripts T-SQL y orden | `sql/README.md` |
| Consultas, resultados e interpretaciones | `sql/consultas/`, `reports/resultados/`, `docs/07_consultas/catalogo_consultas.md` |
| Pruebas y evidencias | `docs/06_pruebas/plan_pruebas.md`, `evidence/contenedor_linux/` |
| Despliegue en Azure | `docs/05_azure/guia_azure.md` |
| Este informe | `reports/informe/informe_fuente.md` → `python -m aerolinea informe` |

## Anexo E. Declaración sobre el uso de herramientas y datos

Los datos del proyecto son sintéticos y no contienen información de personas reales. El equipo debe declarar, conforme a las normas de la universidad y del docente, el uso de herramientas de inteligencia artificial en la elaboración del producto y cómo verificó sus resultados: [POR COMPLETAR por el equipo].
