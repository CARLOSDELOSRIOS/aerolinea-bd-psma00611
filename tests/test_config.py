"""La configuración rechaza combinaciones inseguras y no expone secretos."""
import pytest

from aerolinea.config import ErrorConfiguracion, cargar_config

VARIABLES = ("DB_SERVER", "DB_DATABASE", "DB_AUTH", "DB_DRIVER", "DB_ENCRYPT", "DB_TRUST_SERVER_CERTIFICATE",
             "DB_USER", "DB_PASSWORD", "DB_TIMEOUT", "DB_HOST_NAME_IN_CERTIFICATE", "AEROLINEA_ENV")


@pytest.fixture
def entorno(monkeypatch, tmp_path):
    for v in VARIABLES:
        monkeypatch.delenv(v, raising=False)
    vacio = tmp_path / "vacio.env"
    vacio.write_text("", encoding="utf-8")

    def configurar(**valores):
        for clave, valor in valores.items():
            monkeypatch.setenv(clave, valor)
        return cargar_config(vacio)
    return configurar


def test_local_por_defecto_windows_y_cifrado(entorno):
    cfg = entorno()
    assert (cfg.servidor, cfg.autenticacion, cfg.cifrar) == ("localhost", "windows", "yes")
    assert not cfg.es_azure


def test_azure_exige_validar_certificado(entorno):
    with pytest.raises(ErrorConfiguracion):
        entorno(DB_SERVER="srv.database.windows.net", DB_AUTH="entra_interactivo", DB_USER="a@b.com",
                DB_TRUST_SERVER_CERTIFICATE="yes")


def test_azure_exige_cifrado(entorno):
    with pytest.raises(ErrorConfiguracion):
        entorno(DB_SERVER="srv.database.windows.net", DB_AUTH="entra_interactivo", DB_USER="a@b.com", DB_ENCRYPT="no")


def test_azure_no_admite_autenticacion_windows(entorno):
    with pytest.raises(ErrorConfiguracion):
        entorno(DB_SERVER="tcp:srv.database.windows.net,1433", DB_AUTH="windows")


def test_azure_valido(entorno):
    cfg = entorno(DB_SERVER="srv.database.windows.net", DB_AUTH="entra_interactivo", DB_USER="a@b.com")
    assert cfg.es_azure and not cfg.confiar_certificado


def test_autenticacion_desconocida(entorno):
    with pytest.raises(ErrorConfiguracion):
        entorno(DB_AUTH="kerberos_magico")


def test_descripcion_segura_no_incluye_contrasena(entorno):
    cfg = entorno(DB_AUTH="sql", DB_USER="usuario", DB_PASSWORD="S3creta!")
    assert "S3creta!" not in str(cfg.descripcion_segura())
