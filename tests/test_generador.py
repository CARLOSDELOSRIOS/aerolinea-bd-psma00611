"""Réplica en Python de la política de reembolso (debe coincidir con ven.fn_politica_reembolso)."""
from datetime import datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace

from aerolinea.generador import politica_reembolso

REF = SimpleNamespace(politicas={"ECO": [(336, Decimal("80")), (72, Decimal("50")), (0, Decimal("0"))],
                                 "VIP": [(168, Decimal("90")), (24, Decimal("70")), (0, Decimal("30"))]})
VENTA = datetime(2026, 10, 1, 12, 0)
SALIDA = datetime(2026, 10, 20, 15, 0)


def test_vuelo_cancelado_reembolso_total():
    assert politica_reembolso(REF, "ECO", "VUELO_CANCELADO", VENTA, SALIDA, SALIDA) == (Decimal("100.00"), "REEMBOLSO_TOTAL")


def test_regla_24_horas_con_7_dias_de_anticipacion():
    assert politica_reembolso(REF, "ECO", "VOLUNTARIA", VENTA, SALIDA, VENTA + timedelta(hours=23)) == (Decimal("100.00"), "REGLA_24H")


def test_regla_24_horas_no_aplica_si_faltan_menos_de_7_dias():
    salida = VENTA + timedelta(days=5)
    assert politica_reembolso(REF, "ECO", "VOLUNTARIA", VENTA, salida, VENTA + timedelta(hours=2))[1] == "POLITICA_CABINA"


def test_tramos_por_cabina():
    assert politica_reembolso(REF, "ECO", "VOLUNTARIA", VENTA, SALIDA, SALIDA - timedelta(hours=48)) == (Decimal("0"), "POLITICA_CABINA")
    assert politica_reembolso(REF, "ECO", "VOLUNTARIA", VENTA, SALIDA, SALIDA - timedelta(hours=100)) == (Decimal("50"), "POLITICA_CABINA")
    assert politica_reembolso(REF, "VIP", "VOLUNTARIA", VENTA, SALIDA, SALIDA - timedelta(days=10)) == (Decimal("90"), "POLITICA_CABINA")
