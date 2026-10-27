"""Orquestación de la carga sintética: vuelos -> generación -> CSV -> staging -> modelo."""
from __future__ import annotations

import time
from datetime import date, datetime
from pathlib import Path

from .config import RAIZ_PROYECTO, ConfigBD
from .db import conectar, ejecutar
from .generador import (FECHA_CORTE_PREDETERMINADA, INICIO_OPERACIONES, SEMILLA_PREDETERMINADA, Generador,
                        cargar_staging, escribir_csv, leer_referencia)

DIR_SINTETICO = RAIZ_PROYECTO / "data" / "sintetico"
FIN_HORIZONTE = date(2026, 12, 31)


def cargar_datos(cfg: ConfigBD, semilla: int = SEMILLA_PREDETERMINADA,
                 fecha_corte: datetime = FECHA_CORTE_PREDETERMINADA,
                 hasta: date = FIN_HORIZONTE, directorio: Path = DIR_SINTETICO, eco=print) -> dict:
    tiempos = {}
    inicio = time.perf_counter()
    with conectar(cfg, autocommit=True) as conexion:
        cursor = conexion.cursor()
        # Requisito del enunciado: los vuelos se generan a partir de la programación de rutas (en la base).
        (_, filas), = ejecutar(cursor, """DECLARE @n INT;
            EXEC ops.usp_generar_vuelos @fecha_desde = ?, @fecha_hasta = ?, @vuelos_creados = @n OUTPUT;
            SELECT @n AS vuelos_creados;""", (INICIO_OPERACIONES, hasta))
        eco(f"  Vuelos generados por ops.usp_generar_vuelos: {filas[0][0]}")
        referencia = leer_referencia(conexion)
    tiempos["vuelos_y_referencia_s"] = round(time.perf_counter() - inicio, 1)

    inicio = time.perf_counter()
    resultado = Generador(referencia, semilla, fecha_corte).generar()
    manifiesto = escribir_csv(resultado, directorio)
    tiempos["generacion_csv_s"] = round(time.perf_counter() - inicio, 1)
    eco(f"  Datos generados (semilla {semilla}): " + ", ".join(f"{k}={v}" for k, v in resultado.resumen["filas"].items()))

    inicio = time.perf_counter()
    with conectar(cfg, autocommit=False) as conexion:
        cargar_staging(conexion, directorio, eco=eco)
    tiempos["staging_s"] = round(time.perf_counter() - inicio, 1)

    inicio = time.perf_counter()
    descripcion = f"semilla={semilla}; corte={fecha_corte.isoformat()}; horizonte={INICIO_OPERACIONES}..{hasta}"
    with conectar(cfg, autocommit=True) as conexion:
        conexion.timeout = 0          # sin límite de tiempo para la aplicación de la carga
        cursor = conexion.cursor()
        abiertas = ejecutar(cursor, "SELECT @@TRANCOUNT;")[0][1][0][0]
        if abiertas:
            raise RuntimeError(f"La sesión de carga empezó con {abiertas} transacción(es) abierta(s); no se aplica la carga.")
        ejecutar(cursor, "EXEC stg.usp_aplicar_carga_sintetica @fecha_corte_utc = ?, @descripcion = ?;",
                 (fecha_corte, descripcion))
        abiertas = ejecutar(cursor, "SELECT @@TRANCOUNT;")[0][1][0][0]
        if abiertas:
            ejecutar(cursor, "ROLLBACK;")
            raise RuntimeError("La carga terminó con una transacción sin confirmar; se revirtió. Revise la sesión.")
        ejecutar(cursor, "EXEC stg.usp_vaciar_staging;")
    tiempos["aplicacion_s"] = round(time.perf_counter() - inicio, 1)
    eco("  Carga aplicada con todas las reglas activas: " + ", ".join(f"{k}={v}" for k, v in tiempos.items()))
    manifiesto["tiempos"] = tiempos
    return manifiesto
