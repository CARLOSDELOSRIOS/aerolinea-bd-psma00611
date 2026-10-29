"""Diagramas y esquemas del documento de avance (reports/avance/figuras/).

Cada diagrama se escribe como fuente Graphviz (.dot) y se exporta a PNG; el
cronograma y la evolución de la tarifa se dibujan con matplotlib. Las cifras
proceden de los resultados guardados (evidence/, reports/resultados/) o de los
datos de referencia (sql/09_datos_referencia.sql); los ejemplos ilustrativos
se rotulan como tales.

Requiere Graphviz (`dot`) para los diagramas; si no está instalado se conservan
los PNG existentes.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from collections import Counter
from datetime import date
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.dates as mdates  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

from .config import RAIZ_PROYECTO  # noqa: E402
from .graficos import SERIE, SUPERFICIE, TEXTO, TEXTO_SECUNDARIO  # noqa: E402

DIR_FIGURAS = RAIZ_PROYECTO / "reports" / "avance" / "figuras"
FUENTE = "Liberation Sans"
AZUL_OSCURO = "#1F3864"
AZUL = "#256ABF"
CELESTE = "#EEF3FA"
BORDE = "#9EB6D8"
# Estados (paleta de estado fija): siempre con símbolo y texto, nunca solo color.
ESTADOS = {
    "completo": ("#0ca30c", "#E7F6E7", "✔ Completo"),
    "curso": ("#B07A00", "#FFF4D6", "◐ En curso"),
    "pendiente": ("#d03b3b", "#FBE9E9", "○ Pendiente"),
}


def _grafo(cuerpo: str, direccion: str = "TB", sep: tuple[float, float] = (0.35, 0.45)) -> str:
    return (f'digraph G {{\n graph [rankdir={direccion}, bgcolor="white", pad=0.25, nodesep={sep[0]}, ranksep={sep[1]}, '
            f'fontname="{FUENTE}", fontsize=11, newrank=true];\n'
            f' node [fontname="{FUENTE}", fontsize=11, shape=box, style="rounded,filled", fillcolor="{CELESTE}", '
            f'color="{BORDE}", fontcolor="{TEXTO}", penwidth=1.2, margin="0.18,0.10"];\n'
            f' edge [fontname="{FUENTE}", fontsize=9.5, color="{TEXTO_SECUNDARIO}", fontcolor="{TEXTO_SECUNDARIO}", arrowsize=0.75];\n'
            f'{cuerpo}\n}}\n')


def _esc(t: str) -> str:
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _caja(titulo: str, lineas: list[str] | None = None, color: str = AZUL_OSCURO, ancho: int = 0) -> str:
    """Etiqueta HTML: título en negrita y líneas de detalle en gris."""
    filas = f'<TR><TD ALIGN="LEFT"><B><FONT COLOR="{color}">{_esc(titulo)}</FONT></B></TD></TR>'
    for linea in lineas or []:
        filas += f'<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">{_esc(linea)}</FONT></TD></TR>'
    w = f' WIDTH="{ancho}"' if ancho else ""
    return f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="1" CELLPADDING="1"{w}>{filas}</TABLE>>'


def _chip(estado: str) -> str:
    borde, fondo, texto = ESTADOS[estado]
    return (f'<TABLE BORDER="1" COLOR="{borde}" CELLBORDER="0" CELLPADDING="3" BGCOLOR="{fondo}" STYLE="rounded">'
            f'<TR><TD><FONT FACE="DejaVu Sans" POINT-SIZE="9" COLOR="{borde}"><B>{texto}</B></FONT></TD></TR></TABLE>')


def _exportar(nombre: str, fuente_dot: str) -> Path:
    DIR_FIGURAS.mkdir(parents=True, exist_ok=True)
    ruta_dot = DIR_FIGURAS / f"{nombre}.dot"
    ruta_png = DIR_FIGURAS / f"{nombre}.png"
    ruta_dot.write_text(fuente_dot, encoding="utf-8")
    dot = shutil.which("dot")
    if dot:
        subprocess.run([dot, "-Tpng", "-Gdpi=200", "-o", str(ruta_png), str(ruta_dot)], check=True)
    elif not ruta_png.exists():
        raise RuntimeError("Graphviz no está instalado (https://graphviz.org/download/) y falta " + ruta_png.name)
    return ruta_png


# ------------------------------------------------------------------ diagramas
def encargo() -> Path:
    cuerpo = f"""
 pac [label=<<B><FONT COLOR="white">Producto Académico Colaborativo</FONT></B><BR/><FONT COLOR="white" POINT-SIZE="9.5">Base de datos en la nube para una aerolínea</FONT>>, fillcolor="{AZUL}", color="{AZUL}"];
 av [label={_caja("Avance · 20 %", ["Registrarse en GitHub", "Crear el equipo y el proyecto", "Subir los scripts"])}];
 po [label={_caja("Presentación oral · 40 %", ["10 a 15 diapositivas", "20 minutos", "Todos exponen (al azar)"])}];
 pf [label={_caja("Producto final · 40 %", ["Informe y base de datos", "Entrega del líder", "16-nov-2026, 23:59"])}];
 pac -> av; pac -> po; pac -> pf;
 subgraph cluster_c {{ label=<<B>Lo que debe contener el producto</B>>; fontcolor="{AZUL_OSCURO}"; style="rounded,dashed"; color="{BORDE}";
  c1 [label="1. Requisitos\\nde la empresa"]; c2 [label="2. Modelo\\nde datos"]; c3 [label="3. Creación\\nde tablas"];
  c4 [label="4. Inserción\\nde datos"]; c5 [label="5. Consultas"]; c6 [label="6. Consultas desde\\nun lenguaje de\\nprogramación"];
  {{rank=same; c1 -> c2 -> c3;}} {{rank=same; c4 -> c5 -> c6;}} c3 -> c4 [constraint=false]; c1 -> c4 [style=invis]; }}
 av -> c1 [style=invis]; pf -> c3 [style=dashed, arrowhead=none];"""
    return _exportar("A01_encargo", _grafo(cuerpo, sep=(0.3, 0.45)))


def estado() -> Path:
    filas = [
        ("Requisitos de la empresa", "42 reglas, 13 supuestos, 13 casos de uso", "completo"),
        ("Modelo de datos", "Conceptual, lógico y físico en 3FN; 269 columnas documentadas", "completo"),
        ("Creación de tablas", "Scripts 01 a 13 probados en el entorno de desarrollo", "completo"),
        ("Inserción de datos", "Catálogos y ≈1,19 millones de filas sintéticas", "completo"),
        ("Consultas", "20 consultas con resultado e interpretación", "completo"),
        ("Consultas desde Python", "pyodbc y pandas, con parámetros enlazados", "completo"),
        ("Repositorio en GitHub", "Proyecto y scripts subidos; falta sumar colaboradores", "curso"),
        ("Ejecución en las laptops", "Guía y script de verificación listos", "pendiente"),
        ("Base de datos en Azure", "Guía y scripts listos; sin desplegar", "pendiente"),
    ]
    html = (f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0" CELLPADDING="7">'
            f'<TR><TD ALIGN="LEFT" BGCOLOR="{AZUL}"><B><FONT COLOR="white">Componente</FONT></B></TD>'
            f'<TD ALIGN="LEFT" BGCOLOR="{AZUL}"><B><FONT COLOR="white">Qué tenemos</FONT></B></TD>'
            f'<TD BGCOLOR="{AZUL}"><B><FONT COLOR="white">Estado</FONT></B></TD></TR>')
    for i, (componente, detalle, est) in enumerate(filas):
        fondo = "white" if i % 2 else "#F6F8FC"
        html += (f'<TR><TD ALIGN="LEFT" BGCOLOR="{fondo}"><B>{_esc(componente)}</B></TD>'
                 f'<TD ALIGN="LEFT" BGCOLOR="{fondo}"><FONT COLOR="{TEXTO_SECUNDARIO}">{_esc(detalle)}</FONT></TD>'
                 f'<TD BGCOLOR="{fondo}">{_chip(est)}</TD></TR>')
    html += "</TABLE>>"
    cuerpo = f' t [shape=plain, style="", label={html}];'
    return _exportar("A02_estado", _grafo(cuerpo))


def objetivos() -> Path:
    oes = [("OE1 · Requisitos", "Reglas verificables", "completo"),
           ("OE2 · Modelo", "3FN y desnormalizaciones justificadas", "completo"),
           ("OE3 · Integridad", "Reglas en el motor, también con concurrencia", "completo"),
           ("OE4 · Datos y consultas", "Datos reproducibles y 20 consultas", "completo"),
           ("OE5 · Validación y nube", "Pruebas hechas; Azure por desplegar", "curso")]
    cuerpo = (f' og [label=<<B><FONT COLOR="white">Objetivo general</FONT></B><BR/><FONT COLOR="white" POINT-SIZE="9.5">'
              f'Diseñar, implementar y validar<BR/>la base de datos de la aerolínea,<BR/>desplegable en SQL Server y<BR/>Azure SQL Database, '
              f'con<BR/>consultas desde Python</FONT>>, fillcolor="{AZUL}", color="{AZUL}"];\n')
    for i, (titulo, detalle, est) in enumerate(oes, 1):
        etiqueta = (f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="2"><TR><TD ALIGN="LEFT"><B><FONT COLOR="{AZUL_OSCURO}">{_esc(titulo)}</FONT></B></TD>'
                    f'<TD ROWSPAN="2" WIDTH="120">{_chip(est)}</TD></TR>'
                    f'<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">{_esc(detalle)}</FONT></TD></TR></TABLE>>')
        cuerpo += f' oe{i} [label={etiqueta}, fillcolor="white"];\n og -> oe{i};\n'
    return _exportar("A03_objetivos", _grafo(cuerpo, direccion="LR", sep=(0.12, 0.6)))


def personas() -> Path:
    cuerpo = f'''
 persona [label={_caja("PERSONA  (ven.persona)", ["Toda persona que compra o viaja", "Nombre, documento, contacto"])}, fillcolor="white", color="{AZUL}", penwidth=2];
 comprador [label={_caja("Comprador", ["Paga la compra (ven.compra)", "Puede no tener cuenta"])}];
 pasajero [label={_caja("Pasajero", ["Viaja con un tiquete (ven.tiquete)"])}];
 cliente [label={_caja("Cliente registrado  (ven.cliente)", ["Persona con cuenta: n.º de viajero,", "correo de acceso, nivel de lealtad"])}];
 persona -> comprador [label=" rol"]; persona -> pasajero [label=" rol"]; persona -> cliente [label=" subtipo 1 : 0..1"];
 ej [shape=note, fillcolor="#FFFDF5", color="#D9C9A3", label={_caja("Ejemplo ilustrativo", ["Ana compra dos tiquetes sin registrarse: uno para ella y otro para su hijo.", "Ana = persona + compradora + pasajera.  Su hijo = persona + pasajero.", "Si Ana crea una cuenta, además es cliente registrada; no se duplica nada."], color="#7A5C00")}];
 {{rank=same; comprador; pasajero; cliente;}}
 pasajero -> ej [style=invis];'''
    return _exportar("A04_personas", _grafo(cuerpo, sep=(0.3, 0.5)))


def ruta_vuelo() -> Path:
    cuerpo = f"""
 ruta [label={_caja("Ruta  JFK → LAX", ["Par origen-destino (ops.ruta)", "Nueva York → Los Ángeles"])}];
 prog [label={_caja("Programación  XX101", ["Sale 07:00, hora de Nueva York", "Todos los días · 370 min", "Vigente desde el 1-sep-2026"])}];
 v1 [label={_caja("Vuelo XX101", ["2-nov-2026", "avión, tripulación, estado"])}, fillcolor="white"];
 v2 [label={_caja("Vuelo XX101", ["3-nov-2026"])}, fillcolor="white"];
 v3 [label={_caja("Vuelo XX101", ["4-nov-2026"])}, fillcolor="white"];
 vn [label="…", shape=plaintext, style=""];
 ruta -> prog [label=" se opera con"];
 prog -> v1; prog -> v2 [label=" genera (ops.usp_generar_vuelos)"]; prog -> v3; prog -> vn [style=dashed];
 nota [shape=note, fillcolor="#FFFDF5", color="#D9C9A3", label={_caja("Un horario puede cambiar sin tocar el pasado", ["XX703 ATL → MIA sale a las 16:00 hasta el 30-nov-2026", "y a las 16:30 desde el 1-dic-2026: dos vigencias", "del mismo número de vuelo."], color="#7A5C00")}];
 {{rank=same; prog; nota;}} prog -> nota [style=dotted, arrowhead=none];"""
    return _exportar("A05_ruta_vuelo", _grafo(cuerpo, sep=(0.3, 0.5)))


def precio_historico() -> Path:
    """Tarifa JFK-LAX económica por versión (sql/09) y un tiquete comprado durante la versión 1."""
    DIR_FIGURAS.mkdir(parents=True, exist_ok=True)
    tramos = [(date(2026, 7, 1), date(2026, 9, 16), 308.99), (date(2026, 9, 16), date(2026, 10, 20), 333.99),
              (date(2026, 10, 20), date(2026, 11, 16), 354.99)]
    fig, ax = plt.subplots(figsize=(8.6, 3.6))
    for i, (desde, hasta, precio) in enumerate(tramos, 1):
        ax.plot([desde, hasta], [precio, precio], color=SERIE[0], linewidth=2.2, solid_capstyle="round")
        ax.text(desde + (hasta - desde) / 2, precio + 5, f"Versión {i}: {precio:.2f}".replace(".", ","),
                ha="center", fontsize=9, color=TEXTO_SECUNDARIO)
    venta = date(2026, 9, 10)
    ax.plot([venta, date(2026, 11, 16)], [308.99, 308.99], color=SERIE[1], linewidth=1.6, linestyle=(0, (4, 3)))
    ax.plot([venta], [308.99], marker="o", markersize=8, color=SERIE[1], markeredgecolor=SUPERFICIE, markeredgewidth=2, zorder=5)
    ax.annotate("Tiquete comprado el 10-sep:\nconserva 308,99 USD aunque la tarifa suba",
                xy=(venta, 308.99), xytext=(date(2026, 7, 8), 278), fontsize=9, color=TEXTO,
                arrowprops=dict(arrowstyle="-", color=TEXTO_SECUNDARIO, linewidth=0.8))
    ax.set_ylim(260, 375)
    ax.set_ylabel("USD")
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    meses = {7: "jul", 8: "ago", 9: "sep", 10: "oct", 11: "nov"}
    ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: meses.get(mdates.num2date(x).month, "")))
    ax.set_title("Tarifa JFK → LAX en económica y precio guardado en un tiquete", loc="left", fontsize=11, color=TEXTO)
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    ax.grid(axis="x", visible=False)
    fig.tight_layout()
    ruta = DIR_FIGURAS / "A06_precio_historico.png"
    fig.savefig(ruta, dpi=200)
    plt.close(fig)
    return ruta


def normalizacion() -> Path:
    cuerpo = f"""
 p0 [label={_caja("Punto de partida: una planilla de ventas", ["Pagos y reembolsos como listas", "Horario repetido en cada fila", "Comprador y pasajero mezclados"], color="#A33333")}, fillcolor="#FBE9E9", color="#E5B5B5"];
 p1 [label={_caja("1FN · valores atómicos", ["Pagos, reembolsos y días de operación", "pasan a tablas propias"])}];
 p2 [label={_caja("2FN · sin dependencias parciales", ["Cada dato depende de toda la clave:", "el nombre del tripulante vive en", "rh.empleado, no en la asignación"])}];
 p3 [label={_caja("3FN · sin dependencias transitivas", ["tiquete → vuelo → programación", "→ ruta → aeropuerto, cada uno", "en su propia tabla"])}, fillcolor="#E7F6E7", color="#9FD49F"];
 {{rank=same; p0 -> p1;}} {{rank=same; p2 -> p3;}} p1 -> p2; p0 -> p2 [style=invis];
 r [shape=note, fillcolor="#FFFDF5", color="#D9C9A3", label={_caja("6 redundancias controladas", ["La principal: el tiquete guarda su precio de venta.", "Un trigger comprueba la copia y la vuelve inmutable."], color="#7A5C00")}];
 p3 -> r [style=dashed, arrowhead=none];"""
    return _exportar("A07_normalizacion", _grafo(cuerpo, sep=(0.5, 0.45)))


def integridad() -> Path:
    capas = [("1. Restricciones declarativas", "70 CHECK · 53 claves foráneas · 29 UNIQUE · 6 índices únicos filtrados", "#DCE8F7"),
             ("2. Triggers", "12 triggers: estados, solapes de avión y tripulación, inventario, precio inmutable", "#E6EEF9"),
             ("3. Procedimientos almacenados", "16 procedimientos: emitir, pagar, cancelar, generar vuelos", "#EFF4FB"),
             ("4. Controles por consulta", "Conciliación de inventario y de caja (Q19)", "#F7F9FD")]
    html = '<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="4" CELLPADDING="8" COLOR="#9EB6D8">'
    for titulo, detalle, fondo in capas:
        html += (f'<TR><TD ALIGN="LEFT" BALIGN="LEFT" BGCOLOR="{fondo}" WIDTH="430"><B><FONT COLOR="{AZUL_OSCURO}">{_esc(titulo)}</FONT></B><BR ALIGN="LEFT"/>'
                 f'<FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">{_esc(detalle)}</FONT></TD></TR>')
    html += "</TABLE>>"
    cuerpo = f"""
 entra [label="Dato que llega (aplicación, SSMS o carga masiva)", fillcolor="white"];
 capas [shape=plain, style="", label={html}];
 tabla [label={_caja("Tablas", ["Solo guardan datos que", "cumplen las 42 reglas"])}, fillcolor="#E7F6E7", color="#9FD49F"];
 rechazo [label={_caja("Rechazado", ["Mensaje de negocio", "(errores 50000 en adelante)"], color="#A33333")}, fillcolor="#FBE9E9", color="#E5B5B5"];
 entra -> capas; capas -> tabla [label=" cumple"]; capas -> rechazo [style=dashed, label=" viola una regla"];"""
    return _exportar("A08_integridad", _grafo(cuerpo, sep=(0.8, 0.4)))


def scripts() -> Path:
    filas = [[("s00", "00", "Verificar\nel entorno"), ("s01", "01", "Crear la base\n(solo local)"), ("s02", "02–04", "Tablas, claves\ne índices"), ("s05", "05", "Funciones\ny triggers")],
             [("s06", "06–07", "Vistas y\nprocedimientos"), ("s08", "08", "Seguridad"), ("s09", "09", "Datos de\nreferencia"), ("s10", "10", "Área de carga")],
             [("py", "Python", "Datos sintéticos\n(semilla fija)"), ("s12", "12–13", "Pruebas y\ndescripciones"), ("q", "Q01–Q20", "Consultas")]]
    cuerpo = ""
    for fila in filas:
        for nodo, num, texto in fila:
            color = ('fillcolor="#FFF4D6", color="#E3C77A"' if nodo == "py" else
                     'fillcolor="#E7F6E7", color="#9FD49F"' if nodo == "q" else "")
            cuerpo += f' {nodo} [label=<<B>{_esc(num)}</B><BR/><FONT POINT-SIZE="9.5">{_esc(texto).replace(chr(10), "<BR/>")}</FONT>>, width=1.6, {color}];\n'
        cuerpo += " {rank=same; " + " -> ".join(n for n, _, _ in fila) + ";}\n"
    cuerpo += " s05 -> s06 [constraint=false]; s10 -> py [constraint=false]; s00 -> s06 [style=invis]; s06 -> py [style=invis];\n"
    cuerpo += f""" subgraph cluster_x {{ label=<<B>Fuera del despliegue normal</B>>; fontcolor="{AZUL_OSCURO}"; style="rounded,dashed"; color="{BORDE}";
  s11 [label=<<B>11</B><BR/><FONT POINT-SIZE="9.5">Ejemplos de DML<BR/>(simulan por defecto)</FONT>>, fillcolor="white", style="rounded,dashed,filled", width=1.6];
  s99 [label=<<B>99 · DESTRUCTIVO</B><BR/><FONT POINT-SIZE="9.5">Elimina la base local<BR/>exige confirmación</FONT>>, fillcolor="#FBE9E9", color="#d03b3b", style="rounded,dashed,filled", width=1.6];
  {{rank=same; s11; s99;}} s11 -> s99 [style=invis]; }}
 py -> s11 [style=invis];"""
    return _exportar("A09_scripts", _grafo(cuerpo, sep=(0.35, 0.45)))


def aplicacion() -> Path:
    filas = [[("verificar-conexion", "servidor, versión, cifrado"), ("desplegar", "scripts 01 a 13"), ("cargar-datos", "≈1,19 M filas, una transacción")],
             [("pruebas", "PR-01…23 y PC-01…04"), ("consultas", "Q01–Q20 → CSV"), ("graficos", "figuras F01–F08")]]
    cuerpo = f' env [label={_caja(".env", ["Configuración local", "sin contraseñas (Windows)"])}, shape=note, fillcolor="#FFFDF5", color="#D9C9A3"];\n'
    k = 0
    for fila in filas:
        nombres = []
        for cmd, det in fila:
            cuerpo += (f' p{k} [label=<<B><FONT FACE="Liberation Mono">{_esc(cmd)}</FONT></B><BR/><FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">'
                       f'{_esc(det)}</FONT>>, width=2.2];\n')
            nombres.append(f"p{k}")
            k += 1
        cuerpo += " {rank=same; " + " -> ".join(nombres) + ";}\n"
    cuerpo += " p2 -> p3 [constraint=false]; p0 -> p3 [style=invis]; env -> p0 [style=dashed];\n"
    cuerpo += (f' sal [label={_caja("Resultados", ["evidence/  ·  reports/resultados/", "reports/figuras/  ·  informe y avance"])}, fillcolor="#E7F6E7", color="#9FD49F"];'
               f' p5 -> sal [style=dashed]; p3 -> sal [style=invis];\n'
               f' rep [shape=note, fillcolor="white", label=<<B><FONT FACE="Liberation Mono">python -m aerolinea reproducir</FONT></B><BR/>'
               f'<FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">ejecuta todos los pasos con un solo comando</FONT>>];'
               f' {{rank=same; env; rep;}} env -> rep [style=invis];')
    return _exportar("A10_aplicacion", _grafo(cuerpo, sep=(0.35, 0.45)))


def concurrencia() -> Path:
    cuerpo = f"""
 s [label={_caja("40 sesiones a la vez", ["Cada una con su propia conexión", "y una barrera de arranque común"])}];
 l [label={_caja("Fila del cupo bloqueada (UPDLOCK)", ["ops.vuelo_cabina · cabina VIP de 12 asientos", "Las ventas del mismo vuelo pasan de una en una"])}, fillcolor="#FFF4D6", color="#E3C77A"];
 ok [label={_caja("12 ventas confirmadas", ["Plazas ocupadas: 12 de 12"])}, fillcolor="#E7F6E7", color="#9FD49F"];
 no [label={_caja("28 rechazadas", ["Error 50020: sin plazas", "La transacción se revierte entera"], color="#A33333")}, fillcolor="#FBE9E9", color="#E5B5B5"];
 c [shape=note, fillcolor="white", label={_caja("Última barrera", ["CHECK (plazas_ocupadas", "<= capacidad)"])}];
 s -> l; l -> ok; l -> no; {{rank=same; s; c;}} s -> c [style=invis];"""
    return _exportar("A11_concurrencia", _grafo(cuerpo, sep=(0.5, 0.45)))


def pruebas() -> Path:
    datos = json.loads((RAIZ_PROYECTO / "evidence" / "contenedor_linux" / "resultados_pruebas.json").read_text(encoding="utf-8"))
    conteo = Counter()
    for r in datos["pruebas"]:
        conteo[(r["id"][:2], r["resultado"])] += 1
    pr_ok, pr_total = conteo[("PR", "SUPERADA")], sum(v for (k, _), v in conteo.items() if k == "PR")
    pc_ok, pc_total = conteo[("PC", "SUPERADA")], sum(v for (k, _), v in conteo.items() if k == "PC")

    def nodo(nombre, titulo, detalle, est):
        etiqueta = (f'<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="2"><TR><TD><B><FONT COLOR="{AZUL_OSCURO}">{_esc(titulo)}</FONT></B></TD></TR>'
                    f'<TR><TD><FONT POINT-SIZE="9.5" COLOR="{TEXTO_SECUNDARIO}">{_esc(detalle)}</FONT></TD></TR><TR><TD>{_chip(est)}</TD></TR></TABLE>>')
        return f' {nombre} [label={etiqueta}, fillcolor="white", width=2.6];\n'
    cuerpo = (f' subgraph cluster_d {{ label=<<B>Entorno de desarrollo · contenedor con SQL Server 2022</B>>; fontcolor="{AZUL_OSCURO}"; style="rounded"; color="{BORDE}"; bgcolor="#F6F8FC";\n'
              + nodo("a", "Aplicación (pytest)", "23 de 23", "completo")
              + nodo("b", "Reglas de negocio", f"{pr_ok} de {pr_total} (PR)", "completo" if pr_ok == pr_total else "curso")
              + nodo("c", "Concurrencia real", f"{pc_ok} de {pc_total} (PC)", "completo" if pc_ok == pc_total else "curso")
              + nodo("d", "Compatibilidad SQL Server 2016", "27 de 27 con nivel 130", "completo")
              + "  {rank=same; a; b;} {rank=same; c; d;} a -> c [style=invis]; b -> d [style=invis];\n }\n"
              + f' subgraph cluster_r {{ label=<<B>Entornos reales del encargo</B>>; fontcolor="{AZUL_OSCURO}"; style="rounded,dashed"; color="#E5B5B5";\n'
              + nodo("e", "Laptops del equipo", "Windows · SQL Server local", "pendiente")
              + nodo("f", "Azure SQL Database", "Requisito de nube", "pendiente")
              + "  {rank=same; e; f;}\n }\n c -> e [style=dashed, label=\" siguiente paso\"]; d -> f [style=invis];")
    return _exportar("A12_pruebas", _grafo(cuerpo, sep=(0.3, 0.45)))


def cronograma() -> Path:
    """Plan propuesto hasta la entrega final (fechas objetivo, no compromisos ya cumplidos)."""
    DIR_FIGURAS.mkdir(parents=True, exist_ok=True)
    hitos = [("1. Organización del equipo y GitHub", date(2026, 10, 30), date(2026, 11, 2)),
             ("2. Retroalimentación del avance", None, None),
             ("3. Reproducción en las tres laptops", date(2026, 11, 2), date(2026, 11, 6)),
             ("4. Despliegue en Azure", date(2026, 11, 6), date(2026, 11, 10)),
             ("5. Cierre del informe", date(2026, 11, 9), date(2026, 11, 13)),
             ("6. Ensayo de la exposición", None, None),
             ("7. Entrega final (16-nov, 23:59)", date(2026, 11, 16), date(2026, 11, 16))]
    fig, ax = plt.subplots(figsize=(8.6, 3.7))
    for i, (_, ini, fin) in enumerate(hitos):
        if ini is None:
            ax.text(mdates.date2num(date(2026, 10, 30)), i, "fecha por confirmar con el docente", va="center", fontsize=8.5,
                    color=TEXTO_SECUNDARIO, style="italic", bbox=dict(facecolor=SUPERFICIE, edgecolor="none", pad=1))
        elif ini == fin:
            ax.plot([ini], [i], marker="D", markersize=9, color=SERIE[1], zorder=4)
        else:
            ax.barh(i, (fin - ini).days, left=mdates.date2num(ini), height=0.5, color=SERIE[0], edgecolor=SUPERFICIE, linewidth=2)
    hoy = date(2026, 10, 29)
    ax.axvline(mdates.date2num(hoy), color=TEXTO_SECUNDARIO, linestyle=(0, (3, 3)), linewidth=1)
    ax.text(mdates.date2num(hoy), -0.62, " hoy, 29-oct", fontsize=8.5, color=TEXTO_SECUNDARIO, va="center")
    ax.set_yticks(range(len(hitos)), [h[0] for h in hitos], fontsize=9)
    ax.set_ylim(len(hitos) - 0.4, -0.85)
    ax.set_xlim(mdates.date2num(date(2026, 10, 28)), mdates.date2num(date(2026, 11, 18)))
    ax.xaxis.set_major_locator(mdates.DayLocator(bymonthday=[30, 2, 6, 10, 13, 16]))
    ax.xaxis.set_major_formatter(plt.FuncFormatter(
        lambda x, _: f"{mdates.num2date(x).day}-{'oct' if mdates.num2date(x).month == 10 else 'nov'}"))
    ax.set_title("Plan de trabajo propuesto hasta la entrega final", loc="left", fontsize=11, color=TEXTO, pad=10)
    for lado in ("top", "right", "left"):
        ax.spines[lado].set_visible(False)
    ax.grid(axis="y", visible=False)
    ax.tick_params(axis="y", length=0)
    fig.tight_layout()
    ruta = DIR_FIGURAS / "A13_cronograma.png"
    fig.savefig(ruta, dpi=200)
    plt.close(fig)
    return ruta


def riesgos() -> Path:
    pares = [("Sin suscripción de Azure a tiempo", "Pedirla en la primera semana;\nguía y scripts ya listos"),
             ("Diferencias de versión\nen las laptops", "Script de verificación de solo\nlectura antes de reconstruir"),
             ("Cambio de fechas del curso", "Avance adelantado;\nconsulta al docente"),
             ("Aportes que no se ven\nen GitHub", "Cada integrante sube sus\ncambios con su cuenta"),
             ("Costos inesperados\nen la nube", "Oferta gratuita con pausa automática\ny firewall limitado a una IP")]
    cuerpo = (f' tr [shape=plaintext, style="", label=<<B><FONT COLOR="{AZUL_OSCURO}">Riesgo</FONT></B>>];\n'
              f' tm [shape=plaintext, style="", label=<<B><FONT COLOR="{AZUL_OSCURO}">Qué haremos</FONT></B>>];\n tr -> tm [style=invis];\n')
    for i, (r, m) in enumerate(pares):
        r_, m_ = r.replace("\n", "\\n"), m.replace("\n", "\\n")
        cuerpo += (f' r{i} [label="{r_}", fillcolor="#FBE9E9", color="#E5B5B5", width=2.6];\n'
                   f' m{i} [label="{m_}", fillcolor="#E7F6E7", color="#9FD49F", width=3.3];\n r{i} -> m{i};\n')
    cuerpo += " {rank=same; tr; " + "; ".join(f"r{i}" for i in range(len(pares))) + ";}\n"
    cuerpo += " {rank=same; tm; " + "; ".join(f"m{i}" for i in range(len(pares))) + ";}\n"
    cuerpo += " tr -> r0 -> r1 -> r2 -> r3 -> r4 [style=invis]; tm -> m0 -> m1 -> m2 -> m3 -> m4 [style=invis];"
    return _exportar("A14_riesgos", _grafo(cuerpo, direccion="LR", sep=(0.15, 0.7)))


def equipo() -> Path:
    integrantes = ["Carlos Veliz de Villa Aguirre", "Elias Sifuentes Valles", "Carlos De los Ríos De la Roca\\n(líder)"]
    cuerpo = f' subgraph cluster_e {{ label=<<B>Equipo · los tres en todas las etapas</B>>; fontcolor="{AZUL_OSCURO}"; style="rounded"; color="{BORDE}"; bgcolor="#F6F8FC";\n'
    for i, nombre in enumerate(integrantes):
        cuerpo += f'  i{i} [label="{nombre}", fillcolor="white"];\n'
    cuerpo += "  {rank=same; i0; i1; i2;}\n }\n"
    cuerpo += f""" p [label={_caja("1. Redactamos juntos el prompt", ["Qué pedir, con qué reglas", "y qué no se debe inventar"])}];
 c [label={_caja("2. Claude Code genera y ejecuta", ["Archivos, scripts, pruebas", "y documentos"])}, fillcolor="#FFF4D6", color="#E3C77A"];
 r [label={_caja("3. Revisamos juntos el resultado", ["Cifras, decisiones, pendientes"])}];
 g [label={_caja("4. GitHub", ["Repositorio e historial", "de versiones"])}, fillcolor="#E7F6E7", color="#9FD49F"];
 {{rank=same; p -> c;}} {{rank=same; g -> r [dir=back];}} c -> r; p -> g [style=invis];
 r -> p [label=" ajustes", style=dashed, constraint=false];
 i0 -> p; i1 -> p; i2 -> p;
 n [shape=note, fillcolor="white", label={_caja("Evidencia", ["Prompts literales: anexo B", "Historial de cambios: GitHub"])}]; g -> n [style=dashed, arrowhead=none];"""
    return _exportar("A15_equipo", _grafo(cuerpo, sep=(0.5, 0.5)))


def repositorio(archivos: list[str]) -> Path:
    """Árbol de primer nivel del repositorio, con sus subcarpetas y el número de archivos de cada una."""
    descripciones = {"docs": "Documentación del proyecto", "sql": "Scripts T-SQL y consultas", "src": "Aplicación en Python",
                     "tests": "Pruebas (pytest)", "reports": "Resultados, figuras, informe y avance", "slides": "Presentación",
                     "evidence": "Evidencias por entorno", "scripts": "Windows y Azure", "data": "Manifiesto de datos sintéticos"}
    por_carpeta: dict[str, Counter] = {}
    raiz = 0
    for a in archivos:
        partes = a.split("/")
        if len(partes) == 1:
            raiz += 1
        else:
            por_carpeta.setdefault(partes[0], Counter())[partes[1] if len(partes) > 2 else ""] += 1
    cuerpo = (f' r [label=<<B><FONT COLOR="white">aerolinea-bd-psma00611/</FONT></B><BR/><FONT COLOR="white" POINT-SIZE="9.5">'
              f'{len(archivos)} archivos</FONT>>, fillcolor="{AZUL}", color="{AZUL}"];\n'
              f' raiz [label=<<B>(raíz)</B>  <FONT POINT-SIZE="10" COLOR="{AZUL_OSCURO}">README, CONTRIBUTING, dependencias y ejemplos de configuración · {raiz} archivos</FONT>>, fillcolor="white"];\n r -> raiz;\n')
    orden = list(descripciones)
    for carpeta in sorted(por_carpeta, key=lambda c: orden.index(c) if c in orden else 99):
        subs = por_carpeta[carpeta]
        piezas = [f"{k}/ ({n})" for k, n in sorted(subs.items()) if k]
        if subs.get(""):
            piezas.append(f"{subs['']} archivo{'s' if subs[''] > 1 else ''} propio{'s' if subs[''] > 1 else ''}")
        lineas, actual = [], ""
        for pieza in piezas:
            if actual and len(actual) + len(pieza) > 64:
                lineas.append(actual)
                actual = ""
            actual += ("" if not actual else " · ") + pieza
        if actual:
            lineas.append(actual)
        filas = "".join(f'<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="9" COLOR="{TEXTO_SECUNDARIO}">{_esc(l)}</FONT></TD></TR>' for l in lineas)
        nodo = carpeta.replace("-", "_")
        cuerpo += (f' {nodo} [label=<<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="1">'
                   f'<TR><TD ALIGN="LEFT"><B>{carpeta}/</B>  <FONT POINT-SIZE="10" COLOR="{AZUL_OSCURO}">'
                   f'{_esc(descripciones.get(carpeta, ""))} · {sum(subs.values())} archivo{"s" if sum(subs.values()) != 1 else ""}</FONT></TD></TR>{filas}</TABLE>>];\n r -> {nodo};\n')
    return _exportar("A16_repositorio", _grafo(cuerpo, direccion="LR", sep=(0.1, 0.5)))


def archivos_proyecto() -> list[str]:
    """Archivos del repositorio según Git (incluye los nuevos no ignorados); sin Git, recorre las carpetas."""
    if shutil.which("git"):
        r = subprocess.run(["git", "-C", str(RAIZ_PROYECTO), "ls-files", "--cached", "--others", "--exclude-standard"],
                           capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            return sorted(l for l in r.stdout.splitlines() if (RAIZ_PROYECTO / l).exists())
    omitir = {".git", "__pycache__", ".pytest_cache", "node_modules", ".venv", "venv"}
    archivos = []
    for ruta in RAIZ_PROYECTO.rglob("*"):
        relativa = ruta.relative_to(RAIZ_PROYECTO)
        if not ruta.is_file() or omitir.intersection(relativa.parts):
            continue
        a = relativa.as_posix()
        secreto = ruta.name.startswith(".env") and not ruta.name.endswith(".example")
        regenerable = (a.startswith("data/sintetico/") and a.endswith(".csv")) or a.endswith(("_generado.md", "plantilla_estilos.docx"))
        if not secreto and not regenerable:
            archivos.append(a)
    return sorted(archivos)


def generar_todas(archivos: list[str]) -> list[Path]:
    return [encargo(), estado(), objetivos(), personas(), ruta_vuelo(), precio_historico(), normalizacion(), integridad(),
            scripts(), aplicacion(), concurrencia(), pruebas(), cronograma(), riesgos(), equipo(), repositorio(archivos)]
