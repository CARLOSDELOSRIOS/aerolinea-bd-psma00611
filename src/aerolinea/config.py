"""Configuración externa de la conexión.

La configuración se lee de variables de entorno. Opcionalmente se cargan desde un
archivo .env (ignorado por Git). La contraseña nunca se escribe en el código ni en
el repositorio: se toma de DB_PASSWORD o se solicita de forma interactiva.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

RAIZ_PROYECTO = Path(__file__).resolve().parents[2]

_VERDADERO = {"1", "yes", "si", "sí", "true", "on"}
AUTENTICACIONES = ("windows", "sql", "entra_interactivo", "entra_token")


class ErrorConfiguracion(ValueError):
    """La configuración es incompleta o insegura."""


@dataclass(frozen=True)
class ConfigBD:
    servidor: str
    base_datos: str
    autenticacion: str
    controlador: str | None
    cifrar: str
    confiar_certificado: bool
    usuario: str | None
    contrasena: str | None
    tiempo_espera: int
    nombre_host_certificado: str | None

    @property
    def es_azure(self) -> bool:
        return self.servidor.lower().split(",")[0].endswith(".database.windows.net")

    def descripcion_segura(self) -> dict[str, str]:
        """Resumen apto para registros y evidencias (sin secretos)."""
        return {
            "servidor": self.servidor,
            "base_datos": self.base_datos,
            "autenticacion": self.autenticacion,
            "controlador": self.controlador or "(autodetección)",
            "cifrar": self.cifrar,
            "confiar_certificado": "yes" if self.confiar_certificado else "no",
            "usuario": self.usuario or "(integrada)",
        }


def _cargar_archivo_env(ruta: Path) -> None:
    try:
        from dotenv import load_dotenv
    except ImportError:  # python-dotenv es opcional
        return
    if ruta.is_file():
        load_dotenv(ruta, override=False)


def cargar_config(archivo_env: str | os.PathLike[str] | None = None) -> ConfigBD:
    """Construye la configuración a partir del entorno y, si existe, de un .env."""
    ruta = Path(archivo_env) if archivo_env else Path(os.environ.get("AEROLINEA_ENV", RAIZ_PROYECTO / ".env"))
    _cargar_archivo_env(ruta)

    def leer(clave: str, defecto: str | None = None) -> str | None:
        valor = os.environ.get(clave, defecto)
        return valor.strip() if isinstance(valor, str) else valor

    autenticacion = (leer("DB_AUTH", "windows") or "windows").lower()
    if autenticacion not in AUTENTICACIONES:
        raise ErrorConfiguracion(f"DB_AUTH debe ser uno de {AUTENTICACIONES}; se recibió '{autenticacion}'.")

    cfg = ConfigBD(
        servidor=leer("DB_SERVER", "localhost") or "localhost",
        base_datos=leer("DB_DATABASE", "AerolineaDB") or "AerolineaDB",
        autenticacion=autenticacion,
        controlador=leer("DB_DRIVER") or None,
        cifrar=(leer("DB_ENCRYPT", "yes") or "yes").lower(),
        confiar_certificado=(leer("DB_TRUST_SERVER_CERTIFICATE", "no") or "no").lower() in _VERDADERO,
        usuario=leer("DB_USER") or None,
        contrasena=os.environ.get("DB_PASSWORD") or None,
        tiempo_espera=int(leer("DB_TIMEOUT", "30") or "30"),
        nombre_host_certificado=leer("DB_HOST_NAME_IN_CERTIFICATE") or None,
    )
    validar(cfg)
    return cfg


def validar(cfg: ConfigBD) -> None:
    """Rechaza combinaciones inseguras o incompletas."""
    if cfg.cifrar not in {"yes", "mandatory", "strict", "no", "optional"}:
        raise ErrorConfiguracion("DB_ENCRYPT debe ser yes, strict o no.")
    if cfg.es_azure:
        # En la nube se exige cifrado con validación del certificado del servidor.
        if cfg.cifrar in {"no", "optional"}:
            raise ErrorConfiguracion("Azure SQL Database exige DB_ENCRYPT=yes (o strict).")
        if cfg.confiar_certificado:
            raise ErrorConfiguracion(
                "Para Azure no se permite DB_TRUST_SERVER_CERTIFICATE=yes: el certificado debe validarse.")
        if cfg.autenticacion == "windows":
            raise ErrorConfiguracion("Azure SQL Database no admite autenticación de Windows; use entra_interactivo, entra_token o sql.")
    if cfg.autenticacion in {"sql", "entra_interactivo"} and not cfg.usuario:
        raise ErrorConfiguracion(f"DB_USER es obligatorio con DB_AUTH={cfg.autenticacion}.")
