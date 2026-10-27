"""El separador GO se interpreta en el cliente y nunca se envía al motor."""
from aerolinea.sql_script import dividir_lotes


def test_divide_por_go_y_respeta_repeticiones():
    lotes = dividir_lotes("SELECT 1;\nGO\nSELECT 2;\ngo 3\nSELECT 3;")
    assert [l.texto for l in lotes] == ["SELECT 1;", "SELECT 2;", "SELECT 3;"]
    assert [l.repeticiones for l in lotes] == [1, 3, 1]
    assert [l.linea_inicio for l in lotes] == [1, 3, 5]


def test_go_dentro_de_comentario_de_bloque_anidado_no_separa():
    texto = "/* nivel 1 /* nivel 2\nGO\n*/ sigue\nGO\n*/\nSELECT 1;\nGO"
    lotes = dividir_lotes(texto)
    assert len(lotes) == 1
    assert "SELECT 1;" in lotes[0].texto


def test_go_dentro_de_literal_de_texto_no_separa():
    texto = "PRINT 'primera línea\nGO\núltima';\nGO\nSELECT 2;"
    lotes = dividir_lotes(texto)
    assert len(lotes) == 2
    assert lotes[0].texto.endswith("última';")


def test_go_con_comentario_de_linea_y_espacios():
    lotes = dividir_lotes("SELECT 1;\n   GO   -- fin del lote\nSELECT 2;")
    assert len(lotes) == 2


def test_palabras_que_empiezan_por_go_no_separan():
    lotes = dividir_lotes("SELECT 1 AS GOAL;\nGOTO etiqueta;\nGO")
    assert len(lotes) == 1


def test_ningun_lote_contiene_go_en_los_scripts_del_proyecto():
    from aerolinea.config import RAIZ_PROYECTO
    import re
    for ruta in sorted((RAIZ_PROYECTO / "sql").glob("*.sql")):
        for lote in dividir_lotes(ruta.read_text(encoding="utf-8")):
            assert not re.search(r"^\s*GO\s*$", lote.texto, re.IGNORECASE | re.MULTILINE), ruta.name
