"""Generador determinista de datos sintéticos.

Los datos son SINTÉTICOS: sus patrones (demanda, demoras, cancelaciones) se
derivan de supuestos declarados en este archivo y no acreditan el comportamiento
real del mercado aéreo.

Reproducibilidad: con la misma semilla, la misma fecha de corte y los mismos
datos de referencia, el generador produce exactamente las mismas filas (se
verifica con el hash SHA-256 de cada CSV). Solo se usa random.Random(semilla)
y se recorren estructuras ordenadas.

El generador replica las reglas que la base de datos valida con triggers
(tarifa vigente, descuentos, plazo de pago, política de reembolso); si una fila
no las cumpliera, la carga fallaría y se revertiría por completo.
"""
from __future__ import annotations

import bisect
import csv
import hashlib
import json
import random
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

import pyodbc

from .db import ejecutar

SEMILLA_PREDETERMINADA = 20261106            # fecha de apertura del PAC (6-nov-2026)
FECHA_CORTE_PREDETERMINADA = datetime(2026, 11, 1, 0, 0)   # UTC
INICIO_VENTAS = datetime(2026, 7, 1, 0, 0)   # UTC
INICIO_OPERACIONES = date(2026, 9, 1)

# --------------------------------------------------------------------------
# Supuestos de operación (sintéticos)
# --------------------------------------------------------------------------
# Línea = avión asignado a una secuencia diaria de vuelos (rotación).
LINEAS = {
    "L01": ("N321XA", (101, 102)), "L02": ("N322XA", (112, 111)), "L03": ("N201XA", (201, 202, 203, 204)),
    "L04": ("N202XA", (301, 302)), "L05": ("N801XA", (401, 402, 403, 404)), "L06": ("N802XA", (501, 502)),
    "L07": ("N203XA", (601, 602)), "L08": ("N175XA", (701, 702, 703, 704)), "L09": ("N803XA", (801, 802)),
    "L10": ("N176XA", (901, 902)), "L11": ("N323XA", (1001, 1002)), "L12": ("N324XA", (1101, 1102)),
}
# Un día de mantenimiento cada 21 días; ese día vuela el avión de reserva de la misma configuración.
RESERVA_POR_CONFIGURACION = {"A21N-20V168E": "N325XA", "A20N-12V150E": "N204XA",
                             "B738-16V144E": "N804XA", "E175-12V64E": "N177XA"}
DESFASE_MANTENIMIENTO = {"L01": 3, "L02": 8, "L11": 13, "L12": 18, "L03": 2, "L04": 9, "L07": 16,
                         "L05": 4, "L06": 11, "L09": 18, "L08": 6, "L10": 15}
CICLO_MANTENIMIENTO = 21
# Tripulación: cada línea tiene entre EQUIPOS_MINIMOS y EQUIPOS_MAXIMOS equipos que rotan en bloques de
# DIAS_BLOQUE_TRIPULACION días. Se elige el mínimo de equipos cuya cota de peor caso de horas de vuelo en
# 28 días consecutivos (672 h) no supera LIMITE_HORAS_28_DIAS, referencia tomada de 14 CFR 117.23(b)(1).
EQUIPOS_MINIMOS = 4
EQUIPOS_MAXIMOS = 5
DIAS_BLOQUE_TRIPULACION = 3
LIMITE_HORAS_28_DIAS = 100

FACTOR_DIA = {1: 1.00, 2: 0.90, 3: 0.88, 4: 1.00, 5: 1.08, 6: 0.95, 7: 1.07}   # ISO: 1 = lunes
PROB_CANCELACION_VUELO = 0.012
PROB_COMPRADOR_REGISTRADO = 0.42
PROB_IDA_Y_VUELTA = 0.25
PROB_ASIENTO_EN_COMPRA = 0.85
PROB_CANCELACION_VOLUNTARIA = 0.05
PROB_ABANDONO = 0.015                        # reservas que no se terminan de pagar
PROB_NO_PRESENTADO = 0.045
CLIENTES_REGISTRADOS = 30000

NOMBRES = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda", "David", "Elizabeth",
           "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah", "Christopher", "Karen",
           "Carlos", "María", "José", "Ana", "Luis", "Carmen", "Juan", "Sofía", "Miguel", "Lucía", "Daniel", "Valentina",
           "Emily", "Andrew", "Olivia", "Ethan", "Grace", "Noah", "Chloé", "Kevin", "Isabella", "Brian", "Íñigo",
           "Begoña", "Ángela", "Renée", "Zoë", "Mateo", "Camila", "Diego", "Gabriela", "Wei", "Mei", "Hiroshi",
           "Aiko", "Arjun", "Priya", "Fatima", "Omar", "Liam"]
APELLIDOS = ["Smith", "Johnson", "Williams", "Brown", "Jones", "García", "Miller", "Davis", "Rodríguez", "Martínez",
             "Hernández", "López", "González", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
             "Lee", "Pérez", "Thompson", "White", "Harris", "Sánchez", "Clark", "Ramírez", "Lewis", "Robinson",
             "Walker", "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Muñoz",
             "Peña", "Núñez", "Ibáñez", "O'Connor", "Smith-Jones", "Kim", "Patel", "Chen", "Tanaka", "Silva",
             "Rossi", "Müller", "Dubois", "Castro", "Vargas", "Rojas", "Mendoza", "Herrera", "Cruz"]
PAISES_EXTRANJEROS = ["MX", "CA", "CO", "PE", "ES", "GB", "DE", "BR", "AR", "CL", "FR", "JP", "IN", "CN", "PH", "KR", "DO"]
MOTIVOS_RECHAZO = ["Fondos insuficientes", "Tarjeta vencida", "Rechazado por la entidad emisora", "Sospecha de fraude"]
ALFABETO_LOCALIZADOR = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CENTAVO = Decimal("0.01")


# --------------------------------------------------------------------------
# Datos de referencia leídos de la base
# --------------------------------------------------------------------------
@dataclass
class Referencia:
    vuelos: list[dict]
    aviones: dict[str, dict]
    asientos: dict[int, dict[str, list[str]]]         # id_configuracion -> cabina -> [asientos]
    tarifas: dict[tuple[int, str], list[tuple]]       # (id_ruta, cabina) -> [(desde, hasta, id, precio)]
    descuentos: list[dict]
    politicas: dict[str, list[tuple[int, Decimal]]]   # cabina -> [(horas, porcentaje)] desc
    localizaciones: dict[str, dict]
    aeropuertos: dict[str, int]                       # iata -> id_localizacion
    empleados: list[dict]
    parametros: dict[str, str]


def _filas(cursor, sql: str) -> list[dict]:
    columnas, filas = ejecutar(cursor, sql)[0]
    return [dict(zip(columnas, f)) for f in filas]


def leer_referencia(conexion: pyodbc.Connection) -> Referencia:
    cur = conexion.cursor()
    vuelos = _filas(cur, """
        SELECT id_vuelo, numero_vuelo, id_ruta, origen, destino, fecha_salida_local,
               salida_programada_utc, llegada_programada_utc, duracion_programada_min, codigo_estado, id_avion
        FROM rpt.v_vuelo ORDER BY salida_programada_utc, numero_vuelo""")
    aviones = {a["matricula"]: a for a in _filas(cur, """
        SELECT a.id_avion, a.matricula, a.id_configuracion, c.codigo_configuracion, a.estado_operativo
        FROM ops.avion AS a JOIN ops.configuracion_asientos AS c ON c.id_configuracion = a.id_configuracion""")}
    asientos: dict[int, dict[str, list[str]]] = {}
    for s in _filas(cur, "SELECT id_configuracion, codigo_cabina, codigo_asiento FROM ops.asiento_configuracion ORDER BY id_configuracion, fila, letra"):
        asientos.setdefault(s["id_configuracion"], {}).setdefault(s["codigo_cabina"], []).append(s["codigo_asiento"])
    tarifas: dict[tuple[int, str], list[tuple]] = {}
    for t in _filas(cur, "SELECT id_tarifa, id_ruta, codigo_cabina, precio_base_usd, vigente_desde, vigente_hasta FROM ven.tarifa ORDER BY id_ruta, codigo_cabina, vigente_desde"):
        tarifas.setdefault((t["id_ruta"], t["codigo_cabina"]), []).append(
            (t["vigente_desde"], t["vigente_hasta"] or date(9999, 12, 31), t["id_tarifa"], t["precio_base_usd"]))
    descuentos = _filas(cur, "SELECT * FROM ven.descuento WHERE activo = 1 ORDER BY id_descuento")
    politicas: dict[str, list[tuple[int, Decimal]]] = {}
    for p in _filas(cur, "SELECT codigo_cabina, horas_antes_min, porcentaje_reembolso FROM ven.politica_cancelacion ORDER BY codigo_cabina, horas_antes_min DESC"):
        politicas.setdefault(p["codigo_cabina"], []).append((p["horas_antes_min"], p["porcentaje_reembolso"]))
    localizaciones = {l["codigo_localizacion"]: l for l in _filas(cur, "SELECT id_localizacion, codigo_localizacion, tipo_localizacion, vende_tiquetes FROM ref.localizacion")}
    aeropuertos = {a["codigo_iata"]: a["id_localizacion"] for a in _filas(cur, "SELECT codigo_iata, id_localizacion FROM ref.aeropuerto")}
    empleados = _filas(cur, """
        SELECT id_empleado, numero_empleado, codigo_cargo, id_localizacion_base, fecha_contratacion, fecha_terminacion
        FROM rh.empleado ORDER BY numero_empleado""")
    parametros = {p["clave"]: p["valor"] for p in _filas(cur, "SELECT clave, valor FROM ref.parametro")}
    return Referencia(vuelos, aviones, asientos, tarifas, descuentos, politicas, localizaciones, aeropuertos, empleados, parametros)


# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------
def dia_iso(fecha: date) -> int:
    return fecha.isoweekday()


def minutos_entre(desde: datetime, hasta: datetime) -> int:
    """Equivale a DATEDIFF(MINUTE, desde, hasta) para marcas con segundos = 0."""
    return int((hasta - desde).total_seconds() // 60)


def redondear(valor: Decimal) -> Decimal:
    return valor.quantize(CENTAVO, rounding=ROUND_HALF_UP)


def precio_final(base: Decimal, porcentaje: Decimal) -> Decimal:
    return base - redondear(base * porcentaje / Decimal(100))


def ascii_simple(texto: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", texto) if c.isascii() and (c.isalnum() or c in ".-")).lower()


def tarifa_vigente(ref: Referencia, id_ruta: int, cabina: str, dia: date) -> tuple[int, Decimal]:
    for desde, hasta, id_tarifa, precio in ref.tarifas[(id_ruta, cabina)]:
        if desde <= dia <= hasta:
            return id_tarifa, precio
    raise ValueError(f"Sin tarifa vigente para la ruta {id_ruta}/{cabina} el {dia}")


def politica_reembolso(ref: Referencia, cabina: str, motivo: str, venta: datetime, salida: datetime,
                       cancelacion: datetime) -> tuple[Decimal, str] | None:
    """Réplica de ven.fn_politica_reembolso."""
    if motivo in ("VUELO_CANCELADO", "VENCIMIENTO"):
        return Decimal("100.00"), "REEMBOLSO_TOTAL"
    if motivo == "VOLUNTARIA" and cancelacion <= venta + timedelta(hours=24) and minutos_entre(venta, salida) >= 7 * 24 * 60:
        return Decimal("100.00"), "REGLA_24H"
    antes = minutos_entre(cancelacion, salida)
    for horas, porcentaje in ref.politicas[cabina]:
        if horas * 60 <= antes:
            return porcentaje, "POLITICA_CABINA"
    return None


# --------------------------------------------------------------------------
# Generación
# --------------------------------------------------------------------------
@dataclass
class Resultado:
    tablas: dict[str, list[dict]] = field(default_factory=dict)
    resumen: dict = field(default_factory=dict)


class Generador:
    def __init__(self, ref: Referencia, semilla: int = SEMILLA_PREDETERMINADA,
                 fecha_corte: datetime = FECHA_CORTE_PREDETERMINADA):
        self.ref = ref
        self.semilla = semilla
        self.corte = fecha_corte
        self.rng = random.Random(semilla)
        self.horas_limite = int(ref.parametros.get("HORAS_LIMITE_PAGO", 72))
        self.horas_cierre = int(ref.parametros.get("HORAS_CIERRE_VENTA", 3))
        self.personas: list[dict] = []
        self.clientes: list[dict] = []
        self.compras: list[dict] = []
        self.tiquetes: list[dict] = []
        self.pagos: list[dict] = []
        self.reembolsos: list[dict] = []
        self.localizadores: set[str] = set()
        self._contador_persona = 0

    # ------------------------------------------------------------ operación
    def _equipos_por_linea(self, linea_de_vuelo: dict[int, str]) -> dict[str, int]:
        """Mínimo de equipos por línea que respeta LIMITE_HORAS_28_DIAS en el peor caso.

        Con E equipos y bloques de B días, un equipo trabaja como máximo B * ceil(28 / (E * B)) días
        en 28 días consecutivos; se multiplica por las horas de bloque del día más cargado de la línea.
        """
        horas_dia: dict[tuple[str, date], float] = {}
        for v in self.ref.vuelos:
            clave = (linea_de_vuelo[v["numero_vuelo"]], v["fecha_salida_local"])
            horas_dia[clave] = horas_dia.get(clave, 0.0) + v["duracion_programada_min"] / 60
        resultado = {}
        for linea in LINEAS:
            maximo = max(h for (l, _), h in horas_dia.items() if l == linea)
            for e in range(EQUIPOS_MINIMOS, EQUIPOS_MAXIMOS + 1):
                dias = DIAS_BLOQUE_TRIPULACION * -(-28 // (e * DIAS_BLOQUE_TRIPULACION))
                if dias * maximo <= LIMITE_HORAS_28_DIAS:
                    break
            resultado[linea] = e
        return resultado

    def planificar_operacion(self) -> tuple[list[dict], list[dict], list[dict]]:
        ref, rng = self.ref, self.rng
        linea_de_vuelo = {n: l for l, (_, numeros) in LINEAS.items() for n in numeros}
        plan, tripulacion, eventos = [], [], []

        # Equipos de tripulación por línea, que rotan en bloques de DIAS_BLOQUE_TRIPULACION días.
        por_cargo: dict[str, list[dict]] = {}
        for e in ref.empleados:
            if e["fecha_terminacion"] is None:
                por_cargo.setdefault(e["codigo_cargo"], []).append(e)
        auxiliares = iter(por_cargo["TCP"])
        equipos_linea = self._equipos_por_linea(linea_de_vuelo)
        equipos: dict[tuple[str, int], list[tuple[int, str]]] = {}
        k = 0
        for linea, (matricula, _) in sorted(LINEAS.items()):
            configuracion = ref.aviones[matricula]["codigo_configuracion"]
            asientos = sum(len(v) for v in ref.asientos[ref.aviones[matricula]["id_configuracion"]].values())
            cabina_requerida = -(-asientos // int(ref.parametros.get("ASIENTOS_POR_TRIPULANTE_CABINA", 50)))
            for equipo in range(equipos_linea[linea]):
                miembros = [(por_cargo["PILOTO_CAP"][k]["id_empleado"], "CAPITAN"),
                            (por_cargo["PILOTO_FO"][k]["id_empleado"], "PRIMER_OFICIAL"),
                            (por_cargo["TCP_JEFE"][k]["id_empleado"], "JEFE_CABINA")]
                miembros += [(next(auxiliares)["id_empleado"], "AUXILIAR_VUELO") for _ in range(cabina_requerida - 1)]
                equipos[(linea, equipo)] = miembros
                k += 1
            assert configuracion in RESERVA_POR_CONFIGURACION

        # Avión por vuelo (rotación fija con mantenimiento programado).
        avion_de_vuelo: dict[int, str] = {}
        for v in ref.vuelos:
            linea = linea_de_vuelo[v["numero_vuelo"]]
            matricula = LINEAS[linea][0]
            dia = (v["fecha_salida_local"] - INICIO_OPERACIONES).days
            if dia % CICLO_MANTENIMIENTO == DESFASE_MANTENIMIENTO[linea]:
                matricula = RESERVA_POR_CONFIGURACION[ref.aviones[matricula]["codigo_configuracion"]]
            avion_de_vuelo[v["id_vuelo"]] = matricula
            v["matricula"] = matricula
            v["linea"] = linea
            plan.append({"id_vuelo": v["id_vuelo"], "id_avion": ref.aviones[matricula]["id_avion"]})
            equipo = (dia // DIAS_BLOQUE_TRIPULACION) % equipos_linea[linea]
            for id_empleado, rol in equipos[(linea, equipo)]:
                tripulacion.append({"id_vuelo": v["id_vuelo"], "id_empleado": id_empleado, "rol_vuelo": rol})

        # Resultado operativo: cancelaciones, demoras con propagación por avión.
        cancelados_futuros = set(rng.sample([v["id_vuelo"] for v in ref.vuelos if v["salida_programada_utc"] > self.corte + timedelta(days=1)], 2))
        llegada_anterior: dict[str, datetime] = {}
        for v in sorted(ref.vuelos, key=lambda x: (x["matricula"], x["salida_programada_utc"])):
            salida = v["salida_programada_utc"]
            v["cancelacion_vuelo"] = None
            if v["id_vuelo"] in cancelados_futuros:
                v["cancelacion_vuelo"] = self.corte - timedelta(days=2, minutes=rng.randrange(0, 600))
            elif salida < self.corte and rng.random() < PROB_CANCELACION_VUELO:
                v["cancelacion_vuelo"] = salida - timedelta(minutes=rng.randrange(120, 1800))
            if v["cancelacion_vuelo"] is not None:
                eventos.append({"id_vuelo": v["id_vuelo"], "estado_final": "CANCELADO", "salida_estimada_utc": None,
                                "salida_real_utc": None, "llegada_real_utc": None,
                                "motivo_cancelacion": rng.choice(["Condiciones meteorológicas", "Mantenimiento no programado",
                                                                  "Restricción del control de tránsito aéreo"])})
                v["estado_final"] = "CANCELADO"
                continue
            if salida >= self.corte:
                v["estado_final"] = "PROGRAMADO"
                continue
            r = rng.random()
            demora = (rng.randint(-5, 5) if r < 0.72 else rng.randint(6, 30) if r < 0.90
                      else rng.randint(31, 120) if r < 0.98 else rng.randint(121, 300))
            salida_real = salida + timedelta(minutes=demora)
            previa = llegada_anterior.get(v["matricula"])
            if previa is not None and salida_real < previa + timedelta(minutes=30):
                salida_real = previa + timedelta(minutes=30)       # demora propagada por la rotación
            salida_real = min(salida_real, salida + timedelta(minutes=600))
            duracion = round(v["duracion_programada_min"] * rng.uniform(0.93, 1.05))
            llegada_real = salida_real + timedelta(minutes=duracion)
            llegada_anterior[v["matricula"]] = llegada_real
            demora_total = minutos_entre(salida, salida_real)
            estimada = salida_real if demora_total >= 15 else None
            if salida_real >= self.corte:
                estado, estimada, salida_real, llegada_real = "DEMORADO", salida_real, None, None
            elif llegada_real >= self.corte:
                estado, llegada_real = "EN_VUELO", None
            else:
                estado = "ATERRIZADO"
            v["estado_final"] = estado
            eventos.append({"id_vuelo": v["id_vuelo"], "estado_final": estado, "salida_estimada_utc": estimada,
                            "salida_real_utc": salida_real, "llegada_real_utc": llegada_real, "motivo_cancelacion": None})
        return plan, tripulacion, eventos

    # ------------------------------------------------------------- personas
    def _nueva_persona(self, creado: datetime, adulto: bool = True, con_contacto: bool = False) -> dict:
        rng = self.rng
        self._contador_persona += 1
        nombre, apellido = rng.choice(NOMBRES), rng.choice(APELLIDOS)
        edad = rng.randint(18, 82) if adulto else rng.randint(1, 17)
        nacimiento = (creado - timedelta(days=edad * 365 + rng.randrange(0, 365))).date()
        extranjero = rng.random() < 0.15
        pais = rng.choice(PAISES_EXTRANJEROS) if extranjero else "US"
        tipo = "PASAPORTE" if extranjero else rng.choice(["ID_ESTATAL", "LICENCIA"])
        documento = adulto or rng.random() < 0.3
        persona = {
            "clave": self._contador_persona, "nombres": nombre, "apellidos": apellido,
            "fecha_nacimiento": nacimiento, "genero": rng.choices("FMX", weights=(49, 49, 2))[0],
            "email_contacto": f"{ascii_simple(nombre)}.{ascii_simple(apellido)}{self._contador_persona}@example.com" if con_contacto else None,
            "telefono": f"+1-{rng.randint(201, 989)}-555-01{rng.randint(0, 99):02d}" if con_contacto else None,
            "codigo_pais_nacionalidad": pais,
            "tipo_documento": tipo if documento else None,
            "numero_documento": f"{rng.randrange(10**8, 10**9)}" if documento else None,
            "codigo_pais_documento": pais if documento else None,
            "creado_utc": creado,
        }
        self.personas.append(persona)
        return persona

    def generar_clientes(self) -> list[dict]:
        rng = self.rng
        inicio, fin = INICIO_VENTAS, self.corte - timedelta(days=1)
        aeropuertos = sorted(self.ref.aeropuertos.items())
        clientes = []
        for _ in range(CLIENTES_REGISTRADOS):
            if rng.random() < 0.40:
                registro = inicio + timedelta(minutes=rng.randrange(0, 31 * 24 * 60))
            else:
                registro = inicio + timedelta(minutes=rng.randrange(31 * 24 * 60, int((fin - inicio).total_seconds() // 60)))
            persona = self._nueva_persona(registro, adulto=True, con_contacto=True)
            clientes.append({"persona": persona, "fecha_registro_utc": registro,
                             "nivel_lealtad": rng.choices(["BASICO", "PLATA", "ORO", "PLATINO"], weights=(86, 10, 3, 1))[0],
                             "acepta_marketing": 1 if rng.random() < 0.55 else 0,
                             "id_aeropuerto_preferido": rng.choice(aeropuertos)[1] if rng.random() < 0.7 else None})
        clientes.sort(key=lambda c: (c["fecha_registro_utc"], c["persona"]["clave"]))
        self.clientes = clientes
        # Pesos de selección tipo Pareto: pocos clientes compran con mucha frecuencia.
        acumulado, total = [], 0.0
        for i in range(len(clientes)):
            total += 1.0 / (1 + (i * 7919) % len(clientes)) ** 0.35
            acumulado.append(total)
        self._pesos_clientes = acumulado
        self._fechas_registro = [c["fecha_registro_utc"] for c in clientes]
        return clientes

    def _cliente_registrado_antes(self, momento: datetime) -> dict | None:
        limite = bisect.bisect_right(self._fechas_registro, momento)
        if limite == 0:
            return None
        objetivo = self.rng.random() * self._pesos_clientes[limite - 1]
        return self.clientes[bisect.bisect_left(self._pesos_clientes, objetivo, hi=limite - 1)]

    # --------------------------------------------------------------- ventas
    def _localizador(self) -> str:
        while True:
            codigo = "".join(self.rng.choice(ALFABETO_LOCALIZADOR) for _ in range(6))
            if codigo not in self.localizadores:
                self.localizadores.add(codigo)
                return codigo

    def _momento_compra(self, salida: datetime, tope: datetime) -> datetime | None:
        rng = self.rng
        r = rng.random()
        dias = rng.expovariate(1 / 6) if r < 0.30 else rng.uniform(7, 45) if r < 0.75 else rng.uniform(45, 120)
        momento = salida - timedelta(days=dias, minutes=rng.randrange(0, 600))
        momento = momento.replace(second=0, microsecond=0)
        if momento < INICIO_VENTAS:
            momento = INICIO_VENTAS + timedelta(minutes=rng.randrange(0, 14 * 24 * 60))
        limite_venta = salida - timedelta(hours=self.horas_cierre + 1)
        if momento > limite_venta:
            momento = limite_venta - timedelta(minutes=rng.randrange(0, 240))
        if momento > tope:
            return None
        return momento

    def _canal(self, origen: str) -> tuple[dict, int | None]:
        rng = self.rng
        r = rng.random()
        locs = self.ref.localizaciones
        if r < 0.46:
            loc = locs["WEB-SITIO"]
        elif r < 0.70:
            loc = locs["WEB-APP"]
        elif r < 0.90:
            loc = locs[f"AER-{origen}"]
        else:
            oficina = {"JFK": "OFI-NYC", "ORD": "OFI-CHI", "MIA": "OFI-MIA"}.get(origen) or rng.choice(["OFI-NYC", "OFI-CHI", "OFI-MIA"])
            loc = locs[oficina]
        return loc, None

    def _vendedor(self, loc: dict, momento: datetime) -> int | None:
        if loc["tipo_localizacion"] == "WEB":
            return None
        if not hasattr(self, "_agentes"):
            self._agentes = {}
            for e in self.ref.empleados:
                if e["codigo_cargo"] == "AGENTE_VTA":
                    self._agentes.setdefault(e["id_localizacion_base"], []).append(e)
        candidatos = [e for e in self._agentes.get(loc["id_localizacion"], [])
                      if e["fecha_contratacion"] <= momento.date()
                      and (e["fecha_terminacion"] is None or e["fecha_terminacion"] >= momento.date())]
        return self.rng.choice(candidatos)["id_empleado"]

    def _descuento(self, cabina: str, momento: datetime, fecha_vuelo: date, registrado: bool) -> dict | None:
        dia = momento.date()
        elegibles = [d for d in self.ref.descuentos
                     if d["vigente_desde"] <= dia <= d["vigente_hasta"]
                     and (d["codigo_cabina"] is None or d["codigo_cabina"] == cabina)
                     and (d["dias_anticipacion_min"] is None or (fecha_vuelo - dia).days >= d["dias_anticipacion_min"])
                     and (not d["solo_clientes_registrados"] or registrado)]
        if not elegibles:
            return None
        lanzamiento = any(d["codigo_descuento"] == "LANZAMIENTO20" for d in elegibles)
        if self.rng.random() < (0.55 if lanzamiento else 0.22):
            return max(elegibles, key=lambda d: (d["porcentaje"], d["codigo_descuento"]))
        return None

    def generar_ventas(self) -> None:
        ref, rng = self.ref, self.rng
        self.generar_clientes()
        vuelos = sorted(ref.vuelos, key=lambda v: (v["salida_programada_utc"], v["numero_vuelo"]))
        por_ruta_fecha: dict[tuple[str, str], list[dict]] = {}
        for v in vuelos:
            por_ruta_fecha.setdefault((v["origen"], v["destino"]), []).append(v)
        rutas_ids = sorted({v["id_ruta"] for v in vuelos})
        factor_ruta = {r: rng.uniform(0.72, 0.92) for r in rutas_ids}

        capacidad, objetivo, asignado, asientos_libres, pasajeros = {}, {}, {}, {}, {}
        for v in vuelos:
            avion = ref.aviones[v["matricula"]]
            fecha = v["fecha_salida_local"]
            mes = {9: 0.95, 10: 1.00, 11: 1.05, 12: 1.08}[fecha.month]
            if date(2026, 11, 22) <= fecha <= date(2026, 11, 29) or fecha >= date(2026, 12, 18):
                mes *= 1.12
            if fecha < date(2026, 9, 15):
                mes *= 0.85                                     # arranque de una aerolínea nueva
            pasajeros[v["id_vuelo"]] = set()
            for cabina, lista in ref.asientos[avion["id_configuracion"]].items():
                clave = (v["id_vuelo"], cabina)
                capacidad[clave] = len(lista)
                media = (factor_ruta[v["id_ruta"]] * FACTOR_DIA[dia_iso(fecha)] * mes if cabina == "ECO"
                         else 0.62 * FACTOR_DIA[dia_iso(fecha)] * (mes ** 0.5))
                ocupacion = min(1.0, max(0.2 if cabina == "ECO" else 0.0, rng.gauss(media, 0.08 if cabina == "ECO" else 0.15)))
                objetivo[clave] = round(ocupacion * len(lista))
                asignado[clave] = 0
                libres = list(lista)
                rng.shuffle(libres)
                asientos_libres[clave] = libres

        def reservar(v: dict, cabina: str, n: int, ocupados: list[dict]) -> bool:
            clave = (v["id_vuelo"], cabina)
            if asignado[clave] + n > objetivo[clave]:
                return False
            if any(p["clave"] in pasajeros[v["id_vuelo"]] for p in ocupados):
                return False
            asignado[clave] += n
            return True

        for v in vuelos:
            tope = self.corte if v["cancelacion_vuelo"] is None else min(self.corte, v["cancelacion_vuelo"] - timedelta(hours=1))
            for cabina in sorted(ref.asientos[ref.aviones[v["matricula"]]["id_configuracion"]]):
                clave = (v["id_vuelo"], cabina)
                while asignado[clave] < objetivo[clave]:
                    tamano = min(rng.choices((1, 2, 3, 4), weights=(62, 25, 9, 4))[0], objetivo[clave] - asignado[clave])
                    momento = self._momento_compra(v["salida_programada_utc"], tope)
                    if momento is None:
                        asignado[clave] += tamano                # demanda que aún no se ha vendido a la fecha de corte
                        continue
                    if not self._crear_compra(v, cabina, tamano, momento, por_ruta_fecha, reservar, asientos_libres, pasajeros):
                        asignado[clave] += tamano                # conflicto de pasajero: demanda perdida

    def _crear_compra(self, v, cabina, tamano, momento, por_ruta_fecha, reservar, asientos_libres, pasajeros):
        rng, ref = self.rng, self.ref
        personas_previas = len(self.personas)
        loc, _ = self._canal(v["origen"])
        registrado = rng.random() < PROB_COMPRADOR_REGISTRADO
        cliente = self._cliente_registrado_antes(momento) if registrado else None
        comprador = cliente["persona"] if cliente else self._nueva_persona(momento, con_contacto=True)
        es_registrado = cliente is not None
        viajeros = []
        if rng.random() < 0.85 and comprador["clave"] not in pasajeros[v["id_vuelo"]]:
            viajeros.append(comprador)
        while len(viajeros) < tamano:
            acompanante = None
            if rng.random() < 0.10:
                c = self._cliente_registrado_antes(momento)
                if c and c["persona"]["clave"] not in pasajeros[v["id_vuelo"]] and c["persona"] not in viajeros:
                    acompanante = c["persona"]
            viajeros.append(acompanante or self._nueva_persona(momento, adulto=rng.random() > 0.2))
        if not reservar(v, cabina, len(viajeros), viajeros):
            del self.personas[personas_previas:]
            return False
        compra = {"codigo_reserva": self._localizador(), "comprador": comprador, "id_localizacion_venta": loc["id_localizacion"],
                  "tipo_localizacion": loc["tipo_localizacion"], "id_empleado_vendedor": self._vendedor(loc, momento),
                  "fecha_compra_utc": momento, "email_confirmacion": comprador["email_contacto"]}
        self.compras.append(compra)
        descuento = self._descuento(cabina, momento, v["fecha_salida_local"], es_registrado)
        tramos = [(v, descuento)]
        # Ida y vuelta: mismo grupo en un vuelo de regreso 2 a 10 días después.
        if rng.random() < PROB_IDA_Y_VUELTA:
            candidatos = [r for r in por_ruta_fecha.get((v["destino"], v["origen"]), [])
                          if timedelta(days=2) <= r["salida_programada_utc"] - v["salida_programada_utc"] <= timedelta(days=10)
                          and r["cancelacion_vuelo"] is None]
            if candidatos:
                regreso = rng.choice(candidatos)
                if momento < regreso["salida_programada_utc"] - timedelta(hours=self.horas_cierre + 1) and reservar(regreso, cabina, len(viajeros), viajeros):
                    d2 = descuento if descuento and self._descuento_aplica(descuento, cabina, momento, regreso["fecha_salida_local"], es_registrado) else None
                    tramos.append((regreso, d2))
        for vuelo, desc in tramos:
            for persona in viajeros:
                pasajeros[vuelo["id_vuelo"]].add(persona["clave"])
                self._crear_tiquete(compra, vuelo, cabina, persona, desc, asientos_libres)
        return True

    def _descuento_aplica(self, d, cabina, momento, fecha_vuelo, registrado) -> bool:
        dia = momento.date()
        return (d["vigente_desde"] <= dia <= d["vigente_hasta"] and (d["codigo_cabina"] in (None, cabina))
                and (d["dias_anticipacion_min"] is None or (fecha_vuelo - dia).days >= d["dias_anticipacion_min"])
                and (not d["solo_clientes_registrados"] or registrado))

    def _crear_tiquete(self, compra, vuelo, cabina, persona, descuento, asientos_libres):
        rng = self.rng
        momento = compra["fecha_compra_utc"]
        id_tarifa, base = tarifa_vigente(self.ref, vuelo["id_ruta"], cabina, momento.date())
        porcentaje = descuento["porcentaje"] if descuento else Decimal("0.00")
        salida = vuelo["salida_programada_utc"]
        limite = min(momento + timedelta(hours=self.horas_limite), salida - timedelta(hours=self.horas_cierre))
        asiento = asientos_libres[(vuelo["id_vuelo"], cabina)].pop() if rng.random() < PROB_ASIENTO_EN_COMPRA else None
        tiquete = {"compra": compra, "vuelo": vuelo, "codigo_cabina": cabina, "pasajero": persona, "codigo_asiento": asiento,
                   "id_tarifa": id_tarifa, "precio_base_usd": base, "id_descuento": descuento["id_descuento"] if descuento else None,
                   "porcentaje_descuento": porcentaje, "precio_final": precio_final(base, porcentaje),
                   "creado_utc": momento, "fecha_limite_pago_utc": limite, "estado_final": "RESERVADO",
                   "fecha_emision_utc": None, "fecha_cancelacion_utc": None, "codigo_motivo_cancelacion": None, "pagos": []}
        self.tiquetes.append(tiquete)

    # ---------------------------------------------------------------- pagos
    def _metodo(self, tipo_localizacion: str) -> str:
        if tipo_localizacion == "WEB":
            return self.rng.choices(["TC", "TD", "BILLETERA"], weights=(68, 22, 10))[0]
        return self.rng.choices(["TC", "TD", "EFECTIVO", "BILLETERA"], weights=(48, 24, 22, 6))[0]

    def _pago(self, t: dict, monto: Decimal, momento: datetime, estado: str, metodo: str | None = None,
              id_localizacion: int | None = None, tipo_localizacion: str | None = None) -> dict:
        rng = self.rng
        compra = t["compra"]
        tipo_localizacion = tipo_localizacion or compra["tipo_localizacion"]
        metodo = metodo or self._metodo(tipo_localizacion)
        tarjeta = metodo in ("TC", "TD")
        pago = {"tiquete": t, "codigo_metodo": metodo,
                "id_localizacion_cobro": id_localizacion or compra["id_localizacion_venta"], "monto_usd": monto,
                "estado_inicial": estado, "estado_final": estado, "fecha_creacion_utc": momento,
                "fecha_resolucion_utc": None if estado == "PENDIENTE" else momento,
                "referencia_autorizacion": f"AUT{rng.randrange(16**10):010X}" if estado == "CONFIRMADO" else None,
                "ultimos4_tarjeta": f"{rng.randrange(10000):04d}" if tarjeta else None,
                "marca_tarjeta": rng.choices(["VISA", "MASTERCARD", "AMEX", "DISCOVER"], weights=(50, 30, 15, 5))[0] if tarjeta else None,
                "motivo_rechazo": rng.choice(MOTIVOS_RECHAZO) if estado == "FALLIDO" else None}
        t["pagos"].append(pago)
        return pago

    def generar_pagos_y_estados(self) -> None:
        rng = self.rng
        web = self.ref.localizaciones["WEB-SITIO"]
        for t in sorted(self.tiquetes, key=lambda x: (x["creado_utc"], x["compra"]["codigo_reserva"], x["vuelo"]["id_vuelo"], x["pasajero"]["clave"])):
            inicio, limite, precio = t["creado_utc"], t["fecha_limite_pago_utc"], t["precio_final"]
            fin_ventana = min(limite, self.corte)
            r = rng.random()
            abandona = rng.random() < PROB_ABANDONO
            momento = inicio + timedelta(minutes=rng.randint(1, 10))
            completo_en = None
            if r < 0.06 and momento < fin_ventana:                    # intento fallido y luego aprobado
                self._pago(t, precio, momento, "FALLIDO")
                momento += timedelta(minutes=rng.randint(3, 30))
            plan = "unico" if r < 0.86 else "dos" if r < 0.96 else "tres" if r < 0.99 else "pendiente"
            if abandona:
                if plan != "unico" and momento < fin_ventana:
                    self._pago(t, redondear(precio * Decimal(rng.uniform(0.3, 0.5))), momento, "CONFIRMADO")
            elif plan == "pendiente" and momento < fin_ventana and self.corte - momento < timedelta(hours=6):
                self._pago(t, precio, momento, "PENDIENTE")             # respuesta asíncrona aún no recibida
            elif plan in ("unico", "pendiente"):
                if momento < fin_ventana:
                    self._pago(t, precio, momento, "CONFIRMADO")
                    completo_en = momento
            else:
                # Pagos parciales: instantes distintos dentro del plazo de pago (al menos 60 min entre sí).
                partes = 2 if plan == "dos" else 3
                ventana = int((limite - momento).total_seconds() // 60) - 10
                if ventana < 60 * partes:
                    partes = 1
                instantes = [momento] + sorted(momento + timedelta(minutes=m)
                                               for m in rng.sample(range(60, ventana, 60), partes - 1)) if partes > 1 else [momento]
                restante = precio
                for parte, instante in enumerate(instantes):
                    if instante >= fin_ventana:
                        break                                   # el resto aún no se ha pagado a la fecha de corte
                    monto = restante if parte == partes - 1 else redondear(restante * Decimal(rng.uniform(0.3, 0.6)))
                    loc = None if parte == 0 else web
                    metodo = None if parte == 0 else rng.choices(["TC", "TD", "BILLETERA"], weights=(68, 22, 10))[0]
                    self._pago(t, monto, instante, "CONFIRMADO", metodo=metodo,
                               id_localizacion=loc["id_localizacion"] if loc else None,
                               tipo_localizacion=loc["tipo_localizacion"] if loc else None)
                    restante -= monto
                    if restante == 0:
                        completo_en = instante
            cancelacion_vuelo = t["vuelo"]["cancelacion_vuelo"]
            if completo_en is not None:
                t["estado_final"], t["fecha_emision_utc"] = "EMITIDO", completo_en
            elif limite <= self.corte and not (cancelacion_vuelo is not None and cancelacion_vuelo <= limite):
                self._cancelar(t, "VENCIMIENTO", limite)

        # Cancelaciones de vuelos (reembolso total de lo cobrado).
        for t in self.tiquetes:
            cancel = t["vuelo"]["cancelacion_vuelo"]
            if cancel is not None and t["estado_final"] in ("RESERVADO", "EMITIDO"):
                self._cancelar(t, "VUELO_CANCELADO", max(cancel, t["creado_utc"]))
        # Cancelaciones voluntarias (30 % dentro de las primeras 24 horas).
        for t in self.tiquetes:
            if t["estado_final"] not in ("RESERVADO", "EMITIDO") or rng.random() >= PROB_CANCELACION_VOLUNTARIA:
                continue
            salida = t["vuelo"]["salida_programada_utc"]
            desde = t["creado_utc"] + timedelta(minutes=30)
            hasta = min(salida - timedelta(hours=4), self.corte - timedelta(minutes=1))
            if rng.random() < 0.30:
                hasta = min(hasta, t["creado_utc"] + timedelta(hours=23))
            if hasta <= desde:
                continue
            momento = desde + timedelta(minutes=rng.randrange(0, int((hasta - desde).total_seconds() // 60)))
            self._cancelar(t, "VOLUNTARIA", momento)
        # Abordaje en vuelos que ya salieron.
        for t in self.tiquetes:
            if t["estado_final"] == "EMITIDO" and t["vuelo"]["estado_final"] in ("EN_VUELO", "ATERRIZADO"):
                t["estado_final"] = "NO_PRESENTADO" if rng.random() < PROB_NO_PRESENTADO else "USADO"

    def _cancelar(self, t: dict, motivo: str, momento: datetime) -> None:
        # Lo posterior a la cancelación no ocurrió; lo pendiente se anula.
        t["pagos"] = [p for p in t["pagos"] if p["fecha_creacion_utc"] <= momento]
        if t["fecha_emision_utc"] is not None and t["fecha_emision_utc"] > momento:
            t["fecha_emision_utc"] = None
        for p in t["pagos"]:
            if p["estado_inicial"] == "PENDIENTE":
                p["estado_final"], p["fecha_resolucion_utc"] = "ANULADO", momento
        t["estado_final"], t["fecha_cancelacion_utc"], t["codigo_motivo_cancelacion"] = "CANCELADO", momento, motivo
        politica = politica_reembolso(self.ref, t["codigo_cabina"], motivo, t["creado_utc"], t["vuelo"]["salida_programada_utc"], momento)
        assert politica is not None, "cancelación sin política aplicable"
        porcentaje, regla = politica
        confirmados = [p for p in t["pagos"] if p["estado_inicial"] == "CONFIRMADO"]
        cobrado = sum((p["monto_usd"] for p in confirmados), Decimal("0.00"))
        total = redondear(cobrado * porcentaje / Decimal(100))
        t["reembolso"] = (porcentaje, regla, total)
        if total <= 0:
            return
        acumulado = Decimal("0.00")
        # Mismo orden que el procedimiento: del pago más reciente al más antiguo.
        for orden, p in sorted(enumerate(confirmados), key=lambda x: (x[1]["fecha_resolucion_utc"], x[0]), reverse=True):
            if acumulado >= total:
                break
            monto = min(p["monto_usd"], total - acumulado)
            acumulado += monto
            self.reembolsos.append({"pago": p, "monto_usd": monto, "fecha_reembolso_utc": momento, "codigo_motivo": motivo,
                                    "porcentaje_aplicado": porcentaje, "regla_aplicada": regla})

    # ------------------------------------------------------------ salida
    def generar(self) -> Resultado:
        plan, tripulacion, eventos = self.planificar_operacion()
        self.generar_ventas()
        self.generar_pagos_y_estados()
        return self._numerar(plan, tripulacion, eventos)

    def _numerar(self, plan, tripulacion, eventos) -> Resultado:
        """Asigna identificadores deterministas en orden cronológico."""
        personas = sorted(self.personas, key=lambda p: (p["creado_utc"], p["clave"]))
        for i, p in enumerate(personas, start=1):
            p["id_persona"] = i
        compras = sorted(self.compras, key=lambda c: (c["fecha_compra_utc"], c["codigo_reserva"]))
        for i, c in enumerate(compras, start=1):
            c["id_compra"] = i
        tiquetes = sorted(self.tiquetes, key=lambda t: (t["creado_utc"], t["compra"]["id_compra"], t["vuelo"]["salida_programada_utc"], t["pasajero"]["id_persona"]))
        for i, t in enumerate(tiquetes, start=1):
            t["id_tiquete"], t["numero_tiquete"] = i, f"000{i:010d}"
        pagos = sorted((p for t in tiquetes for p in t["pagos"]), key=lambda p: (p["fecha_creacion_utc"], p["tiquete"]["id_tiquete"]))
        for i, p in enumerate(pagos, start=1):
            p["id_pago"] = i
        reembolsos = sorted(self.reembolsos, key=lambda r: (r["fecha_reembolso_utc"], r["pago"]["id_pago"]))
        for i, r in enumerate(reembolsos, start=1):
            r["id_reembolso"] = i

        tablas = {
            "vuelo_plan": plan,
            "tripulacion": tripulacion,
            "vuelo_evento": eventos,
            "persona": [{k: p[k] for k in ("id_persona", "nombres", "apellidos", "fecha_nacimiento", "genero", "email_contacto",
                                           "telefono", "codigo_pais_nacionalidad", "tipo_documento", "numero_documento",
                                           "codigo_pais_documento", "creado_utc")} for p in personas],
            "cliente": [{"id_persona": c["persona"]["id_persona"], "numero_viajero": f"VF{i:08d}",
                         "email_acceso": c["persona"]["email_contacto"], "fecha_registro_utc": c["fecha_registro_utc"],
                         "nivel_lealtad": c["nivel_lealtad"], "acepta_marketing": c["acepta_marketing"],
                         "id_aeropuerto_preferido": c["id_aeropuerto_preferido"]} for i, c in enumerate(self.clientes, start=1)],
            "compra": [{"id_compra": c["id_compra"], "codigo_reserva": c["codigo_reserva"], "id_persona_comprador": c["comprador"]["id_persona"],
                        "id_localizacion_venta": c["id_localizacion_venta"], "id_empleado_vendedor": c["id_empleado_vendedor"],
                        "fecha_compra_utc": c["fecha_compra_utc"], "email_confirmacion": c["email_confirmacion"]} for c in compras],
            "tiquete": [{"id_tiquete": t["id_tiquete"], "numero_tiquete": t["numero_tiquete"], "id_compra": t["compra"]["id_compra"],
                         "id_vuelo": t["vuelo"]["id_vuelo"], "codigo_cabina": t["codigo_cabina"], "id_persona_pasajero": t["pasajero"]["id_persona"],
                         "codigo_asiento": t["codigo_asiento"], "id_tarifa": t["id_tarifa"], "precio_base_usd": t["precio_base_usd"],
                         "id_descuento": t["id_descuento"], "porcentaje_descuento": t["porcentaje_descuento"],
                         "fecha_limite_pago_utc": t["fecha_limite_pago_utc"], "creado_utc": t["creado_utc"], "estado_final": t["estado_final"],
                         "fecha_emision_utc": t["fecha_emision_utc"], "fecha_cancelacion_utc": t["fecha_cancelacion_utc"],
                         "codigo_motivo_cancelacion": t["codigo_motivo_cancelacion"]} for t in tiquetes],
            "pago": [{"id_pago": p["id_pago"], "id_tiquete": p["tiquete"]["id_tiquete"], "codigo_metodo": p["codigo_metodo"],
                      "id_localizacion_cobro": p["id_localizacion_cobro"], "monto_usd": p["monto_usd"], "estado_inicial": p["estado_inicial"],
                      "estado_final": p["estado_final"], "fecha_creacion_utc": p["fecha_creacion_utc"],
                      "fecha_resolucion_utc": p["fecha_resolucion_utc"], "referencia_autorizacion": p["referencia_autorizacion"],
                      "ultimos4_tarjeta": p["ultimos4_tarjeta"], "marca_tarjeta": p["marca_tarjeta"], "motivo_rechazo": p["motivo_rechazo"]}
                     for p in pagos],
            "reembolso": [{"id_reembolso": r["id_reembolso"], "id_pago": r["pago"]["id_pago"], "monto_usd": r["monto_usd"],
                           "fecha_reembolso_utc": r["fecha_reembolso_utc"], "codigo_motivo": r["codigo_motivo"],
                           "porcentaje_aplicado": r["porcentaje_aplicado"], "regla_aplicada": r["regla_aplicada"],
                           "referencia": f"RB{r['pago']['id_pago']}"} for r in reembolsos],
        }
        resumen = {"semilla": self.semilla, "fecha_corte_utc": self.corte.isoformat(),
                   "filas": {k: len(v) for k, v in tablas.items()}}
        return Resultado(tablas, resumen)


# --------------------------------------------------------------------------
# CSV y carga
# --------------------------------------------------------------------------
COLUMNAS_STAGING = {
    "vuelo_plan": ["id_vuelo", "id_avion"],
    "tripulacion": ["id_vuelo", "id_empleado", "rol_vuelo"],
    "vuelo_evento": ["id_vuelo", "estado_final", "salida_estimada_utc", "salida_real_utc", "llegada_real_utc", "motivo_cancelacion"],
    "persona": ["id_persona", "nombres", "apellidos", "fecha_nacimiento", "genero", "email_contacto", "telefono",
                "codigo_pais_nacionalidad", "tipo_documento", "numero_documento", "codigo_pais_documento", "creado_utc"],
    "cliente": ["id_persona", "numero_viajero", "email_acceso", "fecha_registro_utc", "nivel_lealtad", "acepta_marketing",
                "id_aeropuerto_preferido"],
    "compra": ["id_compra", "codigo_reserva", "id_persona_comprador", "id_localizacion_venta", "id_empleado_vendedor",
               "fecha_compra_utc", "email_confirmacion"],
    "tiquete": ["id_tiquete", "numero_tiquete", "id_compra", "id_vuelo", "codigo_cabina", "id_persona_pasajero", "codigo_asiento",
                "id_tarifa", "precio_base_usd", "id_descuento", "porcentaje_descuento", "fecha_limite_pago_utc", "creado_utc",
                "estado_final", "fecha_emision_utc", "fecha_cancelacion_utc", "codigo_motivo_cancelacion"],
    "pago": ["id_pago", "id_tiquete", "codigo_metodo", "id_localizacion_cobro", "monto_usd", "estado_inicial", "estado_final",
             "fecha_creacion_utc", "fecha_resolucion_utc", "referencia_autorizacion", "ultimos4_tarjeta", "marca_tarjeta",
             "motivo_rechazo"],
    "reembolso": ["id_reembolso", "id_pago", "monto_usd", "fecha_reembolso_utc", "codigo_motivo", "porcentaje_aplicado",
                  "regla_aplicada", "referencia"],
}


def _texto(valor) -> str:
    if valor is None:
        return ""
    if isinstance(valor, datetime):
        return valor.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(valor, date):
        return valor.isoformat()
    return str(valor)


def escribir_csv(resultado: Resultado, directorio: Path) -> dict:
    directorio.mkdir(parents=True, exist_ok=True)
    manifiesto = {"resumen": resultado.resumen, "archivos": {}}
    for tabla, columnas in COLUMNAS_STAGING.items():
        ruta = directorio / f"{tabla}.csv"
        with ruta.open("w", encoding="utf-8", newline="") as f:
            escritor = csv.writer(f, lineterminator="\n")
            escritor.writerow(columnas)
            for fila in resultado.tablas[tabla]:
                escritor.writerow([_texto(fila[c]) for c in columnas])
        manifiesto["archivos"][ruta.name] = {"filas": len(resultado.tablas[tabla]),
                                             "sha256": hashlib.sha256(ruta.read_bytes()).hexdigest()}
    (directorio / "manifiesto.json").write_text(json.dumps(manifiesto, indent=2, ensure_ascii=False), encoding="utf-8")
    return manifiesto


def _convertir(columna: str, texto: str):
    if texto == "":
        return None
    if columna.endswith("_utc"):
        return datetime.strptime(texto, "%Y-%m-%d %H:%M:%S")
    if columna.startswith("fecha_"):
        return date.fromisoformat(texto)
    if columna.endswith("_usd") or columna.startswith("porcentaje"):
        return Decimal(texto)
    if columna.startswith("id_") or columna == "acepta_marketing":
        return int(texto)
    return texto


def cargar_staging(conexion: pyodbc.Connection, directorio: Path, eco=print, lote: int = 20000) -> None:
    cursor = conexion.cursor()
    cursor.fast_executemany = True
    ejecutar(cursor, "EXEC stg.usp_vaciar_staging;")
    for tabla, columnas in COLUMNAS_STAGING.items():
        sql = f"INSERT stg.{tabla} ({', '.join(columnas)}) VALUES ({', '.join('?' * len(columnas))})"
        total = 0
        with (directorio / f"{tabla}.csv").open(encoding="utf-8", newline="") as f:
            lector = csv.reader(f)
            next(lector)
            bloque = []
            for fila in lector:
                bloque.append([_convertir(c, v) for c, v in zip(columnas, fila)])
                if len(bloque) >= lote:
                    cursor.executemany(sql, bloque)
                    total += len(bloque)
                    bloque = []
            if bloque:
                cursor.executemany(sql, bloque)
                total += len(bloque)
        conexion.commit()
        eco(f"  stg.{tabla:<13} {total:>8} filas")
