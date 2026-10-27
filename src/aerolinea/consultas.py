"""Catálogo de consultas: ejecución parametrizada, exportación CSV y documentación.

Cada consulta vive en sql/consultas/Qxx_nombre.sql y se ejecuta tal cual en SSMS.
Las líneas marcadas con "-- @param" declaran parámetros con un valor por omisión:

    DECLARE @fecha_desde DATE = '2026-09-01';   -- @param

Desde Python, el valor literal se sustituye por un marcador "?" y el valor se
envía como parámetro enlazado (pyodbc). La entrada del usuario nunca se
concatena en el texto SQL.
"""
from __future__ import annotations

import hashlib
import json
import re
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from .config import RAIZ_PROYECTO, ConfigBD
from .db import conectar, consumir_resultados, dataframe, traducir_error

DIR_CONSULTAS = RAIZ_PROYECTO / "sql" / "consultas"
DIR_RESULTADOS = RAIZ_PROYECTO / "reports" / "resultados"
DOC_CATALOGO = RAIZ_PROYECTO / "docs" / "07_consultas" / "catalogo_consultas.md"
DOC_INTERPRETACIONES = RAIZ_PROYECTO / "docs" / "07_consultas" / "interpretaciones.md"

_PARAM = re.compile(r"^(?P<prefijo>\s*DECLARE\s+@(?P<nombre>\w+)\s+(?P<tipo>[^=]+?)\s*=\s*)(?P<valor>.+?)(?P<sufijo>;\s*--\s*@param\s*)$",
                    re.IGNORECASE | re.MULTILINE)
_CAMPO = re.compile(r"^\s*(Pregunta|Utilidad|Granularidad|Filtros|Fórmulas?|Técnicas)\s*:\s*(.*)$")
_TITULO = re.compile(r"^\s*(Q\d{2})\s*·\s*(.+?)\s*$")


@dataclass
class Consulta:
    id: str
    titulo: str
    ruta: Path
    texto: str
    campos: dict[str, str] = field(default_factory=dict)
    parametros: dict[str, tuple[str, object]] = field(default_factory=dict)   # nombre -> (tipo, valor por omisión)

    @property
    def sha256(self) -> str:
        return hashlib.sha256(self.texto.encode("utf-8")).hexdigest()

    def sql_parametrizado(self) -> str:
        return _PARAM.sub(lambda m: f"{m.group('prefijo')}?{m.group('sufijo')}", self.texto)


def _literal(texto: str):
    texto = texto.strip()
    if texto.upper() == "NULL":
        return None
    if texto.startswith(("'", "N'")):
        return texto[texto.index("'") + 1:-1].replace("''", "'")
    try:
        return int(texto)
    except ValueError:
        return texto


def leer_consulta(ruta: Path) -> Consulta:
    texto = ruta.read_text(encoding="utf-8")
    cabecera = texto.split("*/", 1)[0]
    consulta = Consulta(id=ruta.stem[:3], titulo=ruta.stem, ruta=ruta, texto=texto)
    actual = None
    for linea in cabecera.splitlines():
        if (m := _TITULO.match(linea)):
            consulta.id, consulta.titulo = m.group(1), m.group(2)
        elif (m := _CAMPO.match(linea)):
            actual = m.group(1).replace("Fórmula", "Fórmulas").replace("Fórmulass", "Fórmulas")
            consulta.campos[actual] = m.group(2).strip()
        elif actual and linea.strip() and not linea.strip().startswith("="):
            consulta.campos[actual] += " " + linea.strip()
    for m in _PARAM.finditer(texto):
        consulta.parametros[m.group("nombre")] = (m.group("tipo").strip(), _literal(m.group("valor")))
    return consulta


def catalogo() -> list[Consulta]:
    return [leer_consulta(r) for r in sorted(DIR_CONSULTAS.glob("Q*.sql"))]


def ejecutar_consulta(conexion, consulta: Consulta, valores: dict[str, object] | None = None):
    valores = valores or {}
    argumentos = [valores.get(n, defecto) for n, (_, defecto) in consulta.parametros.items()]
    cursor = conexion.cursor()
    inicio = time.perf_counter()
    try:
        cursor.execute(consulta.sql_parametrizado(), *argumentos)
    except Exception as exc:   # pyodbc.Error
        raise traducir_error(exc) from None
    conjuntos = consumir_resultados(cursor)
    duracion_ms = round((time.perf_counter() - inicio) * 1000)
    columnas, filas = conjuntos[-1]
    usados = {n: v for n, v in zip(consulta.parametros, argumentos)}
    return dataframe(columnas, filas), usados, duracion_ms


def ejecutar_catalogo(cfg: ConfigBD, ids: list[str] | None = None, parametros: dict[str, str] | None = None,
                      salida: Path | None = None, eco=print) -> dict:
    from .despliegue import informacion_entorno
    salida = salida or DIR_RESULTADOS
    salida.mkdir(parents=True, exist_ok=True)
    entorno = informacion_entorno(cfg)
    manifiesto = {"servidor": entorno["servidor"], "version": entorno["version"], "edicion": entorno["edicion"],
                  "base_datos": entorno["base_datos"], "ejecutado_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                  "consultas": {}}
    resultados = {}
    with conectar(cfg, autocommit=True) as conexion:
        for consulta in catalogo():
            if ids and consulta.id not in ids:
                continue
            valores = {k: v for k, v in (parametros or {}).items() if k in consulta.parametros}
            df, usados, ms = ejecutar_consulta(conexion, consulta, valores)
            archivo = salida / f"{consulta.ruta.stem}.csv"
            df.to_csv(archivo, index=False, encoding="utf-8")
            resultados[consulta.id] = df
            manifiesto["consultas"][consulta.id] = {
                "titulo": consulta.titulo, "sql": str(consulta.ruta.relative_to(RAIZ_PROYECTO)), "sha256_sql": consulta.sha256,
                "parametros": {k: (str(v) if v is not None else None) for k, v in usados.items()},
                "filas": len(df), "columnas": list(df.columns), "duracion_ms": ms,
                "csv": str(archivo.relative_to(RAIZ_PROYECTO)) if archivo.is_relative_to(RAIZ_PROYECTO) else str(archivo)}
            eco(f"  {consulta.id} {consulta.titulo:<60} {len(df):>5} filas {ms:>6} ms")
    (salida / "manifiesto_consultas.json").write_text(json.dumps(manifiesto, indent=2, ensure_ascii=False), encoding="utf-8")
    if not ids and salida == DIR_RESULTADOS:
        escribir_catalogo(resultados, manifiesto)
    return manifiesto


def _tabla_markdown(df, max_filas: int = 15) -> str:
    if df.empty:
        return "_(sin filas)_"
    vista = df.head(max_filas)
    encabezado = "| " + " | ".join(str(c) for c in vista.columns) + " |"
    separador = "|" + "|".join("---" for _ in vista.columns) + "|"
    filas = ["| " + " | ".join("" if v is None or (isinstance(v, float) and v != v) else str(v) for v in fila) + " |"
             for fila in vista.itertuples(index=False)]
    nota = f"\n\n_Se muestran {len(vista)} de {len(df)} filas; el resultado completo está en el CSV._" if len(df) > max_filas else ""
    return "\n".join([encabezado, separador, *filas]) + nota


def _interpretaciones() -> dict[str, str]:
    if not DOC_INTERPRETACIONES.is_file():
        return {}
    bloques = re.split(r"^## (Q\d{2})\s*$", DOC_INTERPRETACIONES.read_text(encoding="utf-8"), flags=re.MULTILINE)
    return {bloques[i]: bloques[i + 1].strip() for i in range(1, len(bloques) - 1, 2)}


def escribir_catalogo(resultados: dict, manifiesto: dict) -> Path:
    interpretaciones = _interpretaciones()
    partes = ["# Catálogo de consultas", "",
              "Documento generado por `python -m aerolinea consultas` a partir de `sql/consultas/*.sql` y de los "
              "resultados guardados en `reports/resultados/`. No editar a mano: las interpretaciones se mantienen en "
              "`docs/07_consultas/interpretaciones.md`.", "",
              f"Ejecución: {manifiesto['ejecutado_utc']} · servidor `{manifiesto['servidor']}` · "
              f"{manifiesto['edicion']} {manifiesto['version']} · base `{manifiesto['base_datos']}`.", "",
              "Los datos son sintéticos: las cifras ilustran el funcionamiento del modelo y no describen un mercado real.", ""]
    for consulta in catalogo():
        if consulta.id not in resultados:
            continue
        datos = manifiesto["consultas"][consulta.id]
        partes += [f"## {consulta.id} · {consulta.titulo}", ""]
        for clave in ("Pregunta", "Utilidad", "Granularidad", "Filtros", "Fórmulas", "Técnicas"):
            if clave in consulta.campos:
                partes.append(f"- **{clave}:** {consulta.campos[clave]}")
        parametros = ", ".join(f"`@{k}` = {v}" for k, v in datos["parametros"].items()) or "ninguno"
        partes += [f"- **Parámetros usados:** {parametros}",
                   f"- **Archivos:** `{datos['sql']}` → `{datos['csv']}` ({datos['filas']} filas, {datos['duracion_ms']} ms)", "",
                   "<details><summary>SQL</summary>", "", "```sql", consulta.texto.strip(), "```", "", "</details>", "",
                   "**Resultado ejecutado**", "", _tabla_markdown(resultados[consulta.id]), "",
                   "**Interpretación**", "", interpretaciones.get(consulta.id, "_Pendiente de redactar._"), ""]
    DOC_CATALOGO.parent.mkdir(parents=True, exist_ok=True)
    DOC_CATALOGO.write_text("\n".join(partes), encoding="utf-8")
    return DOC_CATALOGO
