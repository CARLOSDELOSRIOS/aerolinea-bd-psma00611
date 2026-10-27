"""Ejecución de pruebas: suite T-SQL (una sesión) y pruebas de concurrencia (varias sesiones).

Las pruebas de concurrencia crean escenarios CONFIRMADOS (vuelos 9910-9913 en la
ruta de prueba BOS-ORD, a 40-43 días de la fecha real) porque otras sesiones
deben verlos; al terminar se eliminan con tst.usp_limpiar_escenarios.
"""
from __future__ import annotations

import json
import threading
import time
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

from .config import ConfigBD
from .db import ErrorBaseDatos, abrir_conexion, conectar, ejecutar
from .despliegue import informacion_entorno


def _escenario(cursor, numero: int, dias: int) -> dict:
    (_, filas), = ejecutar(cursor, """
        DECLARE @v INT, @c INT, @w INT;
        EXEC tst.usp_preparar_escenario @numero_vuelo = ?, @dias_hasta_vuelo = ?,
             @id_vuelo = @v OUTPUT, @id_comprador = @c OUTPUT, @id_web = @w OUTPUT;
        SELECT @v, @c, @w;""", (numero, dias))
    return dict(zip(("vuelo", "comprador", "web"), filas[0]))


def _pasajeros(cursor, cantidad: int, base: int) -> list[int]:
    ids = []
    for i in range(cantidad):
        (_, filas), = ejecutar(cursor, "DECLARE @p INT; EXEC tst.usp_nuevo_pasajero @sufijo = ?, @id_persona = @p OUTPUT; SELECT @p;", (base + i,))
        ids.append(filas[0][0])
    return ids


def _en_paralelo(cfg: ConfigBD, tareas: list) -> list[tuple[str, int | None, float]]:
    """Ejecuta cada tarea(cursor) en su propia conexión, liberadas a la vez con una barrera."""
    conexiones = [abrir_conexion(cfg, autocommit=True) for _ in tareas]
    barrera = threading.Barrier(len(tareas))
    resultados: list = [None] * len(tareas)

    def trabajador(i: int) -> None:
        cursor = conexiones[i].cursor()
        barrera.wait()
        inicio = time.perf_counter()
        try:
            tareas[i](cursor)
            resultados[i] = ("OK", None, time.perf_counter() - inicio)
        except ErrorBaseDatos as exc:
            resultados[i] = ("ERROR", exc.numero, time.perf_counter() - inicio)

    hilos = [threading.Thread(target=trabajador, args=(i,)) for i in range(len(tareas))]
    for h in hilos:
        h.start()
    for h in hilos:
        h.join()
    for c in conexiones:
        c.close()
    return resultados


def _emitir(vuelo: int, cabina: str, pasajero: int, comprador: int, web: int, asiento: str | None = None):
    def tarea(cursor):
        ejecutar(cursor, """EXEC ven.usp_emitir_tiquete @id_vuelo = ?, @codigo_cabina = ?, @id_persona_pasajero = ?,
                 @id_persona_comprador = ?, @id_localizacion_venta = ?, @codigo_asiento = ?;""",
                 (vuelo, cabina, pasajero, comprador, web, asiento))
    return tarea


def pruebas_concurrencia(cfg: ConfigBD, eco=print) -> list[dict]:
    resultados = []
    with conectar(cfg, autocommit=True) as conexion:
        cursor = conexion.cursor()
        ejecutar(cursor, "EXEC tst.usp_limpiar_escenarios;")
        try:
            # PC-01: 40 sesiones compiten por 12 asientos VIP.
            e = _escenario(cursor, 9910, 40)
            pasajeros = _pasajeros(cursor, 40, 100)
            r = _en_paralelo(cfg, [_emitir(e["vuelo"], "VIP", p, e["comprador"], e["web"]) for p in pasajeros])
            (_, filas), = ejecutar(cursor, """SELECT vc.plazas_ocupadas, vc.capacidad,
                    (SELECT COUNT(*) FROM ven.tiquete WHERE id_vuelo = ? AND codigo_cabina = 'VIP' AND codigo_estado <> 'CANCELADO')
                FROM ops.vuelo_cabina AS vc WHERE vc.id_vuelo = ? AND vc.codigo_cabina = 'VIP';""", (e["vuelo"], e["vuelo"]))
            ocupadas, capacidad, tiquetes = filas[0]
            conteo = Counter(x[0] if x[1] is None else str(x[1]) for x in r)
            resultados.append({"id": "PC-01", "regla": "RN-11", "descripcion": "40 sesiones simultáneas compran en una cabina VIP de 12 asientos",
                               "resultado": "SUPERADA" if conteo["OK"] == 12 and ocupadas == 12 == tiquetes and conteo["50020"] == 28 else "FALLIDA",
                               "detalle": f"éxitos {conteo['OK']}, rechazos por capacidad {conteo['50020']}, otros {dict(conteo)}; "
                                          f"plazas ocupadas {ocupadas}/{capacidad}; tiquetes activos {tiquetes}; "
                                          f"tiempo máximo {max(x[2] for x in r):.3f} s"})

            # PC-02: 20 sesiones intentan el mismo asiento.
            e = _escenario(cursor, 9911, 41)
            pasajeros = _pasajeros(cursor, 20, 200)
            r = _en_paralelo(cfg, [_emitir(e["vuelo"], "ECO", p, e["comprador"], e["web"], "12A") for p in pasajeros])
            (_, filas), = ejecutar(cursor, "SELECT COUNT(*) FROM ven.tiquete WHERE id_vuelo = ? AND codigo_asiento = '12A' AND codigo_estado <> 'CANCELADO';", (e["vuelo"],))
            conteo = Counter(x[0] if x[1] is None else str(x[1]) for x in r)
            resultados.append({"id": "PC-02", "regla": "RN-12", "descripcion": "20 sesiones simultáneas eligen el asiento 12A del mismo vuelo",
                               "resultado": "SUPERADA" if conteo["OK"] == 1 and filas[0][0] == 1 and conteo["50120"] == 19 else "FALLIDA",
                               "detalle": f"éxitos {conteo['OK']}, rechazos por asiento ocupado {conteo['50120']}, otros {dict(conteo)}; tiquetes con 12A: {filas[0][0]}"})

            # PC-03: 10 sesiones pagan a la vez el total del mismo tiquete.
            e = _escenario(cursor, 9912, 42)
            (_, filas), = ejecutar(cursor, """DECLARE @t INT, @p DECIMAL(10,2);
                EXEC ven.usp_emitir_tiquete @id_vuelo = ?, @codigo_cabina = 'ECO', @id_persona_pasajero = ?, @id_persona_comprador = ?,
                     @id_localizacion_venta = ?, @id_tiquete = @t OUTPUT, @precio_final_usd = @p OUTPUT;
                SELECT @t, @p;""", (e["vuelo"], e["comprador"], e["comprador"], e["web"]))
            tiquete, precio = filas[0]

            def pagar(cursor, t=tiquete, monto=precio, web=e["web"]):
                ejecutar(cursor, """EXEC ven.usp_registrar_pago @id_tiquete = ?, @codigo_metodo = 'BILLETERA', @monto_usd = ?,
                         @id_localizacion_cobro = ?;""", (t, monto, web))
            r = _en_paralelo(cfg, [pagar] * 10)
            (_, filas), = ejecutar(cursor, "SELECT cobrado_usd, codigo_estado FROM rpt.v_tiquete_financiero WHERE id_tiquete = ?;", (tiquete,))
            cobrado, estado = filas[0]
            conteo = Counter(x[0] if x[1] is None else str(x[1]) for x in r)
            resultados.append({"id": "PC-03", "regla": "RN-23", "descripcion": "10 sesiones registran a la vez el pago total del mismo tiquete",
                               "resultado": "SUPERADA" if conteo["OK"] == 1 and Decimal(cobrado) == Decimal(precio) and estado == "EMITIDO" else "FALLIDA",
                               "detalle": f"éxitos {conteo['OK']}, rechazos {dict((k, v) for k, v in conteo.items() if k != 'OK')}; "
                                          f"cobrado {cobrado} de {precio} USD; estado {estado}"})

            # PC-04: 30 tiquetes sin asiento piden asignación automática a la vez.
            e = _escenario(cursor, 9913, 43)
            pasajeros = _pasajeros(cursor, 30, 300)
            tiquetes = []
            for p in pasajeros:
                (_, filas), = ejecutar(cursor, """DECLARE @t INT;
                    EXEC ven.usp_emitir_tiquete @id_vuelo = ?, @codigo_cabina = 'ECO', @id_persona_pasajero = ?, @id_persona_comprador = ?,
                         @id_localizacion_venta = ?, @id_tiquete = @t OUTPUT; SELECT @t;""", (e["vuelo"], p, e["comprador"], e["web"]))
                tiquetes.append(filas[0][0])
            r = _en_paralelo(cfg, [(lambda t: (lambda c: ejecutar(c, "EXEC ven.usp_asignar_asiento @id_tiquete = ?;", (t,))))(t) for t in tiquetes])
            (_, filas), = ejecutar(cursor, """SELECT COUNT(*), COUNT(DISTINCT codigo_asiento) FROM ven.tiquete
                                              WHERE id_vuelo = ? AND codigo_asiento IS NOT NULL;""", (e["vuelo"],))
            asignados, distintos = filas[0]
            conteo = Counter(x[0] if x[1] is None else str(x[1]) for x in r)
            resultados.append({"id": "PC-04", "regla": "RN-12", "descripcion": "30 sesiones piden a la vez la asignación automática de asiento",
                               "resultado": "SUPERADA" if conteo["OK"] == 30 and asignados == distintos == 30 else "FALLIDA",
                               "detalle": f"éxitos {conteo['OK']}, errores {dict((k, v) for k, v in conteo.items() if k != 'OK')}; "
                                          f"asientos asignados {asignados}, distintos {distintos} (semáforo por vuelo y cabina)"})
        finally:
            ejecutar(cursor, "EXEC tst.usp_limpiar_escenarios;")
    for res in resultados:
        eco(f"  {res['id']} {res['resultado']:<9} {res['descripcion']} | {res['detalle']}")
    return resultados


def pruebas_tsql(cfg: ConfigBD, eco=print) -> list[dict]:
    with conectar(cfg, autocommit=True) as conexion:
        conexion.timeout = 0
        conjuntos = ejecutar(conexion.cursor(), "EXEC tst.usp_ejecutar_pruebas;")
    columnas, filas = conjuntos[-1]
    resultados = [dict(zip(columnas, f)) for f in filas]
    for r in resultados:
        eco(f"  {r['id_prueba']} {r['resultado']:<9} {r['descripcion']} | {r['detalle']}")
    return resultados


def ejecutar_pruebas(cfg: ConfigBD, directorio: Path, concurrencia: bool = True, eco=print) -> bool:
    inicio = datetime.now(timezone.utc)
    entorno = informacion_entorno(cfg)
    eco("Pruebas T-SQL (tst.usp_ejecutar_pruebas):")
    tsql = pruebas_tsql(cfg, eco)
    conc = []
    if concurrencia:
        eco("Pruebas de concurrencia (sesiones simultáneas):")
        conc = pruebas_concurrencia(cfg, eco)
    todas = [{"id": r["id_prueba"], "regla": r["regla"], "descripcion": r["descripcion"], "resultado": r["resultado"],
              "detalle": r["detalle"], "tipo": "T-SQL"} for r in tsql] + [{**r, "tipo": "Concurrencia"} for r in conc]
    superadas = sum(1 for r in todas if r["resultado"] == "SUPERADA")
    evidencia = {"inicio_utc": inicio.isoformat(timespec="seconds"),
                 "fin_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                 "entorno": {k: entorno[k] for k in ("servidor", "edicion", "version", "base_datos", "rcsi", "cifrado", "controlador_odbc")},
                 "resumen": {"total": len(todas), "superadas": superadas, "fallidas": len(todas) - superadas},
                 "pruebas": todas}
    directorio.mkdir(parents=True, exist_ok=True)
    (directorio / "resultados_pruebas.json").write_text(json.dumps(evidencia, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    lineas = ["# Resultados de pruebas", "",
              f"- Ejecución: {evidencia['inicio_utc']} a {evidencia['fin_utc']} (UTC)",
              f"- Servidor: `{entorno['servidor']}` · {entorno['edicion']} · {entorno['version']} · base `{entorno['base_datos']}`",
              f"- Aislamiento: READ_COMMITTED_SNAPSHOT = {entorno['rcsi']}; conexión cifrada = {entorno['cifrado']}",
              f"- Resultado: **{superadas} de {len(todas)} superadas**", "",
              "| ID | Tipo | Regla | Resultado | Descripción | Detalle observado |", "|---|---|---|---|---|---|"]
    lineas += [f"| {r['id']} | {r['tipo']} | {r['regla']} | {r['resultado']} | {r['descripcion']} | {str(r['detalle']).replace('|', '/')} |" for r in todas]
    (directorio / "resultados_pruebas.md").write_text("\n".join(lineas) + "\n", encoding="utf-8")
    eco(f"Resultado: {superadas}/{len(todas)} superadas. Evidencia en {directorio}")
    return superadas == len(todas)
