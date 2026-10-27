# Cómo contribuir

Este repositorio es el Producto Académico Colaborativo del curso PSMA00611. Cada integrante registra sus aportes con su propia cuenta de GitHub, de modo que el historial refleje quién hizo qué.

## Flujo de trabajo

1. Cree una rama desde `main` con un nombre descriptivo: `feature/consulta-q21`, `fix/trigger-pago`, `docs/informe-seccion-5`.
2. Haga cambios pequeños y coherentes. Antes de confirmar:
   - `python -m pytest` (pruebas de la aplicación, no requieren servidor);
   - si tocó T-SQL: `python -m aerolinea desplegar` y `python -m aerolinea pruebas` contra su base **local**;
   - si tocó una consulta: `python -m aerolinea consultas --id Qxx` y revise el CSV.
3. Mensajes de confirmación en español, en imperativo y con el *qué* y el *porqué*: «Agrega Q21 de ingresos por día de la semana».
4. Abra un *pull request* hacia `main` y pida la revisión de otro integrante. Quien revisa comprueba que las pruebas pasan y que la documentación se actualizó.

## Reglas

- **Nunca** suba `.env`, `.env.azure`, contraseñas, tokens, cadenas de conexión con credenciales ni capturas que las muestren.
- Los scripts T-SQL deben poder ejecutarse más de una vez sin error (idempotentes) y no deben usar `USE`.
- Las operaciones destructivas van solo en scripts cuyo nombre empiece por `99_DESTRUCTIVO_` y exigen confirmación explícita.
- No concatene valores de usuario en SQL desde Python: use parámetros (`?`).
- Si cambia una tabla o columna, actualice `docs/02_modelo/definiciones_atributos.csv` y ejecute `python -m aerolinea documentar`.
- Los resultados que se citen en el informe deben salir de archivos de `reports/resultados/` generados por el código, no de valores copiados a mano.

## Registro de aportes

Cada integrante completa su fila en `docs/equipo/registro_aportes.md` con aportes verificables (enlaces a *commits*, *pull requests* o archivos). El registro no se completa por otra persona ni con aportes que no ocurrieron.
