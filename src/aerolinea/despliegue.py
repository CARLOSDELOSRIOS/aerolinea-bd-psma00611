"""Despliegue ordenado de los scripts T-SQL y verificación del entorno."""
from __future__ import annotations

import dataclasses
import json
import platform
import time
from datetime import datetime, timezone
from pathlib import Path

import pyodbc

from .config import RAIZ_PROYECTO, ConfigBD
from .db import conectar, ejecutar
from .sql_script import ejecutar_script

DIR_SQL = RAIZ_PROYECTO / "sql"

# Orden de ejecución y dependencias (ver sql/README.md).
SCRIPTS_BASE = [
    "02_esquemas_y_tablas.sql",
    "03_claves_y_restricciones.sql",
    "04_indices.sql",
    "05_funciones_y_triggers.sql",
    "06_vistas.sql",
    "07_procedimientos.sql",
    "08_seguridad.sql",
    "09_datos_referencia.sql",
    "10_carga_staging.sql",
    "12_pruebas_integridad.sql",
    "13_descripciones.sql",       # generado por «documentar»; se omite si aún no existe
]
OPCIONALES = {"13_descripciones.sql"}

CONSULTA_ENTORNO = """
SELECT @@SERVERNAME AS servidor,
       CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS edicion,
       CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS version,
       SUSER_SNAME() AS usuario_actual,
       CAST(SERVERPROPERTY('EngineEdition') AS int) AS edicion_motor,
       DB_NAME() AS base_datos,
       (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()) AS nivel_compatibilidad,
       (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = DB_NAME()) AS rcsi,
       CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS nvarchar(128)) AS intercalacion,
       c.net_transport AS protocolo, c.encrypt_option AS cifrado, c.auth_scheme AS autenticacion
FROM sys.dm_exec_connections AS c
WHERE c.session_id = @@SPID;
"""


def informacion_entorno(cfg: ConfigBD) -> dict:
    """Ejecuta la consulta de verificación y devuelve un diccionario serializable."""
    with conectar(cfg, autocommit=True) as conexion:
        columnas, filas = ejecutar(conexion.cursor(), CONSULTA_ENTORNO)[0]
        datos = {c: (str(v) if v is not None else None) for c, v in zip(columnas, filas[0])}
        datos["controlador_odbc"] = conexion.getinfo(pyodbc.SQL_DRIVER_NAME) + " " + conexion.getinfo(pyodbc.SQL_DRIVER_VER)
    datos["python"] = platform.python_version()
    datos["pyodbc"] = pyodbc.version
    datos["sistema_cliente"] = f"{platform.system()} {platform.release()}"
    datos["configuracion"] = cfg.descripcion_segura()
    datos["verificado_utc"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    return datos


def crear_base_local(cfg: ConfigBD, eco=print) -> None:
    if cfg.es_azure:
        raise RuntimeError("En Azure la base se crea desde el portal o con Azure CLI (docs/05_azure).")
    maestra = dataclasses.replace(cfg, base_datos="master")
    with conectar(maestra, autocommit=True) as conexion:
        ejecutar_script(conexion, DIR_SQL / "01_crear_base_datos_local.sql", eco=eco)


def eliminar_base_local(cfg: ConfigBD, eco=print) -> None:
    """Ejecuta el script destructivo con confirmación explícita (solo local)."""
    if cfg.es_azure:
        raise RuntimeError("La eliminación desde la aplicación está deshabilitada para Azure.")
    ruta = DIR_SQL / "99_DESTRUCTIVO_eliminar_base_local.sql"
    texto = ruta.read_text(encoding="utf-8").replace("DECLARE @confirmar BIT = 0;", "DECLARE @confirmar BIT = 1;", 1)
    maestra = dataclasses.replace(cfg, base_datos="master")
    with conectar(maestra, autocommit=True) as conexion:
        cursor = conexion.cursor()
        ejecutar(cursor, texto)
        for _, mensaje in getattr(cursor, "messages", None) or []:
            eco(str(mensaje).split("]")[-1].strip())


def desplegar(cfg: ConfigBD, scripts: list[str] | None = None, eco=print) -> list[dict]:
    """Ejecuta los scripts de base de datos en orden; devuelve un registro por script."""
    registro = []
    with conectar(cfg, autocommit=True) as conexion:
        for nombre in scripts or SCRIPTS_BASE:
            if nombre in OPCIONALES and not (DIR_SQL / nombre).exists():
                eco(f"  {nombre:<36} (omitido: no existe todavía)")
                continue
            inicio = time.perf_counter()
            resultado = ejecutar_script(conexion, DIR_SQL / nombre)
            segundos = round(time.perf_counter() - inicio, 2)
            eco(f"  {nombre:<36} {resultado.lotes:>3} lotes  {segundos:>6.2f} s")
            registro.append({"script": nombre, "lotes": resultado.lotes, "segundos": segundos})
    return registro


def guardar_json(datos, ruta: Path) -> Path:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(json.dumps(datos, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    return ruta
