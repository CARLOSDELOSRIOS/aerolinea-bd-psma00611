# Base de datos de una aerolínea comercial (PSMA00611)

Producto Académico Colaborativo del curso **Gestión de datos y bases de datos con SQL** (PSMA00611), Maestría en Ciencia de Datos, Escuela de Posgrado de la Universidad Continental.
Equipo: [POR COMPLETAR] · Docente: [POR COMPLETAR] · Sección/NRC: [POR COMPLETAR]

Base de datos en SQL Server / Azure SQL Database para una aerolínea que opera en Estados Unidos: clientes registrados y no registrados, empleados y tripulación, rutas con horario semanal, vuelos fechados generados desde la programación, localizaciones físicas y web, aviones con mapa de asientos, cabinas VIP y económica con tarifas versionadas por ruta, tiquetes, pagos parciales, descuentos, cancelaciones y reembolsos. Incluye una aplicación de consola en Python para desplegar, cargar datos sintéticos reproducibles, ejecutar consultas parametrizadas, exportar CSV, generar gráficos y correr las pruebas.

> **Datos sintéticos.** Todas las personas, ventas y operaciones son ficticias (semilla 20261106). Los dominios web usan `.test` y los correos `example.com`/`.test`.

## Estado de verificación

| Entorno | Estado | Evidencia |
|---|---|---|
| Contenedor Linux con SQL Server 2022 Developer (validación durante el desarrollo) | **Ejecutado**: reproducción completa, 23 de 23 pruebas T-SQL, 4 de 4 de concurrencia, 23 de 23 pruebas de Python, 20 consultas; repetido con nivel de compatibilidad 130 (SQL Server 2016) | [`evidence/contenedor_linux/`](evidence/contenedor_linux/) |
| Laptop Windows del equipo (SQL Server local, `MSSQLSERVER`) | **Pendiente**: seguir la sección «Reproducir desde cero en Windows» | `evidence/laptop_windows/` |
| Azure SQL Database (requisito de nube) | **Pendiente**: no se creó ningún recurso; guía y scripts listos | [`docs/05_azure/guia_azure.md`](docs/05_azure/guia_azure.md) |

El contenedor **no** es la laptop ni Azure: demuestra que el código funciona sobre un motor SQL Server real, pero no sustituye la evidencia en esos entornos.

## Entregables

| Entregable | Archivo | Estado |
|---|---|---|
| Informe académico (16 secciones, APA 7) | [`reports/informe/informe_PSMA00611.docx`](reports/informe/informe_PSMA00611.docx) (editable) y [`.pdf`](reports/informe/informe_PSMA00611.pdf) | Generado; carátula `[POR COMPLETAR]` |
| Presentación (14 diapositivas, 20 minutos, notas del expositor) | [`slides/presentacion_PSMA00611.pptx`](slides/presentacion_PSMA00611.pptx) | Generada |
| Guion, demostración, guía de estudio y 24 preguntas de defensa | [`docs/defensa/`](docs/defensa/) | Preparados; la asignación real de exposiciones es del equipo |
| Modelo, diccionario y diagramas | [`docs/02_modelo/`](docs/02_modelo/) | Generados del catálogo |
| Consultas con resultados e interpretación | [`docs/07_consultas/catalogo_consultas.md`](docs/07_consultas/catalogo_consultas.md) | 20 consultas ejecutadas en el contenedor |
| Matriz de requisitos y trazabilidad | [`docs/00_fuentes/matriz_requisitos.md`](docs/00_fuentes/matriz_requisitos.md) | Actualizada |

## Requisitos previos (Windows)

| Componente | Versión | Cómo comprobarlo |
|---|---|---|
| SQL Server (motor) | 2016 SP1 o posterior; cualquier edición (Express, Developer, Standard) | `sql\00_verificacion_entorno.sql` en SSMS |
| SSMS | Versión actual | *Ayuda → Acerca de* |
| Python | 3.11 o posterior (probado con 3.13) | `py --version` |
| Controlador ODBC | **ODBC Driver 18 for SQL Server** (o 17), 64 bits | `Get-OdbcDriver \| Where-Object Name -like "*SQL Server*"` |
| Permisos | Crear bases de datos (`dbcreator` o `sysadmin`) en la instancia local | `sql\00_verificacion_entorno.sql`, consulta 4 |

`scripts\windows\verificar_entorno.ps1` comprueba todo lo anterior en modo de solo lectura y guarda un informe en `evidence\laptop_windows\`. Detalles y solución de problemas: [`docs/04_entorno_local/guia_entorno_local.md`](docs/04_entorno_local/guia_entorno_local.md).

## Reproducir desde cero en Windows

En PowerShell, dentro de la carpeta del proyecto:

```powershell
# 1. Verificación del entorno (solo lectura)
powershell -ExecutionPolicy Bypass -File .\scripts\windows\verificar_entorno.ps1

# 2. Entorno virtual y dependencias
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt

# 3. Configuración (autenticación de Windows, cifrado activo)
Copy-Item .env.example .env
#    revise .env: DB_SERVER=localhost, DB_AUTH=windows, DB_ENCRYPT=yes,
#    DB_TRUST_SERVER_CERTIFICATE=yes solo por el certificado autofirmado de la instancia local

# 4. Pruebas de la aplicación (no necesitan servidor)
python -m pytest

# 5. Todo en un comando: base nueva, carga, pruebas, consultas, gráficos y documentación
python -m aerolinea --evidencia evidence\laptop_windows reproducir --confirmar-destruccion
```

El paso 5 **elimina y recrea la base local** `AerolineaDB` (por eso exige `--confirmar-destruccion`; se niega a hacerlo contra Azure). Tarda unos 5 minutos en el contenedor de referencia; en otro equipo puede variar. Si la base aún no existe, la verificación inicial se hace conectando a `master`.

## Comandos de la aplicación

`python -m aerolinea [--env ARCHIVO] [--evidencia CARPETA] <comando>`

| Comando | Qué hace |
|---|---|
| `verificar-conexion` | Muestra servidor, edición, versión, usuario, protocolo y cifrado; guarda un JSON de evidencia |
| `desplegar [--crear-bd] [--solo SCRIPT…]` | Ejecuta los scripts `sql/02`–`13` en orden (y `01` con `--crear-bd`) |
| `reiniciar-local --confirmar-destruccion` | Elimina y recrea la base **local** y despliega los scripts |
| `cargar-datos [--semilla N] [--corte FECHA]` | Genera vuelos desde la programación, datos sintéticos y los carga con todas las reglas activas |
| `pruebas [--sin-concurrencia]` | Pruebas T-SQL PR-01 a PR-23 y de concurrencia PC-01 a PC-04 |
| `consultas [--id Q01 …] [--param nombre=valor …] [--salida CARPETA]` | Ejecuta el catálogo Q01–Q20 con parámetros enlazados y exporta CSV |
| `graficos` | Genera las figuras F01–F08 a partir de los CSV |
| `documentar` | Diccionario de datos, `sql/13_descripciones.sql` y diagramas físicos desde el catálogo |
| `demo` | Demostración: atomicidad ante un error y flujo completo emitir → pagar en dos partes → cancelar (se revierte) |
| `emitir-tiquete`, `registrar-pago`, `cancelar-tiquete` | Invocan los procedimientos almacenados con parámetros |
| `reproducir --confirmar-destruccion` | Secuencia completa de los pasos anteriores |

Ejemplo de consulta con parámetros: `python -m aerolinea consultas --id Q16 --param dias=7 origen=JFK`.

## Regenerar el informe y la presentación (opcional)

No hacen falta para usar la base de datos; sirven para volver a producir los documentos después de cambiar resultados o textos.

| Herramienta | Para qué | Comando |
|---|---|---|
| pandoc 3.x y LibreOffice | Informe DOCX y PDF con índice actualizado (`reports/informe/informe_fuente.md` → `.docx` → `.pdf`) | `python -m aerolinea informe` (`--sin-pdf` si no hay LibreOffice) |
| Graphviz (`dot`) | Exportar los diagramas `.mmd` a PNG, SVG y PDF | `python -m aerolinea documentar` (si falta, intenta con `mmdc` de Mermaid CLI) |
| Node.js 18+ | Presentación con `pptxgenjs` (versiones fijadas en `slides/package-lock.json`) | `cd slides; npm ci; node construir_presentacion.js` |

`npm audit` informa una vulnerabilidad de denegación de servicio en `image-size` 1.2.1 (dependencia de `pptxgenjs` 4.0.1) al leer imágenes JXL, HEIF o ICNS manipuladas; el script solo procesa los PNG que genera el propio proyecto, y la corrección que propone npm baja a `pptxgenjs` 4.0.0, por lo que no se aplicó.

Las tablas del informe y las cifras de las diapositivas se leen de `reports/resultados/` y de `evidence/contenedor_linux/` (rutas fijas en `src/aerolinea/informe.py` y `slides/construir_presentacion.js`); el texto redactado del informe cita los resultados del contenedor. Con la misma semilla los datos deberían ser idénticos en la laptop, pero eso debe comprobarse comparando los CSV y el manifiesto SHA-256 antes de presentar cifras como obtenidas en la laptop.

## Solo con SSMS

Los scripts de `sql/` se pueden ejecutar en orden desde SSMS (ver [`sql/README.md`](sql/README.md)). Así se crean la estructura, las reglas y los datos de referencia, y se pueden correr las pruebas (`EXEC tst.usp_ejecutar_pruebas;`) y las consultas. Los datos transaccionales (ventas, pagos, vuelos operados) los genera Python; sin ese paso, las consultas analíticas devuelven pocos o ningún resultado.

## Estructura

```
README.md                  este archivo
CONTRIBUTING.md            flujo de trabajo y reglas para contribuir
requirements*.txt          dependencias (versiones probadas); requirements-azure.txt para Entra ID con token
.env.example               configuración local de ejemplo (sin secretos)
.env.azure.example         configuración de Azure de ejemplo (sin secretos)
pyproject.toml             metadatos y configuración de pytest
docs/
  00_fuentes/              revisión de fuentes, discrepancias y matriz de requisitos
  01_requisitos/           análisis de requisitos, casos de uso, supuestos y reglas RN-01…RN-42
  02_modelo/               modelo conceptual, lógico y físico, normalización y diccionario de datos
  03_arquitectura/         arquitectura, concurrencia y seguridad
  04_entorno_local/        guía de la laptop Windows
  05_azure/                guía de despliegue en Azure SQL Database
  06_pruebas/              plan de pruebas y hallazgos corregidos
  07_consultas/            catálogo de consultas con resultados e interpretaciones
  defensa/                 guion, tiempos, demostración, guía de estudio y preguntas de defensa
  equipo/                  plantillas de registro de aportes y actas
sql/                       scripts T-SQL numerados, consultas Q01–Q20 y verificación de Azure
src/aerolinea/             aplicación de Python
scripts/                   verificación de Windows y creación de recursos de Azure
tests/                     pruebas de la aplicación (pytest)
data/                      datos sintéticos generados (CSV excluidos de Git) y su manifiesto SHA-256
reports/                   resultados CSV, figuras e informe académico
slides/                    presentación
evidence/                  evidencias por entorno
```

## Resultados principales (contenedor de validación)

- Carga de casi 1,2 millones de filas (323 718 tiquetes, 388 003 pagos, 18 182 reembolsos, 3 588 vuelos) en una transacción con todas las restricciones y triggers activos: ~90 s.
- 23/23 pruebas T-SQL, 4/4 pruebas de concurrencia (sin sobreventa, sin asientos duplicados, sin doble cobro) y 23/23 pruebas de la aplicación.
- Controles de conciliación (Q19): cero diferencias, incluida la identidad de caja al centavo.
- 20 hallazgos reales detectados y corregidos durante el desarrollo: [`docs/06_pruebas/hallazgos_y_correcciones.md`](docs/06_pruebas/hallazgos_y_correcciones.md).

## Seguridad

- Sin secretos en el repositorio: `.env` y `.env.azure` están en `.gitignore`; con autenticación de Windows o Entra ID no hay contraseñas.
- Cifrado siempre activo. `TrustServerCertificate=yes` solo para la instancia local con certificado autofirmado; en Azure el certificado se valida y la aplicación rechaza lo contrario.
- No se requiere habilitar SQL Server Browser, SQL Server Agent ni acceso remoto a la instancia local.
- Consultas desde Python siempre con parámetros enlazados; los valores del usuario nunca se concatenan en el SQL.

## Publicar en GitHub (lo hace el equipo)

El repositorio está preparado, pero **no** se ha creado ni publicado nada. Cuando el equipo lo autorice:

1. El líder crea el repositorio (u organización) en GitHub e invita a los integrantes (requisito de las guías: F3 y F4, p. 22).
2. Desde esta carpeta: `git init`, `git add .`, revisar con `git status` que no aparezcan `.env` ni CSV de `data/sintetico/`, `git commit` con la cuenta de quien sube, `git remote add origin …` y `git push`.
3. Cada integrante registra sus aportes reales en [`docs/equipo/registro_aportes.md`](docs/equipo/registro_aportes.md) y trabaja con ramas y *pull requests* ([`CONTRIBUTING.md`](CONTRIBUTING.md)). No se fabrica historial de colaboración.

## Pendientes del equipo

Ver la lista completa en [`docs/registro_progreso.md`](docs/registro_progreso.md). Los principales: datos de carátula `[POR COMPLETAR]`, ejecución en la laptop, despliegue en Azure con autorización, publicación en GitHub, confirmación del número mínimo de páginas del informe y de la semana de entrega del avance (discrepancias D1, D2 y D12 en [`docs/00_fuentes/revision_fuentes.md`](docs/00_fuentes/revision_fuentes.md)).
