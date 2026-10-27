"""Invocación de procedimientos almacenados desde Python.

pyodbc no admite parámetros OUTPUT de forma directa: se usa el patrón
    DECLARE @x ...; EXEC proc ..., @x = @x OUTPUT; SELECT @x;
con todos los valores de entrada enviados como parámetros enlazados (?).
"""
from __future__ import annotations

from decimal import Decimal

from .config import ConfigBD
from .db import ErrorBaseDatos, conectar, ejecutar

SQL_EMITIR = """
DECLARE @id_compra INT, @id_tiquete INT, @numero CHAR(13), @reserva CHAR(6), @precio DECIMAL(10,2);
EXEC ven.usp_emitir_tiquete @id_vuelo = ?, @codigo_cabina = ?, @id_persona_pasajero = ?, @id_persona_comprador = ?,
     @id_localizacion_venta = ?, @id_empleado_vendedor = ?, @codigo_descuento = ?, @codigo_asiento = ?,
     @id_compra = @id_compra OUTPUT, @id_tiquete = @id_tiquete OUTPUT, @numero_tiquete = @numero OUTPUT,
     @codigo_reserva = @reserva OUTPUT, @precio_final_usd = @precio OUTPUT;
SELECT @id_compra AS id_compra, @id_tiquete AS id_tiquete, @numero AS numero_tiquete, @reserva AS codigo_reserva,
       @precio AS precio_final_usd;
"""

SQL_PAGO = """
DECLARE @id_pago INT, @saldo DECIMAL(10,2), @estado VARCHAR(15);
EXEC ven.usp_registrar_pago @id_tiquete = ?, @codigo_metodo = ?, @monto_usd = ?, @id_localizacion_cobro = ?,
     @resultado = ?, @ultimos4_tarjeta = ?, @marca_tarjeta = ?,
     @id_pago = @id_pago OUTPUT, @saldo_pendiente_usd = @saldo OUTPUT, @estado_tiquete = @estado OUTPUT;
SELECT @id_pago AS id_pago, @saldo AS saldo_pendiente_usd, @estado AS estado_tiquete;
"""

SQL_CANCELAR = """
DECLARE @reembolso DECIMAL(10,2), @retenido DECIMAL(10,2), @regla VARCHAR(20), @porcentaje DECIMAL(5,2);
EXEC ven.usp_cancelar_tiquete @id_tiquete = ?, @codigo_motivo = ?,
     @monto_reembolsado_usd = @reembolso OUTPUT, @monto_retenido_usd = @retenido OUTPUT,
     @regla_aplicada = @regla OUTPUT, @porcentaje_reembolso = @porcentaje OUTPUT;
SELECT @reembolso AS monto_reembolsado_usd, @retenido AS monto_retenido_usd, @regla AS regla_aplicada,
       @porcentaje AS porcentaje_reembolso;
"""


def _fila(cursor, sql: str, parametros: tuple) -> dict:
    columnas, filas = ejecutar(cursor, sql, parametros)[-1]
    return dict(zip(columnas, filas[0]))


def emitir_tiquete(cfg: ConfigBD, *, id_vuelo: int, cabina: str, id_pasajero: int, id_comprador: int,
                   id_localizacion: int, id_vendedor: int | None = None, descuento: str | None = None,
                   asiento: str | None = None) -> dict:
    with conectar(cfg, autocommit=True) as conexion:
        return _fila(conexion.cursor(), SQL_EMITIR,
                     (id_vuelo, cabina, id_pasajero, id_comprador, id_localizacion, id_vendedor, descuento, asiento))


def registrar_pago(cfg: ConfigBD, *, id_tiquete: int, metodo: str, monto: Decimal, id_localizacion: int,
                   resultado: str = "CONFIRMADO", ultimos4: str | None = None, marca: str | None = None) -> dict:
    with conectar(cfg, autocommit=True) as conexion:
        return _fila(conexion.cursor(), SQL_PAGO, (id_tiquete, metodo, monto, id_localizacion, resultado, ultimos4, marca))


def cancelar_tiquete(cfg: ConfigBD, *, id_tiquete: int, motivo: str = "VOLUNTARIA") -> dict:
    with conectar(cfg, autocommit=True) as conexion:
        return _fila(conexion.cursor(), SQL_CANCELAR, (id_tiquete, motivo))


def _vuelo_demo(cursor, eco) -> int:
    vuelo = ejecutar(cursor, """
        SELECT TOP (1) o.id_vuelo, o.codigo_vuelo, o.ruta, CONVERT(VARCHAR(30), v.salida_programada, 126), o.plazas_disponibles
        FROM rpt.v_ocupacion_vuelo_cabina AS o JOIN rpt.v_vuelo AS v ON v.id_vuelo = o.id_vuelo
        WHERE o.codigo_cabina = 'ECO' AND o.estado_vuelo = 'PROGRAMADO' AND o.plazas_disponibles > 0
          AND v.salida_programada_utc > DATEADD(DAY, 8, SYSUTCDATETIME())
        ORDER BY v.salida_programada_utc;""")[0][1]
    if vuelo:
        eco(f"   Vuelo: {vuelo[0][1]} {vuelo[0][2]}, salida {vuelo[0][3]} (plazas ECO libres: {vuelo[0][4]})")
        return vuelo[0][0]
    (_, filas), = ejecutar(cursor, "DECLARE @v INT; EXEC tst.usp_preparar_escenario @numero_vuelo = 9950, @id_vuelo = @v OUTPUT; SELECT @v;")
    eco(f"   No hay vuelos futuros en los datos: se crea el vuelo de demostración {filas[0][0]} (BOS-ORD)")
    return filas[0][0]


def _reserva_sin_registro(cursor, id_vuelo: int, web: int) -> dict:
    (_, filas), = ejecutar(cursor, """DECLARE @p INT;
        EXEC ven.usp_registrar_persona @nombres = N'Demo', @apellidos = N'Sin Registro', @fecha_nacimiento = '19880412',
             @genero = 'F', @email_contacto = 'demo@example.com', @id_persona = @p OUTPUT; SELECT @p;""")
    persona = filas[0][0]
    t = _fila(cursor, SQL_EMITIR, (id_vuelo, "ECO", persona, persona, web, None, None, None))
    t["id_persona"] = persona
    return t


def demostracion(cfg: ConfigBD, confirmar: bool = False, eco=print) -> None:
    """Demostración en vivo en dos transacciones.

    A. Atomicidad: un error de negocio dentro de un procedimiento (SET XACT_ABORT ON + THROW) revierte
       TODA la transacción del llamador, no solo la sentencia que falló.
    B. Flujo completo (compra sin registro, pago en dos partes, emisión, cancelación y reembolso), que se
       revierte al final para no alterar los datos sobre los que se calcularon los resultados del informe.
    """
    with conectar(cfg, autocommit=False) as conexion:
        cursor = conexion.cursor()
        web = ejecutar(cursor, "SELECT id_localizacion FROM ref.localizacion WHERE codigo_localizacion = 'WEB-SITIO';")[0][1][0][0]

        eco("A. Atomicidad: un error de negocio revierte toda la transacción")
        id_vuelo = _vuelo_demo(cursor, eco)
        t = _reserva_sin_registro(cursor, id_vuelo, web)
        eco(f"A1. Persona {t['id_persona']} sin cuenta; tiquete {t['numero_tiquete']} RESERVADO por {t['precio_final_usd']} USD")
        abono = (Decimal(t["precio_final_usd"]) * Decimal("0.4")).quantize(Decimal("0.01"))
        p = _fila(cursor, SQL_PAGO, (t["id_tiquete"], "TC", abono, web, "CONFIRMADO", "4242", "VISA"))
        eco(f"A2. Pago parcial {abono} USD -> saldo {p['saldo_pendiente_usd']} USD")
        try:
            _fila(cursor, SQL_PAGO, (t["id_tiquete"], "TC", Decimal("9999.00"), web, "CONFIRMADO", "4242", "VISA"))
            eco("A3. INESPERADO: el sobrepago fue aceptado")
        except ErrorBaseDatos as exc:
            eco(f"A3. Sobrepago rechazado por la base: [{exc.numero}] {exc.mensaje}")
        ejecutar(cursor, "IF @@TRANCOUNT > 0 ROLLBACK;")
        quedan = ejecutar(cursor, "SELECT COUNT(*) FROM ven.tiquete WHERE id_tiquete = ?;", (t["id_tiquete"],))[0][1][0][0]
        eco(f"A4. Después del error, filas del tiquete {t['numero_tiquete']}: {quedan} "
            "(se revirtieron la persona, la reserva y el pago parcial: no quedan operaciones a medias)")
        ejecutar(cursor, "IF @@TRANCOUNT > 0 ROLLBACK;")

        eco("B. Flujo completo: compra sin registro, pago en dos partes, emisión y cancelación")
        id_vuelo = _vuelo_demo(cursor, eco)
        t = _reserva_sin_registro(cursor, id_vuelo, web)
        eco(f"B1. Tiquete {t['numero_tiquete']} (reserva {t['codigo_reserva']}) RESERVADO; precio final {t['precio_final_usd']} USD")
        abono = (Decimal(t["precio_final_usd"]) * Decimal("0.4")).quantize(Decimal("0.01"))
        p = _fila(cursor, SQL_PAGO, (t["id_tiquete"], "TC", abono, web, "CONFIRMADO", "4242", "VISA"))
        eco(f"B2. Pago parcial con tarjeta {abono} USD -> estado {p['estado_tiquete']}, saldo {p['saldo_pendiente_usd']} USD")
        p = _fila(cursor, SQL_PAGO, (t["id_tiquete"], "BILLETERA", Decimal(p["saldo_pendiente_usd"]), web, "CONFIRMADO", None, None))
        eco(f"B3. Pago del saldo con billetera -> estado {p['estado_tiquete']}, saldo {p['saldo_pendiente_usd']} USD")
        c = _fila(cursor, SQL_CANCELAR, (t["id_tiquete"], "VOLUNTARIA"))
        eco(f"B4. Cancelación voluntaria: regla {c['regla_aplicada']} ({c['porcentaje_reembolso']} %), "
            f"reembolso {c['monto_reembolsado_usd']} USD, retenido {c['monto_retenido_usd']} USD")
        columnas, filas = ejecutar(cursor, "SELECT * FROM rpt.v_tiquete_financiero WHERE id_tiquete = ?;", (t["id_tiquete"],))[0]
        eco("B5. Situación financiera: " + ", ".join(f"{k}={v}" for k, v in zip(columnas, filas[0])
                                                    if k in ("codigo_estado", "precio_final_usd", "cobrado_usd", "reembolsado_usd", "penalidad_retenida_usd")))
        if confirmar:
            conexion.commit()
            eco("Cambios CONFIRMADOS.")
        else:
            conexion.rollback()
            eco("Demostración revertida (ROLLBACK): los datos del informe no cambian.")
