::: {custom-style="Portada Institucion"}
UNIVERSIDAD CONTINENTAL

Escuela de Posgrado

Maestría en Ciencia de Datos
:::

::: {custom-style="Portada Curso"}
Gestión de datos y bases de datos con SQL (PSMA00611)
:::

::: {custom-style="Portada Titulo"}
Base de datos para una aerolínea comercial en Estados Unidos
:::

::: {custom-style="Portada Curso"}
Avance del Producto Académico Colaborativo
:::

::: {custom-style="Portada Datos"}
Integrantes que participaron activamente: [POR COMPLETAR]

Docente: [POR COMPLETAR]

Sección / NRC: [POR COMPLETAR]

Líder del equipo: [POR COMPLETAR]

Repositorio: https://github.com/CARLOSDELOSRIOS/aerolinea-bd-psma00611

Lugar y fecha de entrega: [POR COMPLETAR], 2026
:::

```{=openxml}
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
```

::: {custom-style="Titulo Indice"}
Contenido
:::

```{=openxml}
<w:sdt><w:sdtPr><w:docPartObj><w:docPartGallery w:val="Table of Contents"/><w:docPartUnique/></w:docPartObj></w:sdtPr><w:sdtContent><w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-2" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Actualice el índice: clic derecho y «Actualizar campo».</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:sdtContent></w:sdt>
<w:p><w:r><w:br w:type="page"/></w:r></w:p>
```

# Resumen del avance

Este documento informa el estado del Producto Académico Colaborativo (PAC) del curso Gestión de datos y bases de datos con SQL a la fecha de su redacción. El PAC consiste en diseñar y construir la base de datos en la nube de una aerolínea comercial nueva que iniciará operaciones en Estados Unidos (Universidad Continental, 2026). Para el avance, las guías de aprendizaje piden registrarse en GitHub, crear el equipo y el proyecto y subir los scripts del producto (Universidad Continental, 2023).

El repositorio del proyecto existe y contiene los scripts: <https://github.com/CARLOSDELOSRIOS/aerolinea-bd-psma00611>. Su primera versión, del 27 de octubre de 2026, reúne 188 archivos: 15 scripts T-SQL numerados que crean la base de forma idempotente, 20 consultas analíticas documentadas, una aplicación de consola en Python, pruebas automatizadas, el modelo de datos con su diccionario, el borrador del informe final y la presentación. Falta completar la parte de «equipo»: invitar a los integrantes al repositorio y que cada uno registre sus aportes con su propia cuenta.

En cuanto al contenido, los seis componentes que exige el encargo —requisitos, modelo de datos, creación de tablas, inserción de datos, consultas e implementación en un lenguaje de programación— tienen una primera versión completa. El modelo tiene 39 tablas de negocio en tercera forma normal y 42 reglas de negocio que el propio motor garantiza. Se verificó en un entorno de desarrollo (un contenedor Linux con SQL Server 2022 Developer): 23 de 23 pruebas de reglas de negocio, 4 de 4 pruebas de concurrencia y 23 de 23 pruebas de la aplicación superadas, con una carga de unos 1,19 millones de filas sintéticas.

Quedan tres frentes abiertos que este avance declara expresamente: la reproducción en la laptop Windows de cada integrante, el despliegue en Azure SQL Database —que es el requisito de nube del encargo y todavía no se ha ejecutado— y la organización del equipo en GitHub. El documento termina con el plan de trabajo hasta la entrega final del 16 de noviembre de 2026, los riesgos identificados y las consultas que el equipo desea plantear al docente en la retroalimentación del avance.

# Encargo y criterio del avance

## Qué se pide

El enunciado del aula virtual describe el producto final y su rúbrica, pero no menciona el avance (Universidad Continental, 2026). El avance aparece en el sílabo y en las dos guías de aprendizaje del curso. Según las guías, la calificación del producto se compone del avance (20 %), la presentación oral (40 %) y el producto final (40 %), evaluados con una rúbrica de cuatro criterios: información, análisis, conclusiones, y estilo y gramática. Su contenido se describe en una sola indicación: registrarse en GitHub, crear el equipo y el proyecto y subir los scripts de código del producto (Universidad Continental, 2023).

## Semana de entrega

Los documentos no coinciden en la semana del avance: el sílabo indica la semana 4; la guía general, la semana 4 en una página y la semana 3 en otra; y la guía identificada como «VIERNES», la semana 2. El equipo no asume que una versión prevalezca sobre las demás: preparó el avance con anticipación para cumplir cualquiera de las tres fechas y lo incluye entre las consultas al docente (tabla 9). La entrega final está fijada en el aula virtual para el lunes 16 de noviembre de 2026 a las 23:59.

## Cómo se presenta el avance

Como la rúbrica valora la información, el análisis y las conclusiones, el avance no se limita a enlazar el repositorio: explica qué se construyó, qué decisiones de diseño se tomaron y por qué, qué se ha verificado y en qué entorno, y qué falta. La tabla siguiente resume el estado de cada componente que exige el encargo.

Table: Estado del avance por componente del encargo

| Componente del encargo | Estado | Evidencia en el repositorio | Pendiente |
|----------------|--------------|-------------------|-----------------|
| Definición de requisitos | Primera versión completa: 42 reglas, 13 supuestos, 13 casos de uso | `docs/01_requisitos/` | Validación con el docente |
| Diseño del modelo de datos | Modelos conceptual, lógico y físico; normalización hasta 3FN; diccionario de 269 columnas | `docs/02_modelo/` | — |
| Creación de las tablas | Scripts 01 a 13 ejecutados en el contenedor de desarrollo | `sql/` | Ejecutar en la laptop y en Azure |
| Inserción de datos | Catálogos por script; datos transaccionales sintéticos con semilla fija | `sql/09_…`, `src/aerolinea/generador.py` | Ejecutar en la laptop y en Azure |
| Definición de las consultas | 20 consultas documentadas con resultados e interpretación | `sql/consultas/`, `docs/07_consultas/` | — |
| Implementación en un lenguaje de programación | Aplicación en Python (pyodbc y pandas) con parámetros enlazados | `src/aerolinea/` | — |
| Base de datos en la nube | Guía, scripts y verificación preparados | `docs/05_azure/` | **Despliegue no realizado** |
| Repositorio en GitHub (avance) | Repositorio creado y scripts subidos | Repositorio público | Invitar a los integrantes |

# Problema y objetivos

## Problema

Una aerolínea necesita registrar con confiabilidad qué vuelos ofrece, quién compra y quién viaja, cuánto se cobró y cuánto se devolvió, y qué avión y qué tripulación operan cada vuelo. Los errores en ese registro se notan de inmediato: un asiento vendido dos veces, un vuelo sobrevendido o un reembolso mal calculado afectan al pasajero y a la contabilidad. El enunciado pide, además, «ser exhaustivo con los atributos» para que la información sirva después en la toma de decisiones (Universidad Continental, 2026), lo que obliga a definir con precisión cada concepto antes de crear tablas.

## Objetivos

**Objetivo general.** Diseñar, implementar y validar una base de datos relacional para la gestión comercial y operativa de una aerolínea, desplegable en SQL Server y en Azure SQL Database, con consultas analíticas ejecutables desde Python y resultados reproducibles.

**Objetivos específicos.** (1) Identificar los requisitos y expresarlos como reglas verificables; (2) construir los modelos conceptual, lógico y físico en tercera forma normal; (3) implementar las tablas y las reglas en T-SQL, de modo que la base rechace los datos inválidos aun con operaciones simultáneas; (4) cargar datos coherentes y reproducibles y responder preguntas de negocio con al menos quince consultas ejecutadas desde Python; y (5) verificar con pruebas automatizadas y desplegar en Azure SQL Database.

A la fecha del avance, los objetivos 1 a 4 tienen una versión completa y verificada en el entorno de desarrollo; el objetivo 5 está cumplido en su parte de verificación y pendiente en su parte de despliegue en la nube.

# Avance en requisitos

## Fuentes revisadas

Se leyeron completos el enunciado del aula virtual, el sílabo y las dos guías de aprendizaje. Además de la diferencia en la semana del avance, se registraron otras once discrepancias entre documentos; entre ellas, que ambas guías copian un resultado de aprendizaje de otra asignatura, que los años de edición de dos libros de lectura no coinciden con sus ediciones reales y que la rúbrica menciona un «mínimo de páginas» que ningún documento fija. Cada discrepancia queda anotada con el tratamiento que se le dio en `docs/00_fuentes/revision_fuentes.md`.

## Relaciones mínimas del enunciado

El enunciado enumera diez relaciones que la base debe considerar «al menos, pero no limitarse a» ellas. La tabla 2 muestra cómo se implementó cada una y cuántos atributos tiene su tabla principal; el detalle de cada columna, con su tipo, dominio y definición, está en el diccionario de datos.

Table: Relaciones mínimas del enunciado y su implementación

| Relación del enunciado | Tablas que la implementan | Atributos de la tabla principal |
|----------------|-------------------------|-----|
| Clientes | `ven.persona` (toda persona que compra o viaja) y `ven.cliente` (persona con cuenta registrada) | 12 + 8 |
| Empleados | `rh.empleado`, `rh.cargo`, `rh.departamento` | 14 |
| Rutas (origen, destino, día y hora) | `ops.ruta`, `ops.programacion`, `ops.programacion_dia` | 7 + 9 + 2 |
| Vuelos (generados de una ruta programada) | `ops.vuelo`, generado por `ops.usp_generar_vuelos` | 14 |
| Localizaciones (físicas y web) | `ref.localizacion` (aeropuerto, oficina, canal web) y `ref.aeropuerto` | 14 + 7 |
| Tiquetes (clientes registrados o no) | `ven.compra`, `ven.tiquete` | 7 + 20 |
| Aviones (asignados a viajes) | `ops.avion`, `ops.configuracion_asientos`, asignación con `ops.usp_asignar_avion` | 9 |
| Cabina (VIP o económica; precio por ruta y cabina) | `ref.cabina`, `ops.vuelo_cabina` (cupo por vuelo), `ven.tarifa` (precio versionado) | 7 + 4 + 7 |
| Pagos (uno o más por tiquete) | `ven.pago`, `ven.reembolso` | 12 + 8 |
| Descuentos (porcentaje sobre el precio original) | `ven.descuento` | 11 |

## Decisiones que resolvieron la ambigüedad

El enunciado deja abiertas preguntas que cambian el modelo. Las principales decisiones fueron estas:

Table: Decisiones de dominio principales

| Pregunta abierta | Decisión adoptada | Razón |
|------------------|---------------------|----------------------|
| ¿Cliente y pasajero son lo mismo? | Toda persona puede comprar o viajar; «cliente» es la persona con cuenta | Permite la compra sin registro sin columnas nulas ni personas duplicadas |
| ¿Qué diferencia hay entre ruta y vuelo? | Ruta = par origen-destino; programación = número, hora y días con vigencia; vuelo = salida fechada | El enunciado dice que los vuelos se generan de una ruta programada |
| ¿Qué pasa con el precio si cambia la tarifa? | El tiquete conserva el precio y el descuento de la venta; la tarifa usada no se edita, se versiona | Cambiar una tarifa no debe alterar ventas pasadas |
| ¿Se acumulan los descuentos? | Uno por tiquete: el mayor aplicable | Evita promociones acumuladas sin control |
| ¿Cómo se paga en varias partes? | Varios pagos por tiquete; se emite al completar el precio; la reserva vence a las 72 horas | El enunciado admite uno o más pagos por tiquete |
| ¿Qué hora se guarda en una red con cinco husos? | Hora local con su desfase en los vuelos; hora UTC en las transacciones | Evita errores con el horario de verano y las llegadas al día siguiente |

La regla de cancelación sin penalidad durante 24 horas para compras hechas con al menos siete días de antelación sigue la norma del Departamento de Transporte de Estados Unidos (Customer Service Plan, 2026). Trece supuestos (SUP-01 a SUP-13) completan lo que el enunciado no fija; por ejemplo, el plazo de 72 horas para pagar una reserva.

# Avance en el diseño del modelo de datos

## Modelo conceptual

![Modelo conceptual: 19 entidades y sus relaciones. Fuente: `docs/02_modelo/diagramas/conceptual.mmd`.](../../docs/02_modelo/diagramas/conceptual.png){width=82%}

El modelo conceptual (figura 1) reúne 19 entidades alrededor del tiquete. La entidad que concentra el control de la sobreventa es el cupo por vuelo y cabina: cada venta consume una plaza de ese cupo, y ahí se aplica el bloqueo que impide vender más asientos de los que existen cuando dos agentes venden a la vez.

## Modelo lógico y físico

El modelo lógico se dividió en cuatro áreas —red y vuelos; flota y tripulación; personas, compras y tiquetes; precios, pagos y reembolsos— para que cada diagrama sea legible. El modelo físico se genera desde el catálogo del motor, de modo que los diagramas, el diccionario y el código no pueden contradecirse. Las tablas se agrupan en esquemas por área (`ref`, `ops`, `rh`, `ven`), más esquemas de reporte (`rpt`), auditoría (`aud`), administración (`adm`), carga (`stg`) y pruebas (`tst`), lo que permite conceder permisos por área.

## Normalización

El modelo está en tercera forma normal (Codd, 1970; Elmasri y Navathe, 2011): cada atributo depende de la clave completa y solo de ella. Se mantienen seis redundancias controladas, cada una con su justificación y su control; la más importante es la copia del precio y del porcentaje de descuento en el tiquete. Esa copia no produce anomalías, porque el precio del tiquete es un hecho de la venta y no un atributo de la tarifa actual: un trigger verifica que coincida con la tarifa vigente al vender y que no cambie después.

# Avance en la implementación

## Scripts subidos al repositorio

Los scripts T-SQL se numeran en el orden de ejecución y pueden volver a ejecutarse sin error ni duplicados. La única eliminación de la base está aislada en un script marcado como destructivo, que exige confirmación explícita y se niega a ejecutarse en Azure.

Table: Scripts T-SQL del repositorio

| Script | Contenido |
|---------------------------|---------------------------|
| `00_verificacion_entorno.sql` | Diagnóstico de solo lectura: versión, edición, permisos y cifrado |
| `01_crear_base_datos_local.sql` | Crea `AerolineaDB` solo si no existe (únicamente en local) |
| `02` a `04` | Esquemas, tablas, claves, restricciones e índices |
| `05_funciones_y_triggers.sql` | Funciones y triggers de reglas de negocio |
| `06_vistas.sql`, `07_procedimientos.sql` | Vistas de reporte y procedimientos de negocio |
| `08_seguridad.sql` | Roles con privilegio mínimo y enmascaramiento de datos personales |
| `09_datos_referencia.sql` | Aeropuertos, rutas, horarios, flota, tarifas, descuentos y empleados |
| `10_carga_staging.sql` | Carga de los datos sintéticos en una sola transacción |
| `11_dml_seguro.sql` | Ejemplos de `INSERT`, `UPDATE` y `DELETE` que simulan por defecto |
| `12_pruebas_integridad.sql`, `13_descripciones.sql` | Pruebas automatizadas y descripción de cada columna |
| `99_DESTRUCTIVO_eliminar_base_local.sql` | Elimina la base local; exige confirmación |
| `consultas/Q01` a `Q20` | Consultas analíticas documentadas |

## Integridad en el motor

La base garantiza sus reglas aunque alguien inserte datos sin pasar por la aplicación. Para ello se priorizaron las restricciones declarativas —70 `CHECK`, 53 claves foráneas, 29 restricciones de unicidad y 6 índices únicos filtrados— y se usaron 12 triggers solo donde una restricción no alcanza, por ejemplo para validar transiciones de estado o impedir que un avión opere dos vuelos solapados. Dieciséis procedimientos almacenados agrupan las operaciones críticas (emitir, pagar, cancelar, generar vuelos) y nueve vistas fijan las fórmulas de análisis.

## Aplicación en Python

La aplicación de consola despliega los scripts en orden, genera y carga los datos sintéticos, ejecuta las consultas con parámetros enlazados —nunca concatena lo que escribe el usuario—, exporta los resultados a CSV, genera los gráficos y ejecuta las pruebas. La configuración se lee de un archivo `.env` que no se sube al repositorio; con la laptop se usa autenticación de Windows, por lo que no hay contraseñas guardadas. Todo el proceso se reproduce con un solo comando.

## Arquitectura local y en la nube

![Arquitectura de la solución. Fuente: `docs/03_arquitectura/arquitectura.mmd`.](../../docs/03_arquitectura/arquitectura.png){width=72%}

El mismo código T-SQL está pensado para SQL Server en la laptop y para Azure SQL Database (figura 2). Las diferencias se resolvieron en el diseño: los scripts no cambian de base con `USE`, la autenticación en Azure será con Microsoft Entra ID y el certificado del servidor se validará siempre. Para no generar costos se propone la oferta gratuita de Azure SQL Database, que pausa la base al agotar el cómputo mensual incluido (Microsoft, s. f.). **Todavía no se ha creado ningún recurso en Azure**: hace falta una suscripción y la autorización del equipo.

# Verificación realizada hasta la fecha

## Entorno de verificación

Todas las pruebas de este avance se ejecutaron en un contenedor Linux con SQL Server 2022 Developer (versión 16.0.4305.5), controlador ODBC 18 y Python 3.13. Ese entorno demuestra que el código funciona sobre un motor SQL Server real, pero **no** sustituye la ejecución en la laptop de los integrantes ni el despliegue en la nube. Las pruebas se repitieron con el nivel de compatibilidad de SQL Server 2016 con los mismos resultados.

Table: Resultados de la verificación en el entorno de desarrollo

| Verificación | Resultado observado | Evidencia |
|---------------------|--------------------|------------------|
| Pruebas de reglas de negocio (PR-01 a PR-23) | 23 de 23 superadas | `evidence/contenedor_linux/resultados_pruebas.md` |
| Concurrencia con sesiones simultáneas reales (PC-01 a PC-04) | 4 de 4: sin sobreventa, sin asientos duplicados y sin doble cobro | Mismo archivo |
| Pruebas de la aplicación (pytest) | 23 de 23 superadas | `evidence/contenedor_linux/pytest.txt` |
| Carga de datos sintéticos | Unos 1,19 millones de filas en unos 90 segundos, con todas las reglas activas | `evidence/contenedor_linux/carga_sintetica.json` |
| Conciliación de caja | 0,00 USD de diferencia | Consulta Q19 |
| Laptop Windows | **Pendiente** | `evidence/laptop_windows/` |
| Azure SQL Database | **Pendiente** | `evidence/azure/` |

Un ejemplo muestra el valor de estas pruebas: en la prueba de concurrencia, 40 sesiones intentan comprar a la vez en una cabina VIP de 12 asientos, y exactamente 12 lo consiguen. Esa garantía se basa en bloquear solo la fila del recurso disputado, en lugar de elevar el aislamiento de toda la base (Berenson et al., 1995).

## Primeros resultados

Los datos son sintéticos: se generan con una semilla fija (20261106) y reglas conocidas, por lo que las cifras validan el modelo y las consultas, pero no describen ningún mercado real.

Table: Indicadores preliminares con datos sintéticos

| Indicador | Valor | Consulta |
|-------------------------|---------------|------|
| Factor de ocupación ponderado (económica · VIP) | 68,9 % · 53,0 % | Q02 |
| Ventas brutas · cobros · reembolsos (julio-octubre de 2026) | 73,52 · 72,27 · 3,03 millones de USD | Q03 |
| Compras hechas por compradores registrados | 41,9 % (el generador usa 42 %) | Q08 |
| Vuelos que llegan con menos de 15 minutos de demora | 78,4 % | Q15 |
| Máximo de horas de vuelo de un piloto en 28 días | 94,5 horas (referencia normativa: 100) | Q18 |

Que una consulta recupere el 41,9 % cuando el generador usa el 42 % es una forma de validar que la consulta calcula lo que dice calcular. Los cobros superan a las ventas vigentes sin que haya error, porque incluyen dinero que después se devolvió o se retuvo como penalidad; por eso las ventas, los cobros y los reembolsos se agregan por separado, cada uno por su propia fecha.

## Dificultades y aprendizajes

Las pruebas detectaron 20 defectos reales durante el desarrollo, documentados con su causa y su corrección en `docs/06_pruebas/hallazgos_y_correcciones.md`. Tres de ellos ilustran lo aprendido:

- **Concurrencia.** La primera versión de la asignación automática de asientos solo atendió 6 de 30 solicitudes simultáneas, porque todas elegían a la vez el mismo «primer asiento libre». Se corrigió serializando la asignación por vuelo y cabina.
- **Lógica de tres valores.** Una condición del tipo `NOT (categoria = 'TECNICA')` devuelve *desconocido* cuando la categoría es nula, y la fila se aceptaba; así, un empleado sin categoría podía asignarse como capitán.
- **Datos sintéticos realistas.** La consulta de horas de tripulación mostró que la primera planificación sintética superaba el límite normativo de 100 horas de vuelo en 28 días (Cumulative Limitations, 2026). Se ajustó el número de equipos por línea hasta quedar por debajo.

# Plan de trabajo hasta la entrega final

El plan siguiente es una **propuesta** que el equipo debe validar y completar con los responsables reales. No asigna tareas a personas, porque esa distribución solo la puede decidir el equipo.

Table: Plan de trabajo propuesto

| Hito | Actividades | Fecha objetivo | Responsable |
|----------------|------------------------------|-------------|----------|
| 1. Organización del equipo | Confirmar integrantes y líder; invitar a todos al repositorio; fijar reuniones de coordinación | 30 de octubre al 2 de noviembre | [POR COMPLETAR] |
| 2. Retroalimentación del avance | Plantear al docente las consultas de la tabla 9 e incorporar sus indicaciones | Videoclase siguiente [POR CONFIRMAR] | Líder |
| 3. Reproducción en las laptops | Verificar el entorno, reconstruir la base con un comando y guardar las evidencias | 2 al 6 de noviembre | Cada integrante |
| 4. Despliegue en Azure | Obtener la autorización, crear la base con la oferta gratuita, desplegar, cargar y verificar | 6 al 10 de noviembre | [POR COMPLETAR] |
| 5. Cierre del informe | Revisar cada sección, incorporar las evidencias de la laptop y de Azure, completar la carátula | 9 al 13 de noviembre | Todo el equipo |
| 6. Ensayo de la exposición | Ensayos cronometrados de 20 minutos y de la demostración en vivo | Antes de la presentación oral [fecha POR CONFIRMAR] | Todo el equipo |
| 7. Entrega final | El líder envía el producto en el aula virtual | 16 de noviembre, 23:59 | Líder |

## Riesgos identificados

Table: Riesgos y medidas previstas

| Riesgo | Efecto | Medida prevista |
|-----------------------|-------------------|--------------------------------|
| No disponer de una suscripción de Azure a tiempo | No se cumpliría el requisito de nube | Iniciar el trámite en el hito 1; la guía y los scripts ya están listos para ejecutarse en minutos |
| Diferencias de versión o de controlador en las laptops | La reproducción podría fallar | Script de verificación del entorno de solo lectura antes de reconstruir la base |
| Cambio de fecha del avance o de la presentación | Menos tiempo para cerrar | Avance preparado con anticipación; consulta al docente |
| Participación desigual o no registrada | Afecta la carátula y la evaluación colaborativa | Registro de aportes y trabajo con ramas en GitHub |
| Costos inesperados en la nube | Gasto no previsto | Oferta gratuita con pausa automática y firewall limitado a la IP del equipo |

## Consultas para la retroalimentación del docente

Table: Consultas que el equipo desea plantear

| N.º | Consulta | Por qué importa |
|---|--------------------------------|------------------------------|
| 1 | ¿En qué semana se evalúa el avance? | Los documentos indican las semanas 2, 3 y 4 |
| 2 | ¿Cuál es el mínimo de páginas del informe final? | La rúbrica lo menciona, pero ningún documento lo fija; el equipo propone de 30 a 40 páginas de cuerpo |
| 3 | ¿El «equipo» de GitHub debe ser una organización o basta con un repositorio con todos los integrantes como colaboradores? | Determina cómo se organiza el repositorio |
| 4 | ¿La universidad proporciona una suscripción de Azure para estudiantes? | Condiciona el despliegue en la nube |
| 5 | ¿Se acepta un modelo más amplio que las diez relaciones mínimas, con datos sintéticos? | Confirma el alcance elegido |

# Conclusiones del avance

El trabajo realizado hasta ahora muestra que la mayor dificultad del encargo no estaba en crear tablas, sino en precisar qué significa cada concepto del enunciado. Separar al pasajero del comprador, el horario del vuelo fechado y el precio pactado de la tarifa vigente fue lo que permitió que el modelo cumpliera la tercera forma normal y que las consultas posteriores dieran resultados consistentes.

La segunda conclusión es que las reglas de negocio deben vivir en el motor y no solo en la aplicación. Las restricciones declarativas, complementadas por triggers y procedimientos, hicieron que la carga masiva de datos sintéticos funcionara como una prueba adicional: la base rechazó cada dato incoherente, y eso permitió detectar y corregir defectos del generador y del propio diseño.

La tercera es que verificar exige distinguir entornos. Las pruebas superadas en el contenedor de desarrollo prueban que el código es correcto sobre un motor SQL Server real, pero no reemplazan la reproducción en las laptops del equipo ni el despliegue en Azure SQL Database. Por eso este avance declara esos dos frentes como pendientes y los pone en el centro del plan de trabajo.

Por último, el requisito propio del avance —el repositorio con los scripts— está cumplido en su parte técnica y pendiente en su parte colaborativa. El paso inmediato es incorporar a todos los integrantes al repositorio, de modo que su historial refleje los aportes reales de cada uno.

# Referencias

Berenson, H., Bernstein, P., Gray, J., Melton, J., O'Neil, E., & O'Neil, P. (1995). A critique of ANSI SQL isolation levels. En *Proceedings of the 1995 ACM SIGMOD International Conference on Management of Data* (pp. 1–10). Association for Computing Machinery. https://doi.org/10.1145/223784.223785

Codd, E. F. (1970). A relational model of data for large shared data banks. *Communications of the ACM, 13*(6), 377–387. https://doi.org/10.1145/362384.362685

Cumulative limitations, 14 C.F.R. § 117.23 (2026). https://www.ecfr.gov/current/title-14/chapter-I/subchapter-G/part-117/section-117.23

Customer service plan, 14 C.F.R. § 259.5 (2026). https://www.ecfr.gov/current/title-14/chapter-II/subchapter-A/part-259/section-259.5

Elmasri, R., & Navathe, S. B. (2011). *Fundamentals of database systems* (6th ed.). Addison-Wesley.

Microsoft. (s. f.). *Deploy Azure SQL Database for free*. Microsoft Learn. Recuperado el 27 de octubre de 2026, de https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer

Universidad Continental. (2023). *Guía de actividades de aprendizaje: Gestión de datos y bases de datos con SQL (PSMA00611)*. Escuela de Posgrado.

Universidad Continental. (2026). *Producto académico colaborativo: Gestión de datos y bases de datos con SQL (PSMA00611)* [Enunciado del aula virtual]. Escuela de Posgrado.

# Anexo. Estructura del repositorio

Table: Contenido del repositorio en su primera versión

| Carpeta | Archivos | Contenido |
|-----------|-------|--------------------------------------|
| `sql/` | 37 | Scripts T-SQL numerados, consultas Q01 a Q20 y verificación para Azure |
| `src/aerolinea/` | 16 | Aplicación en Python: conexión, generador, carga, consultas, gráficos, pruebas, documentación |
| `tests/` | 5 | Pruebas de la aplicación (pytest) |
| `docs/` | 68 | Fuentes, requisitos, modelo, diccionario, arquitectura, guías local y de Azure, pruebas, consultas y defensa |
| `reports/` | 33 | Resultados en CSV, gráficos e informe final (borrador) |
| `slides/` | 4 | Presentación de 14 diapositivas y su generador |
| `evidence/` | 14 | Evidencias del entorno de desarrollo; carpetas para la laptop y Azure |
| `scripts/`, `data/` | 3 | Verificación de Windows, creación de recursos de Azure y manifiesto de los datos sintéticos |
| Raíz | 8 | `README.md`, `CONTRIBUTING.md`, dependencias, configuración de ejemplo sin secretos y `.gitignore` |

Los dos primeros commits del repositorio (27 de octubre de 2026) se generaron en la sesión de desarrollo asistida por una herramienta de inteligencia artificial y figuran con el autor «Claude»; no corresponden a aportes individuales de los integrantes. Los aportes de cada integrante se registrarán con su propia cuenta de GitHub y en `docs/equipo/registro_aportes.md`. Declaración del equipo sobre el uso de herramientas de inteligencia artificial, conforme a las normas de la universidad y del docente: [POR COMPLETAR por el equipo].
