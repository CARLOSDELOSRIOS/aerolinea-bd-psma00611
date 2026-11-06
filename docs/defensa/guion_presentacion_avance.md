# Guion de la presentación alineada con el avance (20 minutos, 15 diapositivas)

Archivo: `slides/presentacion_avance_PSMA00611.pptx`. Parte de la versión que preparó el equipo (23 diapositivas) y la condensa en 15, el máximo que fijan las guías para la presentación oral (F3 y F4, p. 22). Los títulos y el orden siguen la versión en Word del avance editada por el equipo: el **título** de cada diapositiva es el capítulo del Word y el **subtítulo**, las secciones que cubre. Se regenera con `cd slides; npm ci; node construir_presentacion_avance.js`.

**Cómo usar las diapositivas como guía.**

1. **Título y subtítulo:** el capítulo y las secciones del informe de avance.
2. **Frases guía** (recuadros con la palabra clave en negrita): cada una es un punto que hay que decir. Se leen de un vistazo y se desarrollan con palabras propias.
3. **Notas del expositor** (en PowerPoint, *Vista → Notas*): el tiempo, la **idea central** (la frase que el público debe recordar; si solo da tiempo para una, es esa), *Qué decir* y *Si preguntan*.

Todos los integrantes exponen de forma aleatoria (F3 p. 23), así que cualquiera debe poder tomar cualquier diapositiva.

## Distribución del tiempo

| # | Título (capítulo) | Subtítulo (secciones) | Idea central (en las notas) | Tiempo | Acumulado |
|---|---|---|---|---|---|
| 1 | Portada | — | Base de datos que hace cumplir sus reglas y se reconstruye con un comando; datos sintéticos; Azure pendiente | 0:30 | 0:30 |
| 2 | Requisitos académicos del producto | Estructura y criterios de evaluación · Estado de los componentes | Los seis componentes ya tienen una versión probada; faltan las laptops y Azure | 1:15 | 1:45 |
| 3 | Organización y metodología de trabajo | Integrantes del equipo · Metodología de trabajo · Registro de colaboración en GitHub | Los tres participamos en todas las etapas, del prompt al repositorio | 1:15 | 3:00 |
| 4 | Problema y objetivos del proyecto | Planteamiento del problema · Objetivos del proyecto | Que los datos sean correctos aunque muchos vendan y cobren a la vez | 1:30 | 4:30 |
| 5 | Análisis e interpretación de requisitos | Relaciones mínimas requeridas | Cada relación tiene sus tablas y sus atributos documentados | 1:15 | 5:45 |
| 6 | Análisis e interpretación de requisitos | Distinción entre pasajero, comprador y cliente registrado · Ruta, programación y vuelo | Quien compra no siempre viaja, y la ruta no es el vuelo | 1:30 | 7:15 |
| 7 | Análisis e interpretación de requisitos | Conservación del precio histórico del tiquete · Decisiones complementarias de modelado | El tiquete guarda el precio y el descuento del momento de la venta | 1:30 | 8:45 |
| 8 | Diseño del modelo de datos | Modelo conceptual · Normalización | Todo gira alrededor del tiquete; el cupo por cabina impide la sobreventa | 1:30 | 10:15 |
| 9 | Implementación de la solución | Organización y secuencia de los scripts · Reglas de integridad en la base de datos | La base rechaza un dato inválido, venga de la aplicación, de SSMS o de una carga | 1:30 | 11:45 |
| 10 | Implementación de la solución | Aplicación en Python · Arquitectura local y en la nube | Un comando reconstruye todo; Azure está preparado, pero aún no desplegado | 1:15 | 13:00 |
| 11 | Validación y resultados | Entorno y alcance de las pruebas · Control de concurrencia y prevención de sobreventa | 40 sesiones a la vez por 12 asientos: exactamente 12 ventas | 1:30 | 14:30 |
| 12 | Validación y resultados | Resultados preliminares | Sirven para validar el modelo y las consultas, no para describir un mercado | 1:30 | 16:00 |
| 13 | Validación y resultados | Hallazgos y correcciones durante el desarrollo | Las pruebas encontraron lo que una revisión a ojo no veía | 1:15 | 17:15 |
| 14 | Actividades pendientes y plan de trabajo | Plan de trabajo · Riesgos del proyecto | Laptops, Azure y cierre del informe | 1:15 | 18:30 |
| 15 | Conclusiones del avance | — | Una conclusión por idea; gracias y preguntas | 1:30 | **20:00** |

Si el tiempo aprieta, resumir las diapositivas 5 y 12 en 45 segundos cada una. No recortar la 10 ni la 14: decir con claridad que Azure está pendiente es parte de la honestidad del trabajo.

## Correspondencia con la versión del equipo (23 diapositivas)

| Versión del equipo | Esta versión |
|---|---|
| 1 Portada | 1 |
| 3 Estructura y componentes | 2 (se añaden los pesos y la fecha de entrega) |
| 4 Metodología de trabajo | 3 |
| 2 Problema y objetivos | 4 (pasa después de la metodología, como en el Word) |
| 5 Relaciones del enunciado | 5 |
| 6 Pasajero, comprador y cliente · 7 Ruta, programación y vuelo | 6 |
| 8 Precio histórico · 9 Decisiones complementarias | 7 |
| 10 Modelo conceptual · 11 Normalización | 8 |
| 12 Scripts · 13 Reglas de integridad | 9 |
| 14 Aplicación en Python · 15 Arquitectura | 10 |
| 16 Entorno de pruebas · 17 Concurrencia | 11 |
| 18 Indicadores · 19 Ventas, cobros y reembolsos | 12 |
| 20 Hallazgos | 13 |
| 21 Plan de trabajo · 22 Riesgos | 14 |
| 23 Conclusiones | 15 |

Las notas de la versión del equipo se habían copiado de otra presentación y no correspondían a cada diapositiva; aquí se reescribieron una por una.
