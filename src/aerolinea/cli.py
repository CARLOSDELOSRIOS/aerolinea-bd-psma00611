"""Aplicación de consola del proyecto.

Uso:  python -m aerolinea <comando> [opciones]      (ver --help de cada comando)
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

from .config import RAIZ_PROYECTO, ErrorConfiguracion, cargar_config
from .db import ErrorBaseDatos


def _cfg(args):
    return cargar_config(args.env)


def _dir_evidencia(args) -> Path:
    return Path(args.evidencia) if args.evidencia else RAIZ_PROYECTO / "evidence" / "local"


def cmd_verificar_conexion(args) -> None:
    import dataclasses
    from .despliegue import guardar_json, informacion_entorno
    cfg = _cfg(args)
    try:
        datos = informacion_entorno(cfg)
    except ErrorBaseDatos as exc:
        if exc.numero != 4060 or cfg.es_azure:      # 4060: la base indicada no existe o no se puede abrir
            raise
        print(f"  La base '{cfg.base_datos}' aún no existe: se verifica la instancia conectando a master.")
        datos = informacion_entorno(dataclasses.replace(cfg, base_datos="master"))
    for clave, valor in datos.items():
        print(f"  {clave:<22} {valor}")
    ruta = guardar_json(datos, _dir_evidencia(args) / "verificacion_conexion.json")
    print(f"Evidencia guardada en {ruta}")


def cmd_desplegar(args) -> None:
    from .despliegue import SCRIPTS_BASE, crear_base_local, desplegar
    cfg = _cfg(args)
    if args.crear_bd:
        crear_base_local(cfg)
    desplegar(cfg, args.solo or SCRIPTS_BASE)


def cmd_reiniciar_local(args) -> None:
    from .despliegue import SCRIPTS_BASE, crear_base_local, desplegar, eliminar_base_local
    if not args.confirmar_destruccion:
        sys.exit("Operación destructiva: agregue --confirmar-destruccion para eliminar y recrear la base LOCAL.")
    cfg = _cfg(args)
    eliminar_base_local(cfg)
    crear_base_local(cfg)
    desplegar(cfg, SCRIPTS_BASE)


def cmd_cargar_datos(args) -> None:
    from .carga import cargar_datos
    from .despliegue import guardar_json
    corte = datetime.fromisoformat(args.corte) if args.corte else None
    kwargs = {"semilla": args.semilla}
    if corte:
        kwargs["fecha_corte"] = corte
    manifiesto = cargar_datos(_cfg(args), **kwargs)
    guardar_json(manifiesto, _dir_evidencia(args) / "carga_sintetica.json")


def cmd_consultas(args) -> None:
    from .consultas import ejecutar_catalogo
    parametros = dict(p.split("=", 1) for p in (args.param or []))
    ejecutar_catalogo(_cfg(args), ids=args.id, parametros=parametros,
                      salida=Path(args.salida) if args.salida else None)


def cmd_graficos(args) -> None:
    from .graficos import generar_graficos
    generar_graficos()


def cmd_pruebas(args) -> None:
    from .pruebas import ejecutar_pruebas
    ok = ejecutar_pruebas(_cfg(args), _dir_evidencia(args), concurrencia=not args.sin_concurrencia)
    if not ok:
        sys.exit(1)


def cmd_documentar(args) -> None:
    from .documentar import documentar
    documentar(_cfg(args))


def cmd_informe(args) -> None:
    from .informe import construir_informe
    construir_informe(pdf=not args.sin_pdf)


def cmd_demo(args) -> None:
    from .operaciones import demostracion
    demostracion(_cfg(args))


def cmd_emitir(args) -> None:
    from .operaciones import emitir_tiquete
    _imprimir(emitir_tiquete(_cfg(args), id_vuelo=args.vuelo, cabina=args.cabina, id_pasajero=args.pasajero,
                             id_comprador=args.comprador, id_localizacion=args.localizacion, id_vendedor=args.vendedor,
                             descuento=args.descuento, asiento=args.asiento))


def cmd_pagar(args) -> None:
    from .operaciones import registrar_pago
    _imprimir(registrar_pago(_cfg(args), id_tiquete=args.tiquete, metodo=args.metodo, monto=Decimal(args.monto),
                             id_localizacion=args.localizacion, resultado=args.resultado,
                             ultimos4=args.ultimos4, marca=args.marca))


def cmd_cancelar(args) -> None:
    from .operaciones import cancelar_tiquete
    _imprimir(cancelar_tiquete(_cfg(args), id_tiquete=args.tiquete, motivo=args.motivo))


def cmd_reproducir(args) -> None:
    """Secuencia completa desde cero (solo local): base, carga, pruebas, consultas, gráficos y documentación."""
    if not args.confirmar_destruccion:
        sys.exit("La reproducción completa elimina la base LOCAL: agregue --confirmar-destruccion.")
    print("[1/7] Verificación de la conexión");  cmd_verificar_conexion(args)
    print("[2/7] Base de datos desde cero");     cmd_reiniciar_local(args)
    print("[3/7] Carga de datos sintéticos");    args.semilla = args.semilla; args.corte = None; cmd_cargar_datos(args)
    print("[4/7] Pruebas");                      args.sin_concurrencia = False; cmd_pruebas(args)
    print("[5/7] Consultas");                    args.id = None; args.param = None; args.salida = None; cmd_consultas(args)
    print("[6/7] Gráficos");                     cmd_graficos(args)
    print("[7/7] Documentación del modelo");     cmd_documentar(args)


def _imprimir(datos) -> None:
    print(json.dumps(datos, indent=2, ensure_ascii=False, default=str))


def construir_parser() -> argparse.ArgumentParser:
    from .generador import SEMILLA_PREDETERMINADA
    p = argparse.ArgumentParser(prog="aerolinea", description="Base de datos de la aerolínea (PSMA00611).")
    p.add_argument("--env", help="archivo de configuración (por defecto .env o $AEROLINEA_ENV)")
    p.add_argument("--evidencia", help="carpeta de evidencias (por defecto evidence/local)")
    sub = p.add_subparsers(dest="comando", required=True)

    sub.add_parser("verificar-conexion", help="muestra servidor, edición, versión, usuario y cifrado").set_defaults(func=cmd_verificar_conexion)
    s = sub.add_parser("desplegar", help="ejecuta los scripts 02-10 (y 01 con --crear-bd)")
    s.add_argument("--crear-bd", action="store_true", help="crea la base local antes (01)")
    s.add_argument("--solo", nargs="*", help="nombres de scripts concretos")
    s.set_defaults(func=cmd_desplegar)
    s = sub.add_parser("reiniciar-local", help="DESTRUCTIVO: elimina y recrea la base local")
    s.add_argument("--confirmar-destruccion", action="store_true")
    s.set_defaults(func=cmd_reiniciar_local)
    s = sub.add_parser("cargar-datos", help="genera vuelos y datos sintéticos y los carga")
    s.add_argument("--semilla", type=int, default=SEMILLA_PREDETERMINADA)
    s.add_argument("--corte", help="fecha de corte UTC ISO (por defecto 2026-11-01T00:00)")
    s.set_defaults(func=cmd_cargar_datos)
    s = sub.add_parser("consultas", help="ejecuta el catálogo de consultas y exporta CSV")
    s.add_argument("--id", nargs="*", help="identificadores (p. ej. Q01 Q05)")
    s.add_argument("--param", nargs="*", help="parámetros nombre=valor")
    s.add_argument("--salida", help="carpeta de resultados (por defecto reports/resultados)")
    s.set_defaults(func=cmd_consultas)
    sub.add_parser("graficos", help="genera las figuras a partir de los CSV").set_defaults(func=cmd_graficos)
    s = sub.add_parser("pruebas", help="pruebas T-SQL y de concurrencia")
    s.add_argument("--sin-concurrencia", action="store_true")
    s.set_defaults(func=cmd_pruebas)
    sub.add_parser("documentar", help="diccionario de datos y diagrama físico desde el catálogo").set_defaults(func=cmd_documentar)
    sub.add_parser("demo", help="demostración: emitir, pagar en dos partes y cancelar").set_defaults(func=cmd_demo)
    s = sub.add_parser("informe", help="genera el informe académico (DOCX con pandoc y PDF con LibreOffice)")
    s.add_argument("--sin-pdf", action="store_true", help="solo DOCX")
    s.set_defaults(func=cmd_informe)

    s = sub.add_parser("emitir-tiquete", help="invoca ven.usp_emitir_tiquete")
    for nombre in ("vuelo", "pasajero", "comprador", "localizacion"):
        s.add_argument(f"--{nombre}", type=int, required=True)
    s.add_argument("--cabina", required=True, choices=["ECO", "VIP"])
    s.add_argument("--vendedor", type=int)
    s.add_argument("--descuento")
    s.add_argument("--asiento")
    s.set_defaults(func=cmd_emitir)
    s = sub.add_parser("registrar-pago", help="invoca ven.usp_registrar_pago")
    s.add_argument("--tiquete", type=int, required=True)
    s.add_argument("--metodo", required=True, choices=["TC", "TD", "EFECTIVO", "BILLETERA"])
    s.add_argument("--monto", required=True)
    s.add_argument("--localizacion", type=int, required=True)
    s.add_argument("--resultado", default="CONFIRMADO", choices=["CONFIRMADO", "FALLIDO", "PENDIENTE"])
    s.add_argument("--ultimos4")
    s.add_argument("--marca")
    s.set_defaults(func=cmd_pagar)
    s = sub.add_parser("cancelar-tiquete", help="invoca ven.usp_cancelar_tiquete")
    s.add_argument("--tiquete", type=int, required=True)
    s.add_argument("--motivo", default="VOLUNTARIA")
    s.set_defaults(func=cmd_cancelar)
    s = sub.add_parser("reproducir", help="DESTRUCTIVO (local): reconstruye todo y regenera resultados")
    s.add_argument("--confirmar-destruccion", action="store_true")
    s.add_argument("--semilla", type=int, default=SEMILLA_PREDETERMINADA)
    s.set_defaults(func=cmd_reproducir)
    return p


def main(argv: list[str] | None = None) -> None:
    args = construir_parser().parse_args(argv)
    try:
        args.func(args)
    except (ErrorConfiguracion, ErrorBaseDatos) as exc:
        sys.exit(f"ERROR: {exc}")


if __name__ == "__main__":
    main()
