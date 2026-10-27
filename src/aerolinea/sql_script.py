"""Ejecución de scripts T-SQL con separadores GO.

GO no es una sentencia T-SQL: es un separador de lotes que interpretan las
herramientas cliente (SSMS, sqlcmd). Enviarlo al motor produce un error de
sintaxis. Este módulo divide el script en lotes en el cliente, respetando
comentarios de bloque (que en T-SQL pueden anidarse) y literales de texto, y
envía cada lote por separado, como hace SSMS.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import pyodbc

from .db import ErrorBaseDatos, consumir_resultados, traducir_error

_PATRON_GO = re.compile(r"^\s*GO(?:\s+(\d+))?\s*(?:--.*)?$", re.IGNORECASE)


@dataclass
class Lote:
    texto: str
    linea_inicio: int
    repeticiones: int = 1


@dataclass
class ResultadoScript:
    ruta: str
    lotes: int = 0
    mensajes: list[str] = field(default_factory=list)
    conjuntos: list[tuple[list[str], list[tuple]]] = field(default_factory=list)


def dividir_lotes(texto: str) -> list[Lote]:
    lotes: list[Lote] = []
    actual: list[str] = []
    inicio = 1
    profundidad_comentario = 0
    en_texto = False

    for numero, linea in enumerate(texto.splitlines(), start=1):
        if profundidad_comentario == 0 and not en_texto:
            coincidencia = _PATRON_GO.match(linea)
            if coincidencia:
                cuerpo = "\n".join(actual).strip()
                if cuerpo:
                    lotes.append(Lote(cuerpo, inicio, int(coincidencia.group(1) or 1)))
                actual, inicio = [], numero + 1
                continue
        actual.append(linea)
        profundidad_comentario, en_texto = _analizar_linea(linea, profundidad_comentario, en_texto)

    cuerpo = "\n".join(actual).strip()
    if cuerpo:
        lotes.append(Lote(cuerpo, inicio))
    return lotes


def _analizar_linea(linea: str, profundidad: int, en_texto: bool) -> tuple[int, bool]:
    """Actualiza el estado léxico (comentario de bloque / literal) al final de la línea."""
    i, n = 0, len(linea)
    while i < n:
        par = linea[i:i + 2]
        if en_texto:
            if linea[i] == "'":
                if i + 1 < n and linea[i + 1] == "'":
                    i += 2
                    continue
                en_texto = False
        elif profundidad > 0:
            if par == "/*":
                profundidad += 1
                i += 2
                continue
            if par == "*/":
                profundidad -= 1
                i += 2
                continue
        else:
            if par == "--":
                break
            if par == "/*":
                profundidad += 1
                i += 2
                continue
            if linea[i] == "'":
                en_texto = True
        i += 1
    return profundidad, en_texto


def ejecutar_script(conexion: pyodbc.Connection, ruta: str | Path, eco=None) -> ResultadoScript:
    """Ejecuta un archivo .sql lote a lote en una conexión en modo autocommit.

    Un error detiene el script e informa el archivo y la línea del lote.
    """
    ruta = Path(ruta)
    resultado = ResultadoScript(str(ruta))
    cursor = conexion.cursor()
    for lote in dividir_lotes(ruta.read_text(encoding="utf-8-sig")):
        for _ in range(lote.repeticiones):
            try:
                cursor.execute(lote.texto)
                resultado.conjuntos.extend(consumir_resultados(cursor))
            except (pyodbc.Error, ErrorBaseDatos) as exc:
                error = traducir_error(exc) if isinstance(exc, pyodbc.Error) else exc
                raise ErrorBaseDatos(error.numero,
                                     f"{ruta.name}, lote que inicia en la línea {lote.linea_inicio}: {error.mensaje}",
                                     exc) from None
            finally:
                for _, mensaje in getattr(cursor, "messages", None) or []:
                    texto = re.sub(r"^\[[^\]]*\]\[[^\]]*\]\[[^\]]*\]", "", str(mensaje)).strip()
                    resultado.mensajes.append(texto)
                    if eco:
                        eco(texto)
            resultado.lotes += 1
    cursor.close()
    return resultado
