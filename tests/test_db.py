"""Construcción de la cadena de conexión y traducción de errores (sin servidor)."""
import pyodbc

from aerolinea.config import ConfigBD
from aerolinea.db import cadena_conexion, traducir_error


def _cfg(**cambios):
    base = dict(servidor="localhost", base_datos="AerolineaDB", autenticacion="sql", controlador=None, cifrar="yes",
                confiar_certificado=False, usuario="usr", contrasena="a;b}c", tiempo_espera=30, nombre_host_certificado=None)
    base.update(cambios)
    return ConfigBD(**base)


def test_contrasena_con_caracteres_especiales_se_escapa():
    cadena = cadena_conexion(_cfg(), "ODBC Driver 18 for SQL Server")
    assert "PWD={a;b}}c}" in cadena
    assert "Encrypt=yes" in cadena


def test_windows_no_incluye_credenciales():
    cadena = cadena_conexion(_cfg(autenticacion="windows", usuario=None, contrasena=None), "ODBC Driver 18 for SQL Server")
    assert "Trusted_Connection=yes" in cadena
    assert "PWD" not in cadena and "UID" not in cadena


def test_traduce_numero_y_mensaje_del_motor():
    exc = pyodbc.Error("42000", "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]"
                                "RN-11: sin disponibilidad en la cabina VIP del vuelo 7. (50020) (SQLExecDirectW)")
    error = traducir_error(exc)
    assert error.numero == 50020
    assert error.mensaje.startswith("RN-11")


def test_ignora_avisos_previos_al_error():
    exc = pyodbc.Error("42000", "[01003] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Warning: Null value is "
                                "eliminated by an aggregate or other SET operation. (8153) "
                                "[42000] [Microsoft][ODBC Driver 18 for SQL Server][SQL Server]El monto excede el saldo pendiente. (50135)")
    error = traducir_error(exc)
    assert error.numero == 50135
