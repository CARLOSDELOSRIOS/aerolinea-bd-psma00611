# Guion de la presentación alineada con el avance (20 minutos, 15 diapositivas)

Archivo: `slides/presentacion_avance_PSMA00611.pptx`. Parte de la versión que preparó el equipo (23 diapositivas) y la condensa en 15, el máximo que fijan las guías para la presentación oral (F3 y F4, p. 22). Se regenera con `cd slides; npm ci; node construir_presentacion_avance.js`.

**Cómo usar las diapositivas como guía.** Cada diapositiva tiene tres niveles de ayuda:

1. **Título:** el tema.
2. **Idea clave** (subtítulo en cursiva): la frase que el público debe recordar. Si solo da tiempo para una frase, es esa.
3. **Frases guía** (recuadros con la palabra clave en negrita): cada una es un punto que hay que decir. Se leen de un vistazo y se desarrollan con palabras propias.

El desarrollo completo está en las **notas del expositor** de PowerPoint (*Vista → Notas*), con tres partes: el tiempo, *Qué decir* y *Si preguntan*.

Todos los integrantes exponen de forma aleatoria (F3 p. 23), así que cualquiera debe poder tomar cualquier diapositiva.

## Distribución del tiempo

| # | Diapositiva | Idea clave | Tiempo | Acumulado |
|---|---|---|---|---|
| 1 | Portada | Base de datos que hace cumplir sus reglas y se reconstruye con un comando; datos sintéticos; Azure pendiente | 0:30 | 0:30 |
| 2 | El problema y lo que queremos lograr | Que los datos sean correctos aunque muchos vendan y cobren a la vez | 1:30 | 2:00 |
| 3 | Qué pide el curso y dónde estamos | Los seis componentes ya tienen una versión probada; faltan las laptops y Azure | 1:15 | 3:15 |
| 4 | Cómo trabajamos los tres | Los tres participamos en todas las etapas, del prompt al repositorio | 1:15 | 4:30 |
| 5 | Las diez relaciones del enunciado | Cada relación tiene sus tablas y sus atributos documentados | 1:15 | 5:45 |
| 6 | Dos dudas del enunciado que cambiaron el modelo | Quien compra no siempre viaja, y la ruta no es el vuelo | 1:30 | 7:15 |
| 7 | El precio vendido no cambia, y otras reglas del negocio | El tiquete guarda el precio y el descuento del momento de la venta | 1:30 | 8:45 |
| 8 | Un modelo de 19 entidades en tercera forma normal | Todo gira alrededor del tiquete; el cupo por cabina impide la sobreventa | 1:30 | 10:15 |
| 9 | Scripts ordenados y reglas dentro de la base | La base rechaza un dato inválido, venga de la aplicación, de SSMS o de una carga | 1:30 | 11:45 |
| 10 | Python automatiza; el mismo T-SQL sirve en la laptop y en Azure | Un comando reconstruye todo; Azure está preparado, pero aún no desplegado | 1:15 | 13:00 |
| 11 | Pruebas: todo superado en el entorno de desarrollo | 40 sesiones a la vez por 12 asientos: exactamente 12 ventas | 1:30 | 14:30 |
| 12 | Primeros resultados con datos sintéticos | Sirven para validar el modelo y las consultas, no para describir un mercado | 1:30 | 16:00 |
| 13 | Lo que aprendimos: 20 errores reales corregidos | Las pruebas encontraron lo que una revisión a ojo no veía | 1:15 | 17:15 |
| 14 | Lo que sigue hasta el 16 de noviembre | Laptops, Azure y cierre del informe | 1:15 | 18:30 |
| 15 | Conclusiones del avance | Una conclusión por idea; gracias y preguntas | 1:30 | **20:00** |

Si el tiempo aprieta, resumir las diapositivas 5 y 12 en 45 segundos cada una. No recortar la 10 ni la 14: decir con claridad que Azure está pendiente es parte de la honestidad del trabajo.

## Correspondencia con la versión del equipo (23 diapositivas)

| Versión del equipo | Esta versión |
|---|---|
| 1 Portada | 1 |
| 2 Problema y objetivos | 2 |
| 3 Estructura y componentes | 3 (se añaden los pesos y la fecha de entrega) |
| 4 Metodología de trabajo | 4 |
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
