# Revisión de fuentes académicas

Fecha de revisión: 2026-10-27.
Documentos leídos íntegramente (texto extraído página por página con `pdftotext`; las páginas sin texto se revisaron como imagen):

| Código | Documento | Páginas | Metadatos del archivo | Observación |
|---|---|---|---|---|
| F1 | `Producto académico colaborativo.txt` | — (texto del aula virtual) | Apertura: viernes 6-nov-2026 00:00; vence: lunes 16-nov-2026 23:59 | Enunciado del PAC + rúbrica de 4 criterios |
| F2 | `PSMA00611 Silabo.pdf` | 10 | Creado 11-feb-2026 (Word 365) | Universidad Continental, Maestría en Ciencia de Datos |
| F3 | `PSMA00611 Guia de aprendizaje.pdf` (guía general) | 26 | Creado 05-ene-2024, modificado 05-ene-2025 | Índice con errores "¡Error! Marcador no definido" |
| F4 | `PSMA00611_Guía de aprendizaje_VIERNES.pdf` | 25 | Creado 03-jun-2026 (Word 365) | Versión con videoclases agrupadas |

Las páginas 25-26 de F3 y 24-25 de F4 son contraportadas (datos de contacto del CAS de Posgrado); no contienen requisitos.

## 1. Requisitos académicos extraídos

### 1.1 Enunciado del producto (F1; F3 pp. 21-23; F4 pp. 21-22)

- Base de datos **en la nube** para el sistema de gestión de una aerolínea.
- Debe abordar: definición de requisitos de la empresa; diseño del modelo de datos; creación de tablas; inserción de datos; definición de consultas; implementación de las consultas en un lenguaje de programación.
- Logro: aplicar fundamentos de BD, creación de BD en la nube, DML, restricciones, agrupaciones, vistas, agregaciones y procedimientos almacenados.
- Relaciones mínimas ("al menos, pero no limitarse a"): Clientes, Empleados, Rutas (origen, destino, día de la semana, hora prevista), Vuelos (generados desde una ruta programada), Localizaciones (áreas físicas o ubicaciones web de compra), Tiquetes (compra por clientes registrados o no), Aviones (asignados a viajes), Cabina (VIP o económica; precio por ruta y cabina), Pagos (uno o más por tiquete), Descuentos (porcentaje sobre el precio original).
- "Sea exhaustivo con los atributos" para la toma de decisiones.
- Entrega: solo el líder envía; carátula con los nombres de quienes participaron activamente.

### 1.2 Requisitos que aparecen solo en las guías (F3 p. 22-23; F4 p. 22)

- Avance del PA: registrarse en GitHub, crear equipo y proyecto y subir los scripts.
- Presentación oral: mínimo 10, máximo 15 diapositivas; 20 minutos; **todos los miembros exponen de forma aleatoria**.

El texto del aula virtual (F1) no menciona GitHub ni la presentación oral; no los contradice, pero tampoco los repite.

### 1.3 Rúbrica (F1; F3 p. 24; F4 p. 23)

Cuatro criterios con escala 0 / 2 / 4 / 5 puntos: Información, Análisis, Conclusiones, Estilo/Gramática. El criterio de estilo menciona "cumple con el mínimo de páginas requeridas", pero **ningún documento fija ese mínimo**.

## 2. Discrepancias entre documentos

| ID | Tema | F2 Sílabo | F3 Guía general | F4 Guía VIERNES | Tratamiento en el proyecto |
|---|---|---|---|---|---|
| D1 | Semana del avance del PA (20 %) | Semana 4 (p. 9) | Semana 4 (p. 5) y Semana 3 (p. 23) | Semana 2 (p. 5); "Avance del PAC" en semana 2 del cronograma (p. 7) | Pendiente de confirmar con el docente. El repositorio queda listo desde ya para cualquiera de las fechas. |
| D2 | Semana de la entrega final del PA (40 %) | Semana 4 (p. 9) | Semana 4 (p. 5) y Semana 3 (p. 23) | Semana 4 (p. 5) | La fecha operativa vigente es la del aula virtual (F1): 16-nov-2026 23:59. |
| D3 | Resultado de aprendizaje de la asignatura | Diseño de BD con SQL (p. 1) | "Inequidades sanitarias… determinantes de la salud" (p. 5) | Igual que F3 (p. 5) | Error de plantilla evidente en F3 y F4; se usa el del sílabo. |
| D4 | Número de videoclases | — | 6 (dos por unidad, pp. 11, 15, 19) | 3 (una por unidad, pp. 10, 14, 17) | Sin efecto sobre el producto; F4 parece corresponder a una sección de viernes. No se presume cuál rige. |
| D5 | Páginas de lecturas | Elmasri pp. 3-11 y 87-109; Silberschatz pp. 37-47 y 154-190 (pp. 3-8) | Elmasri pp. 30-40 y 89-109; Silberschatz pp. 37-47 y 183-219 (pp. 9, 15, 18) | Igual que F3 | Se citan las obras completas, sin rangos de páginas no verificados. |
| D6 | Edición y año de Elmasri y Navathe | "(2017) … (6th ed.)" (p. 10) | "(2017) … (6th ed.)" | Igual | La 6.ª edición tiene copyright 2011 (Addison-Wesley/Pearson; ISBN 978-0-13-608620-8). El año 2017 no corresponde a esa edición, aunque existe un registro de catálogo con fecha 2017 de una edición posterior. El enlace del sílabo apunta al PDF de la 6.ª edición, por lo que el informe la cita como 2011. |
| D7 | Año de Silberschatz, Korth y Sudarshan, 7.ª ed. | 2017 (p. 10) | 2017 | 2017 | La 7.ª edición salió a la venta en 2019 y su página de derechos indica copyright 2020 (ISBN 978-0-07-802215-9). Conforme a APA 7 se cita con el año del copyright (2020) y se deja la nota. |
| D8 | Lectura "Yaseen (2019). Restricciones en SQL Server" y "Microsoft (2023). ¿Qué son las bases de datos?" | No figuran | Figuran (pp. 10, 15) | Figuran (pp. 10, 14) | Se consideran lecturas complementarias. |
| D9 | Foro 2: "Revise el material de la semana 5" | — | p. 20 | p. 19 | El curso tiene 4 semanas; sin efecto sobre el PA. |
| D10 | Naturaleza del curso | "Teórico", 0 horas prácticas (p. 1) | Talleres prácticos con SSMS/Azure Data Studio | Igual | El PA exige implementación práctica; se sigue el enunciado del PA. |
| D11 | Herramienta de los talleres | SSMS o Azure Data Studio (pp. 5-8) | — | — | Microsoft anunció el retiro de Azure Data Studio (28-feb-2026). Se usa SSMS, como indicó el usuario. |
| D12 | Mínimo de páginas del informe | No se indica | No se indica | No se indica | **Pendiente.** Propuesta editorial: 30-40 páginas de cuerpo (sin anexos), en A4/Carta, 11-12 pt. |

## 3. Instrucciones del usuario frente al contenido de las fuentes

Las instrucciones de este encargo (por ejemplo, ≥15 consultas, pruebas de concurrencia, Python con pyodbc y pandas, APA 7, preparación de Azure SQL Database) son **mejoras propuestas por el equipo**. No se atribuyen al docente. La matriz de requisitos (`matriz_requisitos.md`) distingue la columna "Obligatorio (fuente)" de la columna "Mejora propuesta".

## 4. Información institucional que no se inventa

Los documentos identifican a la Universidad Continental (Escuela de Posgrado, Maestría en Ciencia de Datos), el curso PSMA00611 y su ciclo II. **No** identifican al docente, la sección, el NRC ni a los integrantes. Esos campos quedan como `[POR COMPLETAR]`.
