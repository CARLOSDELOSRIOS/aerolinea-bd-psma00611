"""Catálogo de consultas: documentación completa y parámetros enlazados."""
import re

from aerolinea.consultas import catalogo

CAMPOS = {"Pregunta", "Utilidad", "Granularidad", "Filtros", "Fórmulas"}


def test_hay_al_menos_quince_consultas_documentadas():
    consultas = catalogo()
    assert len(consultas) >= 15
    for c in consultas:
        faltan = CAMPOS - set(c.campos)
        assert not faltan, f"{c.id}: faltan {faltan}"


def test_parametros_se_sustituyen_por_marcadores():
    for c in catalogo():
        sql = c.sql_parametrizado()
        marcadores = len(re.findall(r"=\s*\?;\s*--\s*@param", sql))
        assert marcadores == len(c.parametros), c.id
        for nombre, (_, valor) in c.parametros.items():
            if isinstance(valor, str) and valor:
                linea = next(l for l in sql.splitlines() if re.search(rf"DECLARE\s+@{nombre}\b", l))
                assert valor not in linea, f"{c.id}: el valor de @{nombre} sigue en el texto"
