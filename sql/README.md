# Scripts T-SQL

Todos los scripts son T-SQL de SQL Server. Los lotes se separan con `GO`, que **no es una instrucción del motor**: lo interpretan SSMS y `sqlcmd`; la aplicación de Python divide los lotes del lado del cliente (`src/aerolinea/sql_script.py`) antes de enviarlos.

## Orden de ejecución

| Script | Contenido | Depende de | ¿Se puede volver a ejecutar? |
|---|---|---|---|
| `00_verificacion_entorno.sql` | Diagnóstico de solo lectura: servidor, edición, versión, usuario, protocolo, cifrado, permisos y compatibilidad | — | Sí (no modifica nada) |
| `01_crear_base_datos_local.sql` | Crea `AerolineaDB` (intercalación `SQL_Latin1_General_CP1_CI_AS`) y activa `READ_COMMITTED_SNAPSHOT`. **Solo local**: en Azure la base se crea con el portal o la CLI | `master` | Sí (crea solo si no existe) |
| `02_esquemas_y_tablas.sql` | Esquemas, secuencias y tablas | 01 | Sí (`IF OBJECT_ID … IS NULL`) |
| `03_claves_y_restricciones.sql` | `UNIQUE`, `CHECK`, `FOREIGN KEY` e índices únicos filtrados | 02 | Sí |
| `04_indices.sql` | Índices de rendimiento | 03 | Sí |
| `05_funciones_y_triggers.sql` | Funciones (calendario, política de reembolso) y triggers de reglas de negocio | 04 | Sí (`CREATE OR ALTER`) |
| `06_vistas.sql` | Vistas de reporte `rpt.*` | 05 | Sí |
| `07_procedimientos.sql` | Procedimientos de negocio (emitir, pagar, cancelar, generar vuelos…) | 06 | Sí |
| `08_seguridad.sql` | Roles, permisos, enmascaramiento dinámico y usuarios de demostración sin inicio de sesión | 07 | Sí |
| `09_datos_referencia.sql` | Catálogos, red de rutas, flota, horarios, tarifas, descuentos, políticas y empleados | 08 | Sí (inserta lo que falta) |
| `10_carga_staging.sql` | Tablas `stg.*` y procedimiento que aplica la carga sintética en una sola transacción | 09 | Sí |
| `11_dml_seguro.sql` | Ejemplos de `INSERT`/`UPDATE`/`DELETE` con transacción, `OUTPUT` y confirmación explícita (por defecto `ROLLBACK`). **No forma parte del despliegue** | datos cargados | Sí (simula por defecto) |
| `12_pruebas_integridad.sql` | Procedimientos `tst.*` con las pruebas PR-01 a PR-23 | 10 | Sí |
| `13_descripciones.sql` | Definiciones de tablas y columnas como propiedades extendidas `MS_Description` (visibles en SSMS). **Generado** por `python -m aerolinea documentar` | 12 | Sí |
| `99_DESTRUCTIVO_eliminar_base_local.sql` | **Destructivo.** Elimina la base local. Exige cambiar `@confirmar` a 1, rechaza Azure y debe ejecutarse desde `master` | — | — |
| `consultas/Q01…Q20` | Catálogo de consultas analíticas documentadas | datos cargados | Sí (solo lectura) |
| `azure/` | Verificación posterior al despliegue en Azure SQL Database | despliegue en Azure | Sí (solo lectura) |

Los datos transaccionales (personas, compras, tiquetes, pagos, reembolsos, vuelos operados) **no** están en scripts: los genera `python -m aerolinea cargar-datos` con semilla fija y los aplica `stg.usp_aplicar_carga_sintetica`.

## Cómo ejecutarlos

**Opción recomendada (un comando):** `python -m aerolinea desplegar --crear-bd` ejecuta 01 y 02–13 en orden y muestra el tiempo de cada script (ver el `README.md` principal).

**SSMS:** abra cada archivo en orden, verifique en la barra superior que la base activa es `AerolineaDB` (01 y 99 se ejecutan desde `master`) y pulse *Ejecutar* (F5). Los scripts 02 en adelante no contienen `USE`: así sirven igual en Azure SQL Database, donde `USE` no cambia de base.

**sqlcmd:** use `-I` para activar `QUOTED_IDENTIFIER` (los índices filtrados y las columnas calculadas persistidas lo exigen):

```bat
sqlcmd -S localhost -E -C -I -d AerolineaDB -i sql\02_esquemas_y_tablas.sql
```

`-E` = autenticación de Windows; `-C` = confiar en el certificado del servidor (solo para la instancia local con certificado autofirmado; ver `docs/04_entorno_local`). Nunca use `-C` contra Azure.

## Salvaguardas comunes

- Cada script de 02 en adelante se detiene si la conexión apunta a una base del sistema (`master`, `model`, `msdb`, `tempdb`) mediante `RAISERROR` + `SET NOEXEC ON`.
- Las operaciones destructivas están aisladas en `99_DESTRUCTIVO_…` y en `stg.usp_vaciar_staging`/`tst.usp_limpiar_escenarios`, que solo afectan al área de carga y a los escenarios de prueba (vuelos 9900–9999).
- Cada script registra su ejecución en `adm.registro_despliegue`.
- Compatibilidad objetivo: SQL Server 2016 SP1 o posterior (nivel de compatibilidad 130) y Azure SQL Database. Se usan `CREATE OR ALTER` (2016 SP1), `AT TIME ZONE` y `sp_set_session_context` (2016); no se usan funciones de 2017 o posteriores (`STRING_AGG`, `TRIM`, `CONCAT_WS`, `GREATEST`, `GENERATE_SERIES`…). Qué se comprobó y qué no: `docs/06_pruebas/plan_pruebas.md`.
