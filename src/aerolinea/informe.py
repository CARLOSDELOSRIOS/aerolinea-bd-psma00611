"""Construcción del informe académico (DOCX editable y PDF).

Fuente editable:   reports/informe/informe_fuente.md  (Markdown de pandoc)
Tablas de datos:   se insertan desde reports/resultados/*.csv, los manifiestos y
                   las evidencias, de modo que las cifras del informe proceden de
                   resultados guardados (marcadores [[TABLA:ID]]).
Salidas:           reports/informe/informe_PSMA00611.docx  (pandoc + plantilla de estilos)
                   reports/informe/informe_PSMA00611.pdf   (LibreOffice, con el índice actualizado)

Requiere pandoc y, para el PDF, LibreOffice con su módulo de Python (uno).
"""
from __future__ import annotations

import csv
import json
import re
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path

from .config import RAIZ_PROYECTO

DIR_INFORME = RAIZ_PROYECTO / "reports" / "informe"
DIR_RESULTADOS = RAIZ_PROYECTO / "reports" / "resultados"
FUENTE = DIR_INFORME / "informe_fuente.md"
PLANTILLA = DIR_INFORME / "plantilla_estilos.docx"
SALIDA_DOCX = DIR_INFORME / "informe_PSMA00611.docx"
SALIDA_PDF = DIR_INFORME / "informe_PSMA00611.pdf"
NBSP = "\u00a0"


# --------------------------------------------------------------------- formatos
def _numero(valor, decimales: int) -> str:
    if valor in (None, "") or (isinstance(valor, float) and valor != valor):
        return "—"
    texto = f"{float(valor):,.{decimales}f}"
    entero, _, fraccion = texto.partition(".")
    entero = entero.replace(",", NBSP)
    return entero + ("," + fraccion if fraccion else "")


FORMATOS = {
    "texto": lambda v: "—" if v in (None, "") else str(v),
    "entero": lambda v: _numero(v, 0),
    "usd": lambda v: _numero(v, 2),
    "dec1": lambda v: _numero(v, 1),
    "pct": lambda v: "—" if v in (None, "") else _numero(float(v) * 100, 1) + NBSP + "%",
    "pct_directo": lambda v: "—" if v in (None, "") else _numero(v, 1) + NBSP + "%",
    "mes": lambda v: {"01": "ene", "02": "feb", "03": "mar", "04": "abr", "05": "may", "06": "jun", "07": "jul",
                      "08": "ago", "09": "sep", "10": "oct", "11": "nov", "12": "dic"}[str(v)[5:7]] + " " + str(v)[:4],
    "bool": lambda v: "sí" if str(v).lower() in ("true", "1") else "no",
}


def _celda(texto: str) -> str:
    return str(texto).replace("|", "\\|").replace("\n", " ")


def tabla_markdown(titulo: str, encabezados: list[str], filas: list[list[str]], anchos: list[int],
                   alineacion: list[str] | None = None, nota: str | None = None) -> str:
    """Tabla pipe de pandoc. Los anchos relativos se expresan con el número de guiones del separador."""
    alineacion = alineacion or ["l"] * len(encabezados)
    separador = []
    for ancho, a in zip(anchos, alineacion):
        guiones = "-" * max(3, ancho)
        separador.append(("" if a == "l" else ":") + guiones[: -1 if a == "r" else None] + (":" if a == "r" else ""))
    lineas = [f"Table: {titulo}", "", "| " + " | ".join(_celda(e) for e in encabezados) + " |",
              "|" + "|".join(separador) + "|"]
    lineas += ["| " + " | ".join(_celda(c) for c in fila) + " |" for fila in filas]
    if nota:
        lineas += ["", f"::: {{custom-style=\"Nota Tabla\"}}\n{nota}\n:::"]
    return "\n".join(lineas)


def _leer_csv(nombre: str) -> list[dict]:
    with (DIR_RESULTADOS / f"{nombre}.csv").open(encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def tabla_csv(titulo: str, nombre: str, columnas: list[tuple[str, str, str, int]], filtro=None, nota=None,
              limite: int | None = None) -> str:
    """columnas: (columna CSV, encabezado, formato, ancho relativo)."""
    filas = [f for f in _leer_csv(nombre) if (filtro(f) if filtro else True)]
    if limite:
        filas = filas[:limite]
    cuerpo = [[FORMATOS[fmt](f[col]) for col, _, fmt, _ in columnas] for f in filas]
    alineacion = ["l" if fmt in ("texto", "mes", "bool") else "r" for _, _, fmt, _ in columnas]
    fuente = f"Fuente: `reports/resultados/{nombre}.csv` (consulta `sql/consultas/{nombre}.sql`). Datos sintéticos."
    return tabla_markdown(titulo, [c[1] for c in columnas], cuerpo, [c[3] for c in columnas], alineacion,
                          (nota + " " if nota else "") + fuente)


# ------------------------------------------------------------ tablas del informe
def _tabla_pruebas() -> str:
    datos = json.loads((RAIZ_PROYECTO / "evidence" / "contenedor_linux" / "resultados_pruebas.json").read_text(encoding="utf-8"))
    filas = [[p["id"], p["tipo"], p["regla"], p["descripcion"], p["resultado"].capitalize()] for p in datos["pruebas"]]
    e = datos["entorno"]
    nota = (f"Ejecución del {datos['inicio_utc'][:10]} en `{e['servidor']}` ({e['edicion']}, {e['version']}), "
            f"READ_COMMITTED_SNAPSHOT = {e['rcsi']}, conexión cifrada = {e['cifrado']}. "
            f"Resultado: {datos['resumen']['superadas']} de {datos['resumen']['total']} superadas. "
            "Fuente: `evidence/contenedor_linux/resultados_pruebas.json`.")
    return tabla_markdown("Resultados de las pruebas de reglas y de concurrencia (contenedor de validación)",
                          ["ID", "Tipo", "Regla", "Caso probado", "Resultado"], filas, [8, 13, 12, 56, 11],
                          nota=nota)


def _tabla_consultas() -> str:
    m = json.loads((DIR_RESULTADOS / "manifiesto_consultas.json").read_text(encoding="utf-8"))
    filas = [[q, d["titulo"], ", ".join(f"@{k} = {v}" for k, v in d["parametros"].items()) or "—",
              FORMATOS["entero"](d["filas"]), FORMATOS["entero"](d["duracion_ms"])] for q, d in m["consultas"].items()]
    nota = (f"Ejecución del {m['ejecutado_utc'][:10]} en `{m['servidor']}` ({m['edicion']}, {m['version']}). "
            "Fuente: `reports/resultados/manifiesto_consultas.json`, que guarda también la huella SHA-256 de cada SQL.")
    return tabla_markdown("Consultas ejecutadas desde Python con parámetros enlazados",
                          ["ID", "Consulta", "Parámetros", "Filas", "ms"], filas, [5, 40, 34, 8, 6],
                          ["l", "l", "l", "r", "r"], nota)


def _tabla_diccionario() -> str:
    with (RAIZ_PROYECTO / "docs" / "02_modelo" / "diccionario_datos.csv").open(encoding="utf-8-sig") as f:
        filas = [r for r in csv.DictReader(f, delimiter=";") if r["esquema"] == "ven" and r["tabla"] == "tiquete"]
    cuerpo = []
    for r in sorted(filas, key=lambda x: int(x["orden"])):
        claves = re.sub(r"FK → (\w+\.\w+)\.\w+", r"FK → \1", r["claves"])
        claves = re.sub(r"\(filtrado: .*?\)(?=; |$)", "(filtrado)", claves)
        cuerpo.append([r["columna"], r["tipo"], r["nulo"], claves or "—", r["definicion"]])
    return tabla_markdown("Diccionario de datos de la tabla `ven.tiquete`", ["Columna", "Tipo", "Nulo", "Claves", "Definición"],
                          cuerpo, [17, 13, 6, 26, 38], nota="Fuente: `docs/02_modelo/diccionario_datos.csv`, generado desde el catálogo del motor.")


def _filas_markdown(ruta: Path, desde: str, hasta: str | None = None) -> list[list[str]]:
    texto = ruta.read_text(encoding="utf-8")
    texto = texto[texto.index(desde):]
    if hasta and hasta in texto:
        texto = texto[: texto.index(hasta)]
    filas = []
    for linea in texto.splitlines():
        if linea.startswith("| ") and not linea.startswith("|---"):
            filas.append([c.strip() for c in re.split(r"(?<!\\)\|", linea.strip())[1:-1]])
    return filas[1:]   # sin encabezado


def _tabla_matriz() -> str:
    ruta = RAIZ_PROYECTO / "docs" / "00_fuentes" / "matriz_requisitos.md"
    filas = _filas_markdown(ruta, "## 1. Requisitos del producto", "## 2.")
    filas += _filas_markdown(ruta, "## 2. Mejoras propuestas")
    cuerpo = []
    for f in filas:
        if f[0].startswith("R"):
            cuerpo.append([f[0], f[1], f[2], f[3], f[4], f[6]])
        else:   # mejoras: ID, mejora, motivo, archivos, evidencia, estado
            cuerpo.append([f[0], f[1], "Propuesta del equipo", "MEJ", f[3], f[5]])
    return tabla_markdown("Matriz de trazabilidad de requisitos", ["ID", "Requisito", "Documento y página", "Tipo",
                          "Archivo(s)", "Estado"], cuerpo, [6, 24, 15, 6, 27, 22],
                          nota="Fuente: `docs/00_fuentes/matriz_requisitos.md`. F1: enunciado del aula virtual; F3: guía de "
                               "aprendizaje general; F4: guía «VIERNES».")


def _tabla_hallazgos() -> str:
    filas = _filas_markdown(RAIZ_PROYECTO / "docs" / "06_pruebas" / "hallazgos_y_correcciones.md", "| ID |", "## Observaciones")
    cuerpo = [[f[0], f[1], f[2], f[3]] for f in filas if f and f[0].startswith("H-")]
    return tabla_markdown("Defectos detectados y corregidos durante el desarrollo", ["ID", "Síntoma observado", "Causa", "Corrección"],
                          cuerpo, [7, 29, 33, 31], nota="Fuente: `docs/06_pruebas/hallazgos_y_correcciones.md` (incluye la evidencia de cada corrección).")


TABLAS = {
    "PRUEBAS": _tabla_pruebas,
    "CONSULTAS": _tabla_consultas,
    "DICCIONARIO_TIQUETE": _tabla_diccionario,
    "MATRIZ": _tabla_matriz,
    "HALLAZGOS": _tabla_hallazgos,
    "Q03": lambda: tabla_csv("Ventas, cobros y reembolsos por mes (Q03)", "Q03_ventas_cobros_reembolsos_mes", [
        ("mes", "Mes", "mes", 9), ("tiquetes_vendidos", "Tiquetes vendidos", "entero", 11),
        ("ventas_brutas_usd", "Ventas brutas", "usd", 14), ("ventas_vigentes_usd", "Ventas vigentes", "usd", 14),
        ("cobros_usd", "Cobros confirmados", "usd", 14), ("reembolsos_usd", "Reembolsos", "usd", 12),
        ("cobro_neto_usd", "Cobro neto", "usd", 14)], nota="Importes en USD."),
    "Q04": lambda: tabla_csv("Reservas con saldo pendiente a la fecha de corte (Q04)", "Q04_saldos_pendientes", [
        ("situacion", "Situación", "texto", 26), ("plazo", "Plazo hasta el vencimiento", "texto", 22),
        ("tiquetes", "Tiquetes", "entero", 9), ("valor_reservado_usd", "Valor reservado", "usd", 13),
        ("abonado_usd", "Abonado", "usd", 12), ("saldo_pendiente_usd", "Saldo pendiente", "usd", 13)], nota="Importes en USD."),
    "Q05": lambda: tabla_csv("Cancelaciones y reembolsos por motivo, regla y cabina (Q05)", "Q05_reembolsos", [
        ("motivo", "Motivo", "texto", 17), ("regla", "Regla aplicada", "texto", 18), ("codigo_cabina", "Cabina", "texto", 7),
        ("tiquetes", "Tiquetes", "entero", 8), ("porcentaje_politica_medio", "% política medio", "pct_directo", 9),
        ("cobrado_usd", "Cobrado", "usd", 12), ("reembolsado_usd", "Reembolsado", "usd", 12),
        ("penalidad_retenida_usd", "Retenido", "usd", 11), ("tasa_reembolso", "Tasa de reembolso", "pct", 9)],
        nota="Importes en USD. Tasa de reembolso = reembolsado / cobrado (nula si no hubo cobro)."),
    "Q08": lambda: tabla_csv("Compradores registrados frente a no registrados (Q08)", "Q08_registrados_vs_no_registrados", [
        ("comprador", "Comprador", "texto", 13), ("compras", "Compras", "entero", 9), ("compradores_distintos", "Personas distintas", "entero", 11),
        ("tiquetes", "Tiquetes", "entero", 9), ("tiquetes_por_compra", "Tiquetes por compra", "usd", 9),
        ("ventas_brutas_usd", "Ventas brutas (USD)", "usd", 13), ("precio_medio_usd", "Precio medio (USD)", "usd", 9),
        ("tasa_cancelacion", "Tasa de cancelación", "pct", 9), ("proporcion_web", "Canal web", "pct", 8)]),
    "Q12": lambda: tabla_csv("Anticipación de la compra y precio medio pagado (Q12)", "Q12_anticipacion_compra", [
        ("tramo", "Anticipación", "texto", 16), ("tiquetes", "Tiquetes", "entero", 10), ("participacion", "Participación", "pct", 11),
        ("precio_medio_eco_usd", "Precio medio ECO (USD)", "usd", 13), ("precio_medio_vip_usd", "Precio medio VIP (USD)", "usd", 13),
        ("penetracion_descuentos", "Con descuento", "pct", 11)], nota="Vuelos operados en septiembre y octubre de 2026."),
    "Q18": lambda: tabla_csv("Horas de vuelo de la tripulación en 672 horas consecutivas (Q18)", "Q18_tripulacion_horas", [
        ("rol_vuelo", "Rol", "texto", 15), ("tripulantes", "Tripulantes", "entero", 9), ("asignaciones", "Asignaciones", "entero", 10),
        ("horas_minimas", "Horas mín.", "dec1", 8), ("horas_promedio", "Horas medias", "dec1", 8), ("horas_maximas", "Horas máx.", "dec1", 8),
        ("pilotos_sobre_100h", "Pilotos > 100 h", "entero", 9), ("vuelos_operados_sin_pilotos", "Vuelos sin 2 pilotos", "entero", 9)],
        nota="Ventana del 1 al 28 de octubre de 2026; horas de bloque programadas."),
    "Q19": lambda: tabla_csv("Controles de integridad y conciliación (Q19)", "Q19_controles_conciliacion", [
        ("control", "Control", "texto", 60), ("filas_con_diferencia", "Filas con diferencia", "entero", 12),
        ("diferencia_usd", "Diferencia (USD)", "usd", 12)]),
    "Q20": lambda: tabla_csv("Uso y costo de los descuentos (Q20)", "Q20_uso_descuentos", [
        ("codigo_descuento", "Código", "texto", 14), ("porcentaje", "%", "dec1", 6), ("codigo_cabina", "Cabina", "texto", 7),
        ("solo_clientes_registrados", "Solo registrados", "bool", 9), ("tiquetes", "Tiquetes", "entero", 9),
        ("costo_descuento_usd", "Costo (USD)", "usd", 12), ("participacion_registrados", "Compradores registrados", "pct", 11)],
        nota="Tiquetes no cancelados. Cabina vacía = todas."),
}


# ---------------------------------------------------------- preparación del texto
def preparar_markdown() -> tuple[str, list[str], list[str]]:
    texto = FUENTE.read_text(encoding="utf-8")
    for clave, funcion in TABLAS.items():
        texto = texto.replace(f"[[TABLA:{clave}]]", funcion())
    pendientes = re.findall(r"\[\[TABLA:(\w+)\]\]", texto)
    if pendientes:
        raise ValueError(f"Marcadores de tabla sin definir: {pendientes}")
    tablas, figuras = [], []

    def numerar_tabla(m):
        tablas.append(m.group(1))
        return f"Table: Tabla {len(tablas)}. {m.group(1)}"

    def numerar_figura(m):
        figuras.append(m.group(1))
        return f"![Figura {len(figuras)}. {m.group(1)}]({m.group(2)})"

    texto = re.sub(r"^Table: (.+)$", numerar_tabla, texto, flags=re.M)
    texto = re.sub(r"!\[(.+?)\]\(([^)]+)\)", numerar_figura, texto)
    return texto, tablas, figuras


# ------------------------------------------------------------ plantilla de estilos
_W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
_FUENTE = '<w:rFonts w:ascii="Calibri" w:eastAsia="Calibri" w:hAnsi="Calibri" w:cs="Calibri" />'
_AZUL = "1F3864"


def _estilo_parrafo(style_id: str, nombre: str, ppr: str, rpr: str, basado="Normal") -> str:
    return (f'<w:style w:type="paragraph" w:customStyle="1" w:styleId="{style_id}"><w:name w:val="{nombre}" />'
            f'<w:basedOn w:val="{basado}" /><w:qFormat /><w:pPr>{ppr}</w:pPr><w:rPr>{rpr}</w:rPr></w:style>')


def _reemplazar_estilo(estilos: str, style_id: str, xml: str) -> str:
    inicio = estilos.index(f'w:styleId="{style_id}"')
    inicio = estilos.rindex("<w:style ", 0, inicio)
    fin = estilos.index("</w:style>", inicio) + len("</w:style>")
    return estilos[:inicio] + xml + estilos[fin:]


def construir_plantilla(destino: Path = PLANTILLA) -> Path:
    """Parte de la plantilla de pandoc y ajusta estilos, página A4 y numeración de páginas."""
    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp) / "base.docx"
        subprocess.run(["pandoc", "-o", str(base), "--print-default-data-file", "reference.docx"], check=True)
        with zipfile.ZipFile(base) as z:
            partes = {n: z.read(n) for n in z.namelist()}
    estilos = partes["word/styles.xml"].decode("utf-8")
    estilos = re.sub(r'<w:rFonts w:asciiTheme="minorHAnsi"[^>]*/>', _FUENTE, estilos, count=1)
    estilos = estilos.replace('<w:sz w:val="24" />\n        <w:szCs w:val="24" />\n        <w:lang w:val="en-US"',
                              '<w:sz w:val="22" />\n        <w:szCs w:val="22" />\n        <w:lang w:val="es-PE"', 1)
    estilos = re.sub(r'<w:rFonts w:asciiTheme="majorHAnsi"[^>]*/>', _FUENTE, estilos)
    estilos = estilos.replace('<w:color w:val="4F81BD" w:themeColor="accent1" />', f'<w:color w:val="{_AZUL}" />')
    # Cuerpo: interlineado 1,5 y separación moderada.
    estilos = estilos.replace('<w:spacing w:before="180" w:after="180" />',
                              '<w:spacing w:before="0" w:after="140" w:line="360" w:lineRule="auto" />', 1)
    # Título 1 en página nueva; título 2 con más aire.
    estilos = estilos.replace('<w:spacing w:before="480" w:after="0" />\n      <w:outlineLvl w:val="0" />',
                              '<w:pageBreakBefore /><w:spacing w:before="0" w:after="240" />\n      <w:outlineLvl w:val="0" />')
    estilos = estilos.replace('<w:spacing w:before="200" w:after="0" />\n      <w:outlineLvl w:val="1" />',
                              '<w:spacing w:before="320" w:after="120" />\n      <w:outlineLvl w:val="1" />')
    estilos = estilos.replace('<w:sz w:val="28" />\n      <w:szCs w:val="28" />', '<w:sz w:val="26" />\n      <w:szCs w:val="26" />', 1)
    # Estilos reescritos completos (respetando el orden de elementos del esquema de WordprocessingML).
    # Pandoc usa «Compact» para listas compactas y para celdas; las celdas pasan a «CompactTabla» en el posprocesado.
    estilos = _reemplazar_estilo(estilos, "Compact",
        '<w:style w:type="paragraph" w:customStyle="1" w:styleId="Compact"><w:name w:val="Compact" /><w:basedOn w:val="BodyText" />'
        '<w:qFormat /><w:pPr><w:spacing w:before="0" w:after="80" w:line="300" w:lineRule="auto" /></w:pPr></w:style>'
        '<w:style w:type="paragraph" w:customStyle="1" w:styleId="CompactTabla"><w:name w:val="Compact Tabla" /><w:basedOn w:val="Compact" />'
        '<w:qFormat /><w:pPr><w:spacing w:before="20" w:after="20" w:line="240" w:lineRule="auto" /></w:pPr>'
        '<w:rPr><w:sz w:val="18" /><w:szCs w:val="18" /></w:rPr></w:style>')
    estilos = _reemplazar_estilo(estilos, "Table",
        '<w:style w:type="table" w:default="1" w:styleId="Table"><w:name w:val="Table" /><w:basedOn w:val="TableNormal" />'
        '<w:semiHidden /><w:unhideWhenUsed /><w:qFormat /><w:tblPr><w:tblInd w:w="0" w:type="dxa" /><w:tblBorders>'
        '<w:top w:val="single" w:sz="8" w:space="0" w:color="52514E" /><w:bottom w:val="single" w:sz="8" w:space="0" w:color="52514E" />'
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="D9D9D9" /></w:tblBorders><w:tblCellMar>'
        '<w:top w:w="0" w:type="dxa" /><w:left w:w="85" w:type="dxa" /><w:bottom w:w="0" w:type="dxa" /><w:right w:w="85" w:type="dxa" />'
        '</w:tblCellMar></w:tblPr><w:tblStylePr w:type="firstRow"><w:rPr><w:b /><w:bCs /></w:rPr><w:tblPr><w:jc w:val="left" />'
        '<w:tblInd w:w="0" w:type="dxa" /></w:tblPr><w:trPr><w:tblHeader /><w:jc w:val="left" /></w:trPr><w:tcPr><w:tcBorders>'
        '<w:bottom w:val="single" w:sz="8" w:space="0" w:color="52514E" /></w:tcBorders><w:shd w:val="clear" w:color="auto" w:fill="EEF3FA" />'
        '<w:vAlign w:val="bottom" /></w:tcPr></w:tblStylePr></w:style>')
    estilos = _reemplazar_estilo(estilos, "TableCaption",
        '<w:style w:type="paragraph" w:customStyle="1" w:styleId="TableCaption"><w:name w:val="Table Caption" /><w:basedOn w:val="Caption" />'
        '<w:pPr><w:keepNext /><w:spacing w:before="200" w:after="80" /></w:pPr>'
        '<w:rPr><w:b /><w:bCs /><w:i w:val="0" /><w:sz w:val="20" /><w:szCs w:val="20" /></w:rPr></w:style>')
    estilos = _reemplazar_estilo(estilos, "ImageCaption",
        '<w:style w:type="paragraph" w:customStyle="1" w:styleId="ImageCaption"><w:name w:val="Image Caption" /><w:basedOn w:val="Caption" />'
        '<w:pPr><w:spacing w:before="60" w:after="240" /><w:jc w:val="center" /></w:pPr>'
        '<w:rPr><w:i /><w:iCs /><w:color w:val="52514E" /><w:sz w:val="19" /><w:szCs w:val="19" /></w:rPr></w:style>')
    estilos = _reemplazar_estilo(estilos, "VerbatimChar",
        '<w:style w:type="character" w:customStyle="1" w:styleId="VerbatimChar"><w:name w:val="Verbatim Char" />'
        '<w:basedOn w:val="BodyTextChar" /><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas" />'
        '<w:color w:val="1F3864" /><w:sz w:val="19" /><w:szCs w:val="19" /></w:rPr></w:style>')
    nuevos = "".join([
        _estilo_parrafo("PortadaInstitucion", "Portada Institucion", '<w:spacing w:before="0" w:after="60" /><w:jc w:val="center" />',
                        f'<w:b /><w:caps /><w:color w:val="{_AZUL}" /><w:sz w:val="28" /><w:szCs w:val="28" />'),
        _estilo_parrafo("PortadaCurso", "Portada Curso", '<w:spacing w:before="600" w:after="120" /><w:jc w:val="center" />',
                        '<w:sz w:val="26" /><w:szCs w:val="26" />'),
        _estilo_parrafo("PortadaTitulo", "Portada Titulo", '<w:spacing w:before="1200" w:after="600" w:line="300" w:lineRule="auto" /><w:jc w:val="center" />',
                        f'<w:b /><w:color w:val="{_AZUL}" /><w:sz w:val="36" /><w:szCs w:val="36" />'),
        _estilo_parrafo("PortadaDatos", "Portada Datos", '<w:spacing w:before="0" w:after="100" /><w:ind w:left="1134" /><w:jc w:val="left" />',
                        '<w:sz w:val="22" /><w:szCs w:val="22" />'),
        _estilo_parrafo("TituloIndice", "Titulo Indice", '<w:spacing w:before="0" w:after="240" />',
                        f'<w:b /><w:color w:val="{_AZUL}" /><w:sz w:val="32" /><w:szCs w:val="32" />'),
        _estilo_parrafo("NotaTabla", "Nota Tabla", '<w:spacing w:before="40" w:after="200" w:line="240" w:lineRule="auto" />',
                        '<w:i /><w:iCs /><w:color w:val="52514E" /><w:sz w:val="17" /><w:szCs w:val="17" />'),
        _estilo_parrafo("SourceCode", "Source Code", '<w:shd w:val="clear" w:color="auto" w:fill="F4F4F2" /><w:spacing w:before="60" w:after="160" w:line="240" w:lineRule="auto" /><w:ind w:left="113" w:right="113" />',
                        '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas" /><w:sz w:val="17" /><w:szCs w:val="17" />'),
        _estilo_parrafo("TOC1", "toc 1", '<w:tabs><w:tab w:val="right" w:leader="dot" w:pos="9060" /></w:tabs><w:spacing w:before="80" w:after="20" />',
                        '<w:b /><w:bCs /><w:sz w:val="22" /><w:szCs w:val="22" />'),
        _estilo_parrafo("TOC2", "toc 2", '<w:tabs><w:tab w:val="right" w:leader="dot" w:pos="9060" /></w:tabs><w:spacing w:before="0" w:after="0" /><w:ind w:left="284" />',
                        '<w:sz w:val="20" /><w:szCs w:val="20" />'),
    ])
    estilos = estilos.replace("</w:styles>", nuevos + "</w:styles>")
    partes["word/styles.xml"] = estilos.encode("utf-8")

    # Página A4, márgenes de 2,5 cm, número de página arriba a la derecha (sin número en la portada).
    encabezado = (f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr {_W}><w:p><w:pPr><w:jc w:val="right" /></w:pPr>'
                  '<w:r><w:rPr><w:sz w:val="18" /></w:rPr><w:fldChar w:fldCharType="begin" /></w:r>'
                  '<w:r><w:rPr><w:sz w:val="18" /></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
                  '<w:r><w:rPr><w:sz w:val="18" /></w:rPr><w:fldChar w:fldCharType="separate" /></w:r>'
                  '<w:r><w:rPr><w:sz w:val="18" /></w:rPr><w:t>1</w:t></w:r>'
                  '<w:r><w:rPr><w:sz w:val="18" /></w:rPr><w:fldChar w:fldCharType="end" /></w:r></w:p></w:hdr>')
    vacio = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr {_W}><w:p /></w:hdr>'
    partes["word/header1.xml"] = encabezado.encode("utf-8")
    partes["word/header2.xml"] = vacio.encode("utf-8")
    rels = partes["word/_rels/document.xml.rels"].decode("utf-8")
    tipo = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header"
    rels = rels.replace("</Relationships>", f'<Relationship Type="{tipo}" Id="rIdHdr1" Target="header1.xml" />'
                                             f'<Relationship Type="{tipo}" Id="rIdHdr2" Target="header2.xml" /></Relationships>')
    partes["word/_rels/document.xml.rels"] = rels.encode("utf-8")
    tipos = partes["[Content_Types].xml"].decode("utf-8")
    ct = "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"
    tipos = tipos.replace("</Types>", f'<Override PartName="/word/header1.xml" ContentType="{ct}" />'
                                      f'<Override PartName="/word/header2.xml" ContentType="{ct}" /></Types>')
    partes["[Content_Types].xml"] = tipos.encode("utf-8")
    documento = partes["word/document.xml"].decode("utf-8")
    seccion = ('<w:sectPr><w:headerReference w:type="default" r:id="rIdHdr1" /><w:headerReference w:type="first" r:id="rIdHdr2" />'
               '<w:pgSz w:w="11906" w:h="16838" /><w:pgMar w:top="1418" w:right="1418" w:bottom="1418" w:left="1418" '
               'w:header="709" w:footer="709" w:gutter="0" /><w:titlePg /></w:sectPr>')
    documento = documento.replace("<w:sectPr />", seccion)
    if 'xmlns:r="' not in documento[:600]:
        documento = documento.replace("<w:document ", '<w:document xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ', 1)
    partes["word/document.xml"] = documento.encode("utf-8")
    destino.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED) as z:
        for nombre, contenido in partes.items():
            z.writestr(nombre, contenido)
    return destino


# ----------------------------------------------------------------- conversiones
def _importar_uno():
    """Importa el puente de Python de LibreOffice (paquete python3-uno en Linux)."""
    import sys
    try:
        import uno
        return uno
    except ImportError:
        pass
    for ruta in ("/usr/lib/python3/dist-packages", "/usr/lib/libreoffice/program", "/opt/libreoffice/program"):
        if Path(ruta, "uno.py").exists() and ruta not in sys.path:
            sys.path.append(ruta)
            try:
                import uno
                return uno
            except ImportError:
                sys.path.remove(ruta)
    return None


def exportar_pdf_con_indice(docx: Path, pdf: Path) -> None:
    """Abre el DOCX con LibreOffice (UNO), actualiza el índice y exporta a PDF."""
    programa = shutil.which("soffice") or shutil.which("libreoffice")
    if not programa:
        raise RuntimeError("LibreOffice no está instalado: abra el DOCX en Word, actualice el índice y guárdelo como PDF.")
    uno = _importar_uno()
    if uno is None:
        # Sin el puente de Python de LibreOffice: conversión simple (el índice queda por actualizar).
        subprocess.run([programa, "--headless", "--convert-to", "pdf", "--outdir", str(pdf.parent), str(docx)], check=True,
                       stdout=subprocess.DEVNULL)
        (pdf.parent / (docx.stem + ".pdf")).replace(pdf)
        print("  Aviso: sin el módulo 'uno' el índice del PDF no se actualiza; abra el DOCX en Word, "
              "actualice los campos (F9) y guarde como PDF.")
        return
    from com.sun.star.beans import PropertyValue

    def prop(nombre, valor):
        p = PropertyValue()
        p.Name, p.Value = nombre, valor
        return p

    tubo = f"informe_{int(time.time())}"
    perfil = Path(tempfile.mkdtemp()) / "perfil"
    proceso = subprocess.Popen([programa, "--headless", "--invisible", "--norestore", "--nologo",
                                f"-env:UserInstallation=file://{perfil}", f"--accept=pipe,name={tubo};urp;"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        local = uno.getComponentContext()
        resolver = local.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local)
        for _ in range(60):
            try:
                contexto = resolver.resolve(f"uno:pipe,name={tubo};urp;StarOffice.ComponentContext")
                break
            except Exception:
                time.sleep(0.5)
        else:
            raise RuntimeError("No se pudo conectar con LibreOffice.")
        escritorio = contexto.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", contexto)
        doc = escritorio.loadComponentFromURL(uno.systemPathToFileUrl(str(docx.resolve())), "_blank", 0, (prop("Hidden", True),))
        indices = doc.getDocumentIndexes()
        for i in range(indices.getCount()):
            indices.getByIndex(i).update()
        doc.refresh()
        for i in range(indices.getCount()):      # segunda pasada: los números de página ya incluyen el índice
            indices.getByIndex(i).update()
        doc.storeToURL(uno.systemPathToFileUrl(str(pdf.resolve())), (prop("FilterName", "writer_pdf_Export"),))
        doc.close(True)
    finally:
        try:
            escritorio.terminate()
        except Exception:
            pass
        proceso.terminate()
        proceso.wait(timeout=30)


def _posprocesar_docx(ruta: Path) -> None:
    """Asigna a los párrafos de las celdas el estilo «CompactTabla» (9 pt) sin afectar a las listas."""
    with zipfile.ZipFile(ruta) as z:
        partes = {n: z.read(n) for n in z.namelist()}
    documento = partes["word/document.xml"].decode("utf-8")
    documento = re.sub(r"<w:tbl>.*?</w:tbl>",
                       lambda m: m.group(0).replace('<w:pStyle w:val="Compact" />', '<w:pStyle w:val="CompactTabla" />'),
                       documento, flags=re.S)
    partes["word/document.xml"] = documento.encode("utf-8")
    with zipfile.ZipFile(ruta, "w", zipfile.ZIP_DEFLATED) as z:
        for nombre, contenido in partes.items():
            z.writestr(nombre, contenido)


def construir_informe(pdf: bool = True, eco=print) -> dict:
    if not shutil.which("pandoc"):
        raise RuntimeError("pandoc no está instalado (https://pandoc.org/installing.html).")
    texto, tablas, figuras = preparar_markdown()
    construir_plantilla()
    intermedio = DIR_INFORME / "informe_generado.md"
    intermedio.write_text(texto, encoding="utf-8")
    subprocess.run(["pandoc", str(intermedio), "-f", "markdown", "-t", "docx", "-o", str(SALIDA_DOCX),
                    f"--reference-doc={PLANTILLA}", f"--resource-path={DIR_INFORME}", "--metadata", "lang=es-PE"],
                   check=True)
    _posprocesar_docx(SALIDA_DOCX)
    eco(f"  {SALIDA_DOCX.relative_to(RAIZ_PROYECTO)}: {len(tablas)} tablas, {len(figuras)} figuras")
    for i, f in enumerate(figuras, 1):
        eco(f"    Figura {i}: {f[:70]}")
    if pdf:
        exportar_pdf_con_indice(SALIDA_DOCX, SALIDA_PDF)
        eco(f"  {SALIDA_PDF.relative_to(RAIZ_PROYECTO)}")
    return {"docx": str(SALIDA_DOCX), "pdf": str(SALIDA_PDF) if pdf else None, "tablas": tablas, "figuras": figuras}
