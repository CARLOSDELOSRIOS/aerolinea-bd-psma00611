"""Exportación de diagramas entidad-relación a Graphviz.

Los diagramas se mantienen en Mermaid (`docs/**/diagramas/*.mmd`): son texto, GitHub los
muestra y se editan fácilmente. Mermaid, sin embargo, reparte las entidades en un
lienzo muy ancho y en papel el texto queda ilegible. Este módulo lee el mismo `.mmd`,
lo traduce a DOT con notación de pata de gallo y lo exporta con Graphviz (`dot`) a PNG,
SVG y PDF compactos. El `.dot` generado también se guarda (editable).
"""
from __future__ import annotations

import html
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

LADO_IZQUIERDO = {"||": "teetee", "|o": "teeodot", "}o": "crowodot", "}|": "crowtee"}
LADO_DERECHO = {"||": "teetee", "o|": "teeodot", "o{": "crowodot", "|{": "crowtee"}
_REL = re.compile(r'^\s*(\w+)\s+(\|\||\|o|\}o|\}\|)(--|\.\.)(\|\||o\||o\{|\|\{)\s+(\w+)\s*:\s*"?([^"]*)"?\s*$')
_ATR = re.compile(r'^\s*(\S+)\s+(\w+)(?:\s+([A-Z,]+))?(?:\s+"([^"]*)")?\s*$')

COLOR_ENCABEZADO = "#256abf"
COLOR_BORDE = "#52514e"
COLOR_CLAVE = "#eef3fa"
FUENTE = "Liberation Sans"


@dataclass
class Atributo:
    tipo: str
    nombre: str
    claves: str = ""
    nota: str = ""


@dataclass
class Entidad:
    nombre: str
    atributos: list[Atributo] = field(default_factory=list)


@dataclass
class Relacion:
    izquierda: str
    marca_izquierda: str
    derecha: str
    marca_derecha: str
    etiqueta: str
    discontinua: bool


def leer_mermaid(ruta: Path) -> tuple[str, dict[str, Entidad], list[Relacion]]:
    titulo, entidades, relaciones = ruta.stem, {}, []
    actual = None
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if linea.startswith("title:"):
            titulo = linea.split(":", 1)[1].strip()
            continue
        if actual is not None:
            if linea.strip() == "}":
                actual = None
            elif (m := _ATR.match(linea)):
                actual.atributos.append(Atributo(m.group(1), m.group(2), m.group(3) or "", m.group(4) or ""))
            continue
        if (m := re.match(r"^\s*(\w+)\s*\{\s*$", linea)):
            actual = entidades.setdefault(m.group(1), Entidad(m.group(1)))
        elif (m := _REL.match(linea)):
            a, mi, guion, md, b, etiqueta = m.groups()
            entidades.setdefault(a, Entidad(a))
            entidades.setdefault(b, Entidad(b))
            relaciones.append(Relacion(a, mi, b, md, etiqueta, guion == ".."))
    return titulo, entidades, relaciones


def _etiqueta_entidad(e: Entidad, con_tipos: bool) -> str:
    nombre = html.escape(e.nombre.replace("_", " ") if not e.atributos else e.nombre)
    if not e.atributos:
        return f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="7" COLOR="{COLOR_BORDE}" BGCOLOR="#ffffff">' \
               f'<TR><TD><B>{nombre}</B></TD></TR></TABLE>>'
    columnas = 3 if con_tipos else 2
    filas = [f'<TR><TD COLSPAN="{columnas}" BGCOLOR="{COLOR_ENCABEZADO}"><FONT COLOR="#ffffff"><B>{nombre}</B></FONT></TD></TR>']
    for a in e.atributos:
        claves = a.claves.replace(",", " ")
        fondo = f' BGCOLOR="{COLOR_CLAVE}"' if "PK" in a.claves else ""
        nombre_attr = f"<B>{html.escape(a.nombre)}</B>" if "PK" in a.claves else html.escape(a.nombre)
        celdas = [f'<TD ALIGN="LEFT"{fondo}><FONT POINT-SIZE="9">{claves}</FONT></TD>' if claves else f'<TD{fondo}></TD>',
                  f'<TD ALIGN="LEFT"{fondo}>{nombre_attr}</TD>']
        if con_tipos:
            celdas.append(f'<TD ALIGN="LEFT"{fondo}><FONT POINT-SIZE="9" COLOR="#52514e">{html.escape(a.tipo)}</FONT></TD>')
        filas.append("<TR>" + "".join(celdas) + "</TR>")
    return f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3" COLOR="{COLOR_BORDE}" BGCOLOR="#ffffff">' \
           + "".join(filas) + "</TABLE>>"


def a_dot(titulo: str, entidades: dict[str, Entidad], relaciones: list[Relacion], direccion: str = "TB",
          con_tipos: bool = True, con_etiquetas: bool = True) -> str:
    lineas = [
        "digraph ER {",
        f'  graph [rankdir={direccion}, nodesep=0.2, ranksep=0.4, splines=true, pad=0.2, fontname="{FUENTE}", '
        f'labelloc=t, fontsize=14, label="{html.escape(titulo)}"];',
        f'  node [shape=plaintext, fontname="{FUENTE}", fontsize=10];',
        f'  edge [fontname="{FUENTE}", fontsize=8.5, color="{COLOR_BORDE}", fontcolor="#52514e", arrowsize=0.9, dir=both];',
    ]
    for e in entidades.values():
        lineas.append(f"  {e.nombre} [label={_etiqueta_entidad(e, con_tipos)}];")
    for r in relaciones:
        estilo = ", style=dashed" if r.discontinua else ""
        etiqueta = f', label=" {html.escape(r.etiqueta)} "' if con_etiquetas else ""
        lineas.append(f'  {r.izquierda} -> {r.derecha} [arrowtail={LADO_IZQUIERDO[r.marca_izquierda]}, '
                      f'arrowhead={LADO_DERECHO[r.marca_derecha]}{etiqueta}{estilo}];')
    lineas.append("}")
    return "\n".join(lineas) + "\n"


def opciones_por_nombre(ruta: Path) -> dict:
    """Conceptual: nombres de relación sin atributos. Lógico: claves y atributos sin tipos genéricos.
    Físico: tipos de SQL Server. En lógico y físico se omiten las etiquetas de las FK (ya se marcan como FK)."""
    if ruta.stem.startswith("conceptual"):
        return {"con_tipos": False, "con_etiquetas": True}
    if ruta.stem.startswith("logico"):
        return {"con_tipos": False, "con_etiquetas": False}
    return {"con_tipos": True, "con_etiquetas": False}


def exportar(ruta_mmd: Path, direccion: str = "TB", con_tipos: bool | None = None, con_etiquetas: bool | None = None,
             formatos=("png", "svg", "pdf"), dpi: int = 200, eco=print) -> list[Path]:
    """Genera <nombre>.dot y las exportaciones junto al .mmd (requiere Graphviz)."""
    if not shutil.which("dot"):
        eco(f"  Graphviz (dot) no está instalado: se omite {ruta_mmd.name}.")
        return []
    opciones = opciones_por_nombre(ruta_mmd)
    if con_tipos is not None:
        opciones["con_tipos"] = con_tipos
    if con_etiquetas is not None:
        opciones["con_etiquetas"] = con_etiquetas
    titulo, entidades, relaciones = leer_mermaid(ruta_mmd)
    dot = ruta_mmd.with_suffix(".dot")
    dot.write_text(a_dot(titulo, entidades, relaciones, direccion, **opciones), encoding="utf-8")
    salidas = []
    for formato in formatos:
        destino = ruta_mmd.with_suffix(f".{formato}")
        extra = [f"-Gdpi={dpi}"] if formato == "png" else []
        subprocess.run(["dot", f"-T{formato}", *extra, str(dot), "-o", str(destino)], check=True)
        salidas.append(destino)
    eco(f"  {ruta_mmd.name} -> .dot, " + ", ".join(f".{f}" for f in formatos) + " (Graphviz)")
    return salidas
