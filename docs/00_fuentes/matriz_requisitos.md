# Matriz de requisitos

Páginas verificadas con `pdftotext` página por página. Fuentes (ver `revision_fuentes.md`): **F1** texto del PAC en el aula virtual · **F2** sílabo · **F3** guía de aprendizaje general · **F4** guía de aprendizaje «VIERNES».

Tipo: **OBL** = obligatorio según las fuentes · **MEJ** = mejora propuesta por el equipo (no atribuida al docente).

Estado: **Cumplido (contenedor)** = implementado y verificado en el contenedor de validación (SQL Server 2022), pendiente de repetir en la laptop · **Preparado** = archivos listos, ejecución pendiente · **Pendiente** = requiere acción del equipo o información que no está en las fuentes.

## 1. Requisitos del producto

| ID | Requisito | Documento y página/sección | Tipo | Archivo(s) | Prueba / evidencia | Estado |
|---|---|---|---|---|---|---|
| R01 | Base de datos **en la nube** | F1; F3 p. 21; F4 p. 21 | OBL | `docs/05_azure/guia_azure.md`, `scripts/azure/crear_recursos_azure.ps1`, `sql/azure/verificacion_azure.sql`, `.env.azure.example` | `evidence/azure/` (vacío) | **Pendiente**: preparado; no se creó ningún recurso (requiere suscripción y autorización) |
| R02 | Definición de los requisitos de la empresa | F1; F3 p. 22; F4 p. 21 | OBL | `docs/01_requisitos/analisis_requisitos.md` | Informe §3-4 | Cumplido |
| R03 | Diseño del modelo de datos | F1; F3 p. 22; F4 p. 21 | OBL | `docs/02_modelo/` (conceptual, lógico, físico, normalización) | Diagramas `.png/.svg`; diccionario generado del catálogo | Cumplido |
| R04 | Creación de tablas | F1; F3 p. 22; F4 p. 21 | OBL | `sql/02`–`sql/04` | `adm.registro_despliegue`; despliegue en `evidence/contenedor_linux/` | Cumplido (contenedor) |
| R05 | Inserción de datos | F1; F3 p. 22; F4 p. 21 | OBL | `sql/09_datos_referencia.sql`, `src/aerolinea/generador.py`, `sql/10_carga_staging.sql` | `evidence/contenedor_linux/carga_sintetica.json` | Cumplido (contenedor) |
| R06 | Definición de consultas | F1; F3 p. 22; F4 p. 21 | OBL | `sql/consultas/Q01`–`Q20` | `reports/resultados/*.csv`, `docs/07_consultas/catalogo_consultas.md` | Cumplido (contenedor) |
| R07 | Implementación de las consultas en un lenguaje de programación | F1; F3 p. 22; F4 p. 21 | OBL | `src/aerolinea/consultas.py`, `operaciones.py` | `reports/resultados/manifiesto_consultas.json` | Cumplido (contenedor) |
| R08 | Fundamentos y DML | F1 (logro); F3 pp. 21-22; F4 p. 21 | OBL | `sql/07_procedimientos.sql`, `sql/11_dml_seguro.sql` | PR-03 a PR-13; ejecución de 11 en modo simulación | Cumplido (contenedor) |
| R09 | Restricciones | F1 (logro); F3 pp. 21-22; F4 p. 21 | OBL | `sql/03_claves_y_restricciones.sql`, `sql/05_funciones_y_triggers.sql` | PR-01, PR-02, PR-08, PR-14 a PR-17 | Cumplido (contenedor) |
| R10 | Agrupaciones y agregaciones | F1 (logro); F3 pp. 21-22; F4 p. 21 | OBL | Q02, Q03, Q06, Q07, Q09, Q11, Q12, Q17, Q20 | CSV de resultados | Cumplido (contenedor) |
| R11 | Vistas | F1 (logro); F3 pp. 21-22; F4 p. 21 | OBL | `sql/06_vistas.sql` | PR-20, PR-23 | Cumplido (contenedor) |
| R12 | Procedimientos almacenados | F1 (logro); F3 pp. 21-22; F4 p. 21 | OBL | `sql/07_procedimientos.sql` | PR-03 a PR-13, PR-18, PC-01 a PC-04 | Cumplido (contenedor) |
| R13 | Clientes | F1; F3 p. 22; F4 p. 21 | OBL | `ven.persona`, `ven.cliente` | PR-03, PR-04 | Cumplido |
| R14 | Empleados | F1; F3 p. 22; F4 p. 21 | OBL | `rh.empleado`, `rh.cargo`, `rh.departamento` | PR-15, PR-17 | Cumplido |
| R15 | Rutas con origen, destino, día de la semana y hora prevista | F1; F3 p. 22; F4 p. 21 | OBL | `ops.ruta`, `ops.programacion`, `ops.programacion_dia` | PR-14, PR-17; `rpt.v_programacion` | Cumplido |
| R16 | Vuelos generados a partir de una ruta programada | F1; F3 p. 22; F4 p. 21 | OBL | `ops.usp_generar_vuelos` | PR-18 (idempotencia); 3 588 vuelos generados | Cumplido (contenedor) |
| R17 | Localizaciones físicas y web de compra | F1; F3 p. 22; F4 p. 21 | OBL | `ref.localizacion` (AER, OFI, WEB), `ref.aeropuerto` | PR-02 (subtipo), PR-07 (efectivo solo físico), Q07 | Cumplido |
| R18 | Tiquetes comprados por clientes registrados o no | F1; F3 p. 22; F4 p. 21 | OBL | `ven.compra`, `ven.tiquete` | PR-03, Q08 | Cumplido |
| R19 | Aviones asignados a los viajes | F1; F3 p. 22; F4 p. 21 | OBL | `ops.avion`, `ops.usp_asignar_avion` | PR-15, Q10 | Cumplido |
| R20 | Cabina VIP o económica; precio por ruta y cabina | F1; F3 p. 22; F4 p. 21 | OBL | `ref.cabina`, `ven.tarifa` (versionada) | PR-05, Q06 | Cumplido |
| R21 | Uno o más pagos por tiquete | F1; F3 p. 22; F4 p. 21 | OBL | `ven.pago`, `ven.usp_registrar_pago` | PR-06, PR-07, PC-03 | Cumplido |
| R22 | Descuentos porcentuales sobre el precio original | F1; F3 p. 22; F4 p. 21 | OBL | `ven.descuento`, columnas calculadas en `ven.tiquete` | PR-04, Q20 | Cumplido |
| R23 | Ser exhaustivo con los atributos | F1; F3 p. 22; F4 p. 21 | OBL | `docs/02_modelo/diccionario_datos.md` (269 columnas con definición) | Generado del catálogo | Cumplido |
| R24 | Scripts en GitHub (registrarse, crear equipo y proyecto, subir scripts) | F3 p. 22; F4 p. 22 (no figura en F1) | OBL (guías) | Estructura del repositorio, `README.md`, `.gitignore`, `CONTRIBUTING.md` | — | **Pendiente**: el repositorio está listo localmente; crear la organización o el repositorio y subirlo requiere cuentas del equipo y su autorización |
| R25 | Presentación de 10 a 15 diapositivas, 20 minutos | F3 p. 22; F4 p. 22 | OBL (guías) | `slides/presentacion_PSMA00611.pptx`, `docs/defensa/guion_presentacion.md` | 14 diapositivas; notas del expositor que suman 20:00; `validate.py` sin errores | Cumplido (preparado); la exposición la realiza el equipo |
| R26 | Todos los integrantes exponen (asignación aleatoria) | F3 p. 23; F4 p. 22 | OBL (guías) | `docs/defensa/guia_estudio_comun.md`, `docs/defensa/preguntas_defensa.md` (24 preguntas), `docs/defensa/guion_demo.md` | — | Preparado; la preparación individual y la asignación real son del equipo |
| R27 | Entrega por el líder, carátula con participantes activos | F1 | OBL | Portada del informe | — | **Pendiente**: nombres `[POR COMPLETAR]` |
| R28 | Rúbrica: Información, Análisis, Conclusiones, Estilo/Gramática (0-5 c/u) | F1; F3 p. 24; F4 p. 23 | OBL | `reports/informe/informe_PSMA00611.docx` y `.pdf` (16 secciones), autoevaluación en el informe | Generado con `python -m aerolinea informe` | Preparado; falta completar la carátula |
| R29 | Mínimo de páginas del informe | Mencionado en la rúbrica; no especificado en F1-F4 (D12) | OBL (indefinido) | — | — | **Pendiente** de confirmar con el docente; propuesta editorial: 30-40 páginas de cuerpo |
| R30 | Fecha de entrega | F1: 16-nov-2026 23:59 (discrepancias de semana D1-D2) | OBL | — | — | Registrado |

## 2. Mejoras propuestas por el equipo

| ID | Mejora | Motivo | Archivo(s) | Evidencia | Estado |
|---|---|---|---|---|---|
| M01 | Al menos 15 consultas documentadas (se entregan 20) | Cubrir agrupación, ventanas, anti-joins, conciliación | `sql/consultas/`, `docs/07_consultas/` | CSV y manifiesto con SHA-256 | Cumplido (contenedor) |
| M02 | Python con pyodbc y pandas: parámetros enlazados, configuración externa, CSV y gráficos | Reproducibilidad y seguridad | `src/aerolinea/` | `reports/` | Cumplido (contenedor) |
| M03 | Control de concurrencia probado con sesiones simultáneas | Sin sobreventa, asientos duplicados ni doble cobro | `docs/03_arquitectura/concurrencia.md` | PC-01 a PC-04 | Cumplido (contenedor) |
| M04 | Datos sintéticos deterministas (semilla 20261106) | Resultados regenerables | `generador.py`, `data/sintetico/manifiesto.json` | SHA-256 de cada CSV | Cumplido (contenedor) |
| M05 | Seguridad: roles, privilegio mínimo, enmascaramiento, cifrado | Datos personales | `sql/08_seguridad.sql`, `docs/03_arquitectura/seguridad.md` | PR-19 | Cumplido (contenedor) |
| M06 | Pruebas automatizadas (pytest + T-SQL) | Verificabilidad | `tests/`, `sql/12_pruebas_integridad.sql` | `evidence/contenedor_linux/resultados_pruebas.md` | Cumplido (contenedor) |
| M07 | Diccionario y diagramas físicos generados del catálogo | Coherencia documento-código | `src/aerolinea/documentar.py` | `docs/02_modelo/` | Cumplido (contenedor) |
| M08 | Zonas horarias y llegadas al día siguiente | Red de EE. UU. con 5 husos y horario de verano | `ops.vuelo` (`datetimeoffset`), `rpt.v_vuelo` | PR-14 | Cumplido (contenedor) |
| M09 | Reproducción completa con un comando | Evaluación y defensa | `python -m aerolinea reproducir` | `evidence/contenedor_linux/` | Cumplido (contenedor); pendiente en laptop |
| M10 | Referencias en APA 7 verificadas | Rigor académico | Informe, sección de referencias; `docs/00_fuentes/revision_fuentes.md` | Ediciones, años y DOI comprobados en las fuentes en línea | Cumplido |
