"""Figuras del informe generadas exclusivamente desde los CSV de reports/resultados.

Cada figura declara la consulta que la alimenta (trazabilidad figura -> CSV -> SQL).
Paleta: ranuras categóricas validadas (azul, naranja, aqua) y rampa secuencial azul.
Sin doble eje: medidas de distinta escala van en paneles separados.
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.colors import LinearSegmentedColormap  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Patch  # noqa: E402

from .config import RAIZ_PROYECTO  # noqa: E402

DIR_RESULTADOS = RAIZ_PROYECTO / "reports" / "resultados"
DIR_FIGURAS = RAIZ_PROYECTO / "reports" / "figuras"

SUPERFICIE = "#fcfcfb"
TEXTO = "#0b0b0b"
TEXTO_SECUNDARIO = "#52514e"
REJILLA = "#e4e3de"
SERIE = ["#2a78d6", "#eb6834", "#1baf7a"]          # ranuras 1-3 validadas (claro)
SECUENCIAL = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]

plt.rcParams.update({
    "figure.facecolor": SUPERFICIE, "axes.facecolor": SUPERFICIE, "savefig.facecolor": SUPERFICIE,
    "axes.edgecolor": REJILLA, "axes.labelcolor": TEXTO_SECUNDARIO, "xtick.color": TEXTO_SECUNDARIO,
    "ytick.color": TEXTO_SECUNDARIO, "text.color": TEXTO, "font.size": 10, "axes.titlesize": 12,
    "axes.titleweight": "bold", "axes.titlelocation": "left", "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": REJILLA, "grid.linewidth": 0.8, "axes.axisbelow": True,
})


def _csv(nombre: str) -> pd.DataFrame:
    return pd.read_csv(DIR_RESULTADOS / f"{nombre}.csv")


def _barras_h(ax, etiquetas, valores, color, alto=0.62, redondeo=0.06):
    """Barras horizontales delgadas con extremo redondeado y separación del color de la superficie."""
    ax.set_ylim(-0.6, len(valores) - 0.4)
    maximo = max(valores) if len(valores) else 1
    for i, v in enumerate(valores):
        ax.add_patch(FancyBboxPatch((0, i - alto / 2), v, alto, boxstyle=f"round,pad=0,rounding_size={min(redondeo * maximo, v / 2) if v > 0 else 0}",
                                    linewidth=0, facecolor=color, mutation_aspect=alto / max(maximo, 1e-9) * 6))
    ax.set_yticks(range(len(etiquetas)), etiquetas)
    ax.set_xlim(0, maximo * 1.18)
    ax.grid(axis="y", visible=False)


def _guardar(fig, nombre: str) -> Path:
    DIR_FIGURAS.mkdir(parents=True, exist_ok=True)
    ruta = DIR_FIGURAS / f"{nombre}.png"
    fig.savefig(ruta, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return ruta


def f01_ocupacion_ruta_cabina():
    df = _csv("Q02_ocupacion_ruta_cabina")
    fig, ejes = plt.subplots(1, 2, figsize=(11, 6.2), sharey=False)
    for ax, (cabina, color) in zip(ejes, (("ECO", SERIE[0]), ("VIP", SERIE[1]))):
        d = df[(df.codigo_cabina == cabina) & (df.ruta != "TOTAL")].sort_values("factor_ponderado")
        total = df[(df.codigo_cabina == cabina) & (df.ruta == "TOTAL")].factor_ponderado * 100
        _barras_h(ax, d.ruta, (d.factor_ponderado * 100).tolist(), color)
        for i, v in enumerate(d.factor_ponderado * 100):
            ax.text(v + 1, i, f"{v:.1f} %", va="center", fontsize=8.5, color=TEXTO_SECUNDARIO, zorder=4,
                    bbox=dict(facecolor=SUPERFICIE, edgecolor="none", pad=0.6))
        if len(total):
            # La fila TOTAL de Q02 (GROUPING SETS) se muestra como referencia, no como una ruta más.
            ax.axvline(total.iloc[0], color=TEXTO_SECUNDARIO, linestyle=(0, (4, 3)), linewidth=1, zorder=1)
            ax.text(total.iloc[0], len(d) - 0.35, f"todas las rutas: {total.iloc[0]:.1f} %", ha="center", va="bottom",
                    fontsize=8.5, color=TEXTO_SECUNDARIO, backgroundcolor=SUPERFICIE)
        ax.set_ylim(-0.6, len(d) + 0.3)
        ax.set_xlim(0, 110)
        ax.set_title(f"Cabina {cabina}")
        ax.set_xlabel("Factor de ocupación ponderado (%)")
    fig.suptitle("Ocupación de vuelos operados por ruta y cabina (sep-oct 2026, datos sintéticos)", x=0.01, ha="left", fontsize=13, fontweight="bold")
    fig.tight_layout()
    return _guardar(fig, "F01_ocupacion_ruta_cabina"), "Q02"


def f02_flujo_mensual():
    df = _csv("Q03_ventas_cobros_reembolsos_mes")
    meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    df["mes"] = [f"{meses[f.month - 1]} {f.year}" for f in pd.to_datetime(df.mes)]
    series = [("ventas_brutas_usd", "Ventas brutas"), ("cobros_usd", "Cobros confirmados"), ("reembolsos_usd", "Reembolsos")]
    fig, ax = plt.subplots(figsize=(10.5, 5.2))
    ancho = 0.26
    for k, (col, etiqueta) in enumerate(series):
        x = [i + (k - 1) * (ancho + 0.02) for i in range(len(df))]
        ax.bar(x, df[col] / 1e6, width=ancho, color=SERIE[k], label=etiqueta)
        for xi, v in zip(x, df[col] / 1e6):
            if v > 0:
                ax.text(xi, v + 0.15, f"{v:.1f}", ha="center", fontsize=7.5, color=TEXTO_SECUNDARIO)
    ax.set_xticks(range(len(df)), df.mes)
    ax.set_ylabel("Millones de USD")
    ax.grid(axis="x", visible=False)
    ax.legend(frameon=False, loc="upper left", ncols=3)
    ax.set_title("Ventas, cobros y reembolsos por mes del evento (datos sintéticos; corte 1-nov-2026)")
    fig.tight_layout()
    return _guardar(fig, "F02_flujo_mensual"), "Q03"


def f03_ventas_canal():
    df = _csv("Q07_ventas_por_canal").sort_values("ventas_usd")
    colores = {"AER": SERIE[0], "OFI": SERIE[1], "WEB": SERIE[2]}
    fig, ax = plt.subplots(figsize=(10, 6.4))
    ax.set_ylim(-0.6, len(df) - 0.4)
    for i, (_, fila) in enumerate(df.iterrows()):
        ax.barh(i, fila.ventas_usd / 1e6, height=0.62, color=colores[fila.tipo_localizacion])
        ax.text(fila.ventas_usd / 1e6 + 0.1, i, f"{fila.participacion_total * 100:.1f} %", va="center", fontsize=8.5, color=TEXTO_SECUNDARIO)
    ax.set_yticks(range(len(df)), df.codigo_localizacion)
    ax.grid(axis="y", visible=False)
    ax.set_xlabel("Ventas vigentes (millones de USD); etiqueta = participación en el total")
    leyenda = [Patch(facecolor=colores[t], label=n)
               for t, n in (("WEB", "Web"), ("AER", "Mostrador de aeropuerto"), ("OFI", "Oficina de ciudad"))]
    ax.legend(handles=leyenda, frameon=False, loc="lower right")
    ax.set_title("Ventas por punto de venta y canal (jul-oct 2026)")
    fig.tight_layout()
    return _guardar(fig, "F03_ventas_canal"), "Q07"


def f04_anticipacion():
    df = _csv("Q12_anticipacion_compra")
    df["tramo"] = df.tramo.str.slice(3)
    fig, ejes = plt.subplots(1, 3, figsize=(12, 4.2))
    paneles = [("participacion", "Participación de tiquetes (%)", 100, SERIE[0]),
               ("precio_medio_eco_usd", "Precio medio ECO (USD)", 1, SERIE[0]),
               ("precio_medio_vip_usd", "Precio medio VIP (USD)", 1, SERIE[1])]
    for ax, (col, titulo, factor, color) in zip(ejes, paneles):
        ax.bar(df.tramo, df[col] * factor, width=0.6, color=color)
        for i, v in enumerate(df[col] * factor):
            ax.text(i, v * 1.01, f"{v:.0f}" if factor == 1 else f"{v:.1f}", ha="center", va="bottom", fontsize=8, color=TEXTO_SECUNDARIO)
        ax.set_title(titulo, fontsize=10.5)
        ax.tick_params(axis="x", rotation=30, labelsize=8.5)
        ax.grid(axis="x", visible=False)
    fig.suptitle("Anticipación de compra (días entre la venta y la salida), vuelos de sep-oct 2026", x=0.01, ha="left", fontsize=12.5, fontweight="bold")
    fig.tight_layout()
    return _guardar(fig, "F04_anticipacion_compra"), "Q12"


def f05_puntualidad():
    df = _csv("Q15_puntualidad").sort_values("puntualidad")
    fig, ax = plt.subplots(figsize=(9.5, 6.2))
    _barras_h(ax, df.ruta, (df.puntualidad * 100).tolist(), SERIE[0])
    for i, (v, c) in enumerate(zip(df.puntualidad * 100, df.vuelos_cancelados)):
        ax.text(v + 1, i, f"{v:.1f} %" + (f"  · {c} cancel." if c else ""), va="center", fontsize=8.5, color=TEXTO_SECUNDARIO)
    ax.set_xlim(0, 115)
    ax.set_xlabel("Vuelos que llegan con menos de 15 min de demora (%)")
    ax.set_title("Puntualidad de llegada por ruta (sep-oct 2026, datos sintéticos)")
    fig.tight_layout()
    return _guardar(fig, "F05_puntualidad_ruta"), "Q15"


def f06_demanda_dia_franja():
    df = _csv("Q11_demanda_dia_hora")
    tabla = df.pivot(index="franja", columns="dia", values="factor_ocupacion")
    dias = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
    tabla = tabla[[d for d in dias if d in tabla.columns]]
    mapa = LinearSegmentedColormap.from_list("azul", SECUENCIAL)
    fig, ax = plt.subplots(figsize=(10, 3.8))
    im = ax.imshow(tabla.values * 100, cmap=mapa, aspect="auto", vmin=tabla.values.min() * 100 - 2, vmax=tabla.values.max() * 100)
    for (i, j), v in pd.DataFrame(tabla.values * 100).stack().items():
        ax.text(j, i, f"{v:.1f}", ha="center", va="center", fontsize=9,
                color="white" if v > (tabla.values.min() * 100 + tabla.values.max() * 100) / 2 else TEXTO)
    ax.set_xticks(range(len(tabla.columns)), tabla.columns)
    ax.set_yticks(range(len(tabla.index)), [f[3:] for f in tabla.index])
    ax.grid(False)
    for lado in ("left", "bottom"):
        ax.spines[lado].set_visible(False)
    barra = fig.colorbar(im, ax=ax, shrink=0.8)
    barra.set_label("Factor de ocupación (%)")
    ax.set_title("Ocupación por día de la semana y franja de salida (vuelos operados)")
    fig.tight_layout()
    return _guardar(fig, "F06_demanda_dia_franja"), "Q11"


def f07_distribucion_ocupacion():
    df = _csv("Q01_ocupacion_por_vuelo")
    fig, ax = plt.subplots(figsize=(9.5, 4.6))
    ax.hist(df.factor_ocupacion * 100, bins=range(0, 105, 5), color=SERIE[0], rwidth=0.88)
    mediana = (df.factor_ocupacion * 100).median()
    ax.axvline(mediana, color=TEXTO_SECUNDARIO, linewidth=1)
    ax.set_ylim(0, ax.get_ylim()[1] * 1.12)
    ax.text(mediana, ax.get_ylim()[1] * 0.97, f"mediana {mediana:.1f} %", color=TEXTO_SECUNDARIO, fontsize=9,
            ha="center", va="top", backgroundcolor=SUPERFICIE)
    ax.set_xlabel("Factor de ocupación del vuelo (%)")
    ax.set_ylabel("Vuelos")
    ax.grid(axis="x", visible=False)
    ax.set_title(f"Distribución de la ocupación de {len(df)} vuelos operados (sep-oct 2026)")
    fig.tight_layout()
    return _guardar(fig, "F07_distribucion_ocupacion"), "Q01"


def f08_utilizacion_flota():
    df = _csv("Q10_utilizacion_flota").sort_values("horas_promedio_por_dia")
    fig, ax = plt.subplots(figsize=(9.5, 6))
    _barras_h(ax, df.matricula + " · " + df.modelo, df.horas_promedio_por_dia.tolist(), SERIE[0])
    for i, (v, e) in enumerate(zip(df.horas_promedio_por_dia, df.estado_operativo)):
        ax.text(v + 0.1, i, f"{v:.1f} h" + ("  (en mantenimiento)" if e != "ACTIVO" else ""), va="center", fontsize=8.5, color=TEXTO_SECUNDARIO)
    ax.set_xlabel("Horas bloque programadas por día del período")
    ax.set_title("Utilización de la flota (sep-oct 2026)")
    fig.tight_layout()
    return _guardar(fig, "F08_utilizacion_flota"), "Q10"


FIGURAS = [f01_ocupacion_ruta_cabina, f02_flujo_mensual, f03_ventas_canal, f04_anticipacion,
           f05_puntualidad, f06_demanda_dia_franja, f07_distribucion_ocupacion, f08_utilizacion_flota]


def generar_graficos(eco=print) -> dict:
    manifiesto = {}
    for funcion in FIGURAS:
        ruta, consulta = funcion()
        manifiesto[ruta.stem] = {"archivo": str(ruta.relative_to(RAIZ_PROYECTO)), "consulta": consulta,
                                 "csv": next(str(p.relative_to(RAIZ_PROYECTO)) for p in DIR_RESULTADOS.glob(f"{consulta}_*.csv"))}
        eco(f"  {ruta.name:<34} <- {consulta}")
    (DIR_FIGURAS / "manifiesto_figuras.json").write_text(json.dumps(manifiesto, indent=2, ensure_ascii=False), encoding="utf-8")
    return manifiesto
