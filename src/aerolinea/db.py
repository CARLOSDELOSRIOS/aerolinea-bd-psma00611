"""Gestión segura de conexiones, transacciones y resultados con pyodbc."""
from __future__ import annotations

import datetime as dt
import getpass
import re
import struct
from contextlib import contextmanager
from decimal import Decimal
from typing import Any, Iterator, Sequence

import pyodbc

from .config import ConfigBD

# Sin pooling del administrador de controladores: cada conexión es una sesión nueva.
# Con el pooling activo (valor por defecto de pyodbc), unixODBC reutiliza la sesión
# física sin restablecerla y una transacción abierta o un SET de una conexión anterior
# se hereda en la siguiente (hallazgo H-13 en docs/06_pruebas). Debe fijarse antes de
# la primera conexión del proceso.
pyodbc.pooling = False

# Tipo ODBC de DATETIMEOFFSET; pyodbc no lo convierte de forma nativa.
SQL_SS_TIMESTAMPOFFSET = -155
# Atributo de conexión para token de acceso de Microsoft Entra ID.
SQL_COPT_SS_ACCESS_TOKEN = 1256

CONTROLADORES_PREFERIDOS = ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server")


class ErrorBaseDatos(RuntimeError):
    """Error del motor con número y mensaje legibles."""

    def __init__(self, numero: int | None, mensaje: str, original: Exception | None = None):
        super().__init__(f"[{numero}] {mensaje}" if numero else mensaje)
        self.numero = numero
        self.mensaje = mensaje
        self.original = original


def elegir_controlador(preferido: str | None = None) -> str:
    instalados = pyodbc.drivers()
    if preferido:
        if preferido not in instalados:
            raise ErrorBaseDatos(None, f"El controlador '{preferido}' no está instalado. Disponibles: {instalados}")
        return preferido
    for nombre in CONTROLADORES_PREFERIDOS:
        if nombre in instalados:
            return nombre
    raise ErrorBaseDatos(None, "No se encontró 'ODBC Driver 18/17 for SQL Server'. Instálelo (ver README). "
                               f"Controladores disponibles: {instalados}")


def _escapar(valor: str) -> str:
    """Escapa un valor para la cadena ODBC: {valor} con '}' duplicado."""
    return "{" + valor.replace("}", "}}") + "}"


def cadena_conexion(cfg: ConfigBD, controlador: str) -> str:
    partes = [
        f"DRIVER={{{controlador}}}",
        f"SERVER={cfg.servidor}",
        f"DATABASE={cfg.base_datos}",
        f"Encrypt={cfg.cifrar}",
        f"TrustServerCertificate={'yes' if cfg.confiar_certificado else 'no'}",
        "APP=aerolinea-python",
    ]
    if cfg.nombre_host_certificado:
        partes.append(f"HostNameInCertificate={cfg.nombre_host_certificado}")
    if cfg.autenticacion == "windows":
        partes.append("Trusted_Connection=yes")
    elif cfg.autenticacion == "sql":
        contrasena = cfg.contrasena or getpass.getpass(f"Contraseña de {cfg.usuario}: ")
        partes += [f"UID={_escapar(cfg.usuario or '')}", f"PWD={_escapar(contrasena)}"]
    elif cfg.autenticacion == "entra_interactivo":
        partes += ["Authentication=ActiveDirectoryInteractive", f"UID={_escapar(cfg.usuario or '')}"]
    return ";".join(partes)


def _token_entra() -> bytes:
    """Obtiene un token de Microsoft Entra ID con azure-identity (dependencia opcional)."""
    try:
        from azure.identity import DefaultAzureCredential
    except ImportError as exc:
        raise ErrorBaseDatos(None, "DB_AUTH=entra_token requiere 'pip install -r requirements-azure.txt'.", exc)
    token = DefaultAzureCredential().get_token("https://database.windows.net/.default").token
    datos = token.encode("utf-16-le")
    return struct.pack(f"<I{len(datos)}s", len(datos), datos)


def _convertir_datetimeoffset(valor: bytes | None) -> dt.datetime | None:
    if valor is None:
        return None
    anio, mes, dia, hora, minuto, segundo, nanos, desf_h, desf_m = struct.unpack("<6hI2h", valor)
    zona = dt.timezone(dt.timedelta(hours=desf_h, minutes=desf_m))
    return dt.datetime(anio, mes, dia, hora, minuto, segundo, nanos // 1000, tzinfo=zona)


def abrir_conexion(cfg: ConfigBD, autocommit: bool = False) -> pyodbc.Connection:
    controlador = elegir_controlador(cfg.controlador)
    atributos: dict[int, Any] = {}
    if cfg.autenticacion == "entra_token":
        atributos[SQL_COPT_SS_ACCESS_TOKEN] = _token_entra()
    try:
        conexion = pyodbc.connect(cadena_conexion(cfg, controlador), autocommit=autocommit,
                                  timeout=cfg.tiempo_espera, attrs_before=atributos or None)
    except pyodbc.Error as exc:
        raise traducir_error(exc) from None
    conexion.add_output_converter(SQL_SS_TIMESTAMPOFFSET, _convertir_datetimeoffset)
    return conexion


@contextmanager
def conectar(cfg: ConfigBD, autocommit: bool = False) -> Iterator[pyodbc.Connection]:
    """Conexión que se cierra siempre y revierte lo no confirmado si hay error."""
    conexion = abrir_conexion(cfg, autocommit=autocommit)
    try:
        yield conexion
    except Exception:
        if not autocommit:
            conexion.rollback()
        raise
    finally:
        conexion.close()


@contextmanager
def transaccion(conexion: pyodbc.Connection) -> Iterator[pyodbc.Cursor]:
    """Confirma al terminar sin errores; revierte en caso contrario."""
    cursor = conexion.cursor()
    try:
        yield cursor
        conexion.commit()
    except Exception:
        conexion.rollback()
        raise
    finally:
        cursor.close()


_PATRON_ERROR = re.compile(r"\[SQL Server\](?P<msg>.*?)\s*\((?P<num>\d+)\)\s*(?:\(SQL|$|;)", re.S)


def traducir_error(exc: pyodbc.Error) -> ErrorBaseDatos:
    """Extrae número y mensaje del error de SQL Server."""
    texto = " ".join(str(a) for a in exc.args)
    coincidencias = list(_PATRON_ERROR.finditer(texto))
    # El mensaje puede traer avisos informativos antes del error (p. ej. 8153, "Warning: Null value is
    # eliminated by an aggregate"); se informa el primer registro que no sea un aviso.
    errores = [m for m in coincidencias if not m.group("msg").lstrip().startswith("Warning:") and m.group("num") != "8153"]
    elegida = (errores or coincidencias or [None])[0]
    if elegida:
        return ErrorBaseDatos(int(elegida.group("num")), elegida.group("msg").strip(), exc)
    return ErrorBaseDatos(None, texto, exc)


def consumir_resultados(cursor: pyodbc.Cursor) -> list[tuple[list[str], list[tuple]]]:
    """Recorre todos los conjuntos de resultados.

    Es imprescindible: un error de una sentencia posterior del lote solo se
    manifiesta al avanzar con nextset().
    """
    conjuntos: list[tuple[list[str], list[tuple]]] = []
    try:
        while True:
            if cursor.description is not None:
                columnas = [c[0] for c in cursor.description]
                conjuntos.append((columnas, [tuple(f) for f in cursor.fetchall()]))
            if not cursor.nextset():
                break
    except pyodbc.Error as exc:
        raise traducir_error(exc) from None
    return conjuntos


def ejecutar(cursor: pyodbc.Cursor, sql: str, parametros: Sequence[Any] = ()) -> list[tuple[list[str], list[tuple]]]:
    try:
        cursor.execute(sql, *parametros) if parametros else cursor.execute(sql)
    except pyodbc.Error as exc:
        raise traducir_error(exc) from None
    return consumir_resultados(cursor)


def a_python(valor: Any) -> Any:
    """Normaliza tipos para CSV y pandas (Decimal se conserva)."""
    if isinstance(valor, (bytes, bytearray)):
        return valor.hex()
    return valor


def dataframe(columnas: list[str], filas: list[tuple]):
    import pandas as pd
    return pd.DataFrame.from_records([tuple(a_python(v) for v in f) for f in filas], columns=columnas)


def es_decimal(valor: Any) -> bool:
    return isinstance(valor, Decimal)
