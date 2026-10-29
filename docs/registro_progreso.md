# Registro de progreso y pendientes efectivos

Este registro describe el trabajo de preparación hecho en el entorno de desarrollo (contenedor Linux con SQL Server 2022 Developer 16.0.4305.5, ODBC Driver 18, Python 3.13). **No** registra aportes de integrantes: esos van en [`equipo/registro_aportes.md`](equipo/registro_aportes.md) y en el historial de GitHub, y solo los puede completar el equipo.

## 1. Estado por etapa

| Etapa | Resultado | Entorno donde se verificó | Evidencia |
|---|---|---|---|
| 0 · Fuentes y entorno | 4 fuentes revisadas; 12 discrepancias registradas (D1-D12); versión del motor, edición y permisos comprobados en el contenedor | Contenedor | `docs/00_fuentes/revision_fuentes.md`, `evidence/contenedor_linux/entorno_versiones.txt` |
| 1 · Requisitos | 30 requisitos del enunciado y las guías (R01-R30), 10 de calidad (M01-M10), 42 reglas (RN-01…RN-42), 13 supuestos (SUP-01…SUP-13) | Revisión documental | `docs/01_requisitos/`, `docs/00_fuentes/matriz_requisitos.md` |
| 2 · Implementación T-SQL | Scripts `sql/01`-`13`, idempotentes; la única eliminación está aislada en `99_DESTRUCTIVO_eliminar_base_local.sql` y en `reiniciar-local --confirmar-destruccion` | Contenedor; también con compatibilidad 130 | `evidence/contenedor_linux/compatibilidad_130/despliegue.txt` |
| 3 · Procedimientos, vistas y consultas | 16 procedimientos de negocio, 9 vistas, 2 funciones, 20 consultas documentadas, DML seguro con simulación | Contenedor | `reports/resultados/`, `evidence/contenedor_linux/dml_seguro_simulacion.txt` |
| 4 · Python | Conexión, generador con semilla 20261106, carga transaccional, CLI, CSV, gráficos, informe | Contenedor | `evidence/contenedor_linux/carga_sintetica.json` |
| 5 · Pruebas | 23/23 T-SQL, 4/4 concurrencia, 23/23 pytest; 20 hallazgos corregidos | Contenedor (nivel 160 y 130) | `evidence/contenedor_linux/resultados_pruebas.md`, `docs/06_pruebas/hallazgos_y_correcciones.md` |
| 6 · Modelado | Diagramas conceptual, lógicos (4) y físicos (3); diccionario de 269 columnas generado del catálogo | Contenedor | `docs/02_modelo/` |
| 7 · Azure | Guía, script de creación (simulación por defecto), verificación de solo lectura, configuración segura | **No ejecutado en Azure** | `docs/05_azure/guia_azure.md` |
| 8 · Informe | DOCX editable y PDF (A4, 16 secciones, 21 tablas, 15 figuras, índice actualizado) | Generado en el contenedor | `reports/informe/` |
| 9 · Presentación y defensa | 14 diapositivas con notas (20:00), guion, demostración, guía de estudio, 24 preguntas | Generado y validado en el contenedor | `slides/`, `docs/defensa/` |
| 10 · Documento de avance del PA | DOCX y PDF de 18 páginas: estado por componente, verificación, plan de trabajo propuesto, riesgos y consultas al docente | Generado en el contenedor | `reports/avance/` |

## 2. Pendientes efectivos

Solo el equipo puede resolverlos, porque requieren identidades, cuentas, equipos o autorizaciones que no están en este entorno.

| # | Pendiente | Quién | Requiere | Dónde se refleja al terminar |
|---|---|---|---|---|
| P1 | Completar carátula: integrantes activos, docente, sección/NRC, líder, lugar y fecha | Equipo | Datos reales | `reports/informe/informe_fuente.md` (líneas 22-30), `slides/construir_presentacion.js` (autor y portada), `README.md`; luego `python -m aerolinea informe` y `node construir_presentacion.js` |
| P2 | Declarar el uso de herramientas de IA según las normas de la universidad y del docente | Equipo | Norma aplicable | Informe, Anexo E (texto preparado para completar) |
| P3 | Ejecutar en la laptop Windows: `verificar_entorno.ps1` y `reproducir --confirmar-destruccion` | Equipo | Laptop con SQL Server, SSMS, Python y ODBC | `evidence/laptop_windows/`; columna «Laptop» de `docs/06_pruebas/plan_pruebas.md` |
| P4 | Comparar los CSV de la laptop con `data/sintetico/manifiesto.json` (SHA-256) antes de citar cifras como obtenidas en la laptop | Equipo | P3 | `README.md`, informe §10-11 |
| P5 | Desplegar en Azure SQL Database | Equipo | Suscripción, autorización expresa para crear recursos, administrador Entra (`docs/05_azure/guia_azure.md`, campo «Quién administra») | `evidence/azure/` según la lista de evidencias de la guía; R01 en la matriz |
| P6 | Invitar a los integrantes al repositorio ya publicado (https://github.com/CARLOSDELOSRIOS/aerolinea-bd-psma00611) | Propietario del repositorio | Usuarios de GitHub de los integrantes | R24 en la matriz |
| P7 | Registrar los aportes reales y las actas de reunión | Cada integrante | Trabajo real realizado | `docs/equipo/registro_aportes.md`, `docs/equipo/plantilla_acta_reunion.md` |
| P8 | Confirmar con el docente el mínimo de páginas (D12) y la semana del avance (D1); verificar la fecha de entrega en el aula virtual (D2) | Equipo | Respuesta del docente | `docs/00_fuentes/revision_fuentes.md`, R29-R30 |
| P9 | Ensayo cronometrado de la exposición y de la demostración en la laptop que se usará | Todos | P3 | `docs/defensa/guion_demo.md` (lista de preparación) |
| P10 | Si hay evidencia de laptop o de Azure, actualizar el informe (§8, §10, §11, anexos) y la diapositiva 13, y regenerar ambos documentos | Equipo | P3, P5 | `reports/informe/`, `slides/` |

## 3. Lo que no se hizo y por qué

- **No se creó ningún recurso en Azure** ni se usó una suscripción: requiere autorización expresa y puede generar costos.
- **El repositorio se publicó solo cuando el propietario de la cuenta lo pidió** (https://github.com/CARLOSDELOSRIOS/aerolinea-bd-psma00611). El primer commit figura a nombre del asistente de IA (autor «Claude»), no de un integrante; los aportes del equipo deben verse en sus propios commits.
- **No se ejecutó nada en la laptop**: este entorno remoto no tiene acceso a ella. Los scripts y la guía están listos.
- **No se asignaron exposiciones ni aportes**: la modalidad es aleatoria y los aportes solo los puede declarar el equipo.
