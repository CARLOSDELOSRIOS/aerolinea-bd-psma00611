# Catálogo de consultas

Documento generado por `python -m aerolinea consultas` a partir de `sql/consultas/*.sql` y de los resultados guardados en `reports/resultados/`. No editar a mano: las interpretaciones se mantienen en `docs/07_consultas/interpretaciones.md`.

Ejecución: 2026-10-27T03:50:58+00:00 · servidor `vm` · Developer Edition (64-bit) 16.0.4305.5 · base `AerolineaDB`.

Los datos son sintéticos: las cifras ilustran el funcionamiento del modelo y no describen un mercado real.

## Q01 · Ocupación por vuelo operado

- **Pregunta:** ¿Qué tan llenos salieron los vuelos y cómo se ubica cada uno dentro de su ruta?
- **Utilidad:** detectar vuelos con baja ocupación (candidatos a cambio de equipo u horario) y saturados.
- **Granularidad:** una fila por vuelo ATERRIZADO.
- **Filtros:** fecha local de salida entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** factor de ocupación = pasajeros volados (tiquetes USADO) / asientos ofrecidos del avión. Los no presentados ocupan plaza vendida pero no cuentan como volados.
- **Técnicas:** JOIN con vistas, GROUP BY, SUM, RANK() OVER (PARTITION BY ruta).
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q01_ocupacion_por_vuelo.sql` → `reports/resultados/Q01_ocupacion_por_vuelo.csv` (1767 filas, 192 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q01 · Ocupación por vuelo operado
   Pregunta     : ¿Qué tan llenos salieron los vuelos y cómo se ubica cada uno dentro de su ruta?
   Utilidad     : detectar vuelos con baja ocupación (candidatos a cambio de equipo u horario) y saturados.
   Granularidad : una fila por vuelo ATERRIZADO.
   Filtros      : fecha local de salida entre @fecha_desde y @fecha_hasta.
   Fórmula      : factor de ocupación = pasajeros volados (tiquetes USADO) / asientos ofrecidos del avión.
                  Los no presentados ocupan plaza vendida pero no cuentan como volados.
   Técnicas     : JOIN con vistas, GROUP BY, SUM, RANK() OVER (PARTITION BY ruta).
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH por_vuelo AS (
    SELECT v.id_vuelo, v.codigo_vuelo, v.ruta, v.fecha_salida_local, v.matricula, v.modelo,
           SUM(o.capacidad)        AS asientos_ofrecidos,
           SUM(o.plazas_ocupadas)  AS plazas_vendidas,
           SUM(o.usados)           AS pasajeros_volados,
           SUM(o.no_presentados)   AS no_presentados
    FROM rpt.v_vuelo AS v
    JOIN rpt.v_ocupacion_vuelo_cabina AS o ON o.id_vuelo = v.id_vuelo
    WHERE v.codigo_estado = 'ATERRIZADO'
      AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY v.id_vuelo, v.codigo_vuelo, v.ruta, v.fecha_salida_local, v.matricula, v.modelo
)
SELECT id_vuelo, codigo_vuelo, ruta, fecha_salida_local, matricula, modelo,
       asientos_ofrecidos, plazas_vendidas, pasajeros_volados, no_presentados,
       CAST(pasajeros_volados * 1.0 / asientos_ofrecidos AS DECIMAL(7,4)) AS factor_ocupacion,
       RANK() OVER (PARTITION BY ruta ORDER BY pasajeros_volados * 1.0 / asientos_ofrecidos DESC) AS rango_en_ruta
FROM por_vuelo
ORDER BY ruta, fecha_salida_local, codigo_vuelo;
```

</details>

**Resultado ejecutado**

| id_vuelo | codigo_vuelo | ruta | fecha_salida_local | matricula | modelo | asientos_ofrecidos | plazas_vendidas | pasajeros_volados | no_presentados | factor_ocupacion | rango_en_ruta |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 7 | XX601 | ATL-DEN | 2026-09-01 | N203XA | A320neo | 162 | 111 | 106 | 5 | 0.6543 | 51 |
| 35 | XX601 | ATL-DEN | 2026-09-02 | N203XA | A320neo | 162 | 90 | 80 | 10 | 0.4938 | 61 |
| 64 | XX601 | ATL-DEN | 2026-09-03 | N203XA | A320neo | 162 | 100 | 97 | 3 | 0.5988 | 57 |
| 94 | XX601 | ATL-DEN | 2026-09-04 | N203XA | A320neo | 162 | 128 | 122 | 6 | 0.7531 | 24 |
| 124 | XX601 | ATL-DEN | 2026-09-05 | N203XA | A320neo | 162 | 106 | 101 | 5 | 0.6235 | 53 |
| 154 | XX601 | ATL-DEN | 2026-09-06 | N203XA | A320neo | 162 | 115 | 113 | 2 | 0.6975 | 35 |
| 184 | XX601 | ATL-DEN | 2026-09-07 | N203XA | A320neo | 162 | 104 | 98 | 6 | 0.6049 | 56 |
| 213 | XX601 | ATL-DEN | 2026-09-08 | N203XA | A320neo | 162 | 100 | 93 | 7 | 0.5741 | 58 |
| 241 | XX601 | ATL-DEN | 2026-09-09 | N203XA | A320neo | 162 | 97 | 93 | 4 | 0.5741 | 58 |
| 270 | XX601 | ATL-DEN | 2026-09-10 | N203XA | A320neo | 162 | 116 | 108 | 8 | 0.6667 | 48 |
| 300 | XX601 | ATL-DEN | 2026-09-11 | N203XA | A320neo | 162 | 117 | 113 | 4 | 0.6975 | 35 |
| 330 | XX601 | ATL-DEN | 2026-09-12 | N203XA | A320neo | 162 | 115 | 110 | 5 | 0.6790 | 44 |
| 360 | XX601 | ATL-DEN | 2026-09-13 | N203XA | A320neo | 162 | 123 | 113 | 10 | 0.6975 | 35 |
| 390 | XX601 | ATL-DEN | 2026-09-14 | N203XA | A320neo | 162 | 90 | 89 | 1 | 0.5494 | 60 |
| 419 | XX601 | ATL-DEN | 2026-09-15 | N203XA | A320neo | 162 | 119 | 111 | 8 | 0.6852 | 41 |

_Se muestran 15 de 1767 filas; el resultado completo está en el CSV._

**Interpretación**

Se analizaron 1 767 vuelos aterrizados entre septiembre y octubre de 2026. La ocupación por vuelo tiene media de 66,9 % y mediana de 67,0 %, con un rango de 31,6 % a 92,6 %; 77 vuelos superaron el 85 % y 92 quedaron por debajo del 50 %. Los no presentados son el 4,55 % de las plazas vendidas en vuelos operados, cerca del 4,5 % que usa el generador, lo que confirma que la consulta separa bien plazas vendidas y pasajeros volados. La clasificación dentro de cada ruta (`RANK`) permite localizar los vuelos de menor ocupación de cada ruta en lugar de compararlos con rutas de distinta demanda.

## Q02 · Ocupación por ruta y cabina (con total por cabina)

- **Pregunta:** ¿Qué rutas y cabinas aprovechan mejor la capacidad?
- **Utilidad:** decidir frecuencias, tamaño de avión y asignación de asientos VIP por ruta.
- **Granularidad:** una fila por ruta dirigida y cabina, más una fila TOTAL por cabina (GROUPING SETS).
- **Filtros:** vuelos ATERRIZADOS en el período; solo grupos con al menos @min_vuelos vuelos (HAVING).
- **Fórmulas:** factor ponderado = SUM(pasajeros volados) / SUM(asientos ofrecidos). En la fila TOTAL se compara con el promedio simple de los factores por vuelo: difieren porque las rutas usan aviones de distinta capacidad (un E175 no pesa lo mismo que un A321neo).
- **Técnicas:** GROUP BY GROUPING SETS, GROUPING(), HAVING, agregaciones.
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31, `@min_vuelos` = 20
- **Archivos:** `sql/consultas/Q02_ocupacion_ruta_cabina.sql` → `reports/resultados/Q02_ocupacion_ruta_cabina.csv` (46 filas, 170 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q02 · Ocupación por ruta y cabina (con total por cabina)
   Pregunta     : ¿Qué rutas y cabinas aprovechan mejor la capacidad?
   Utilidad     : decidir frecuencias, tamaño de avión y asignación de asientos VIP por ruta.
   Granularidad : una fila por ruta dirigida y cabina, más una fila TOTAL por cabina (GROUPING SETS).
   Filtros      : vuelos ATERRIZADOS en el período; solo grupos con al menos @min_vuelos vuelos (HAVING).
   Fórmula      : factor ponderado = SUM(pasajeros volados) / SUM(asientos ofrecidos).
                  En la fila TOTAL se compara con el promedio simple de los factores por vuelo: difieren
                  porque las rutas usan aviones de distinta capacidad (un E175 no pesa lo mismo que un A321neo).
   Técnicas     : GROUP BY GROUPING SETS, GROUPING(), HAVING, agregaciones.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param
DECLARE @min_vuelos INT = 20;               -- @param

SELECT CASE WHEN GROUPING(o.ruta) = 1 THEN 'TOTAL' ELSE o.ruta END       AS ruta,
       o.codigo_cabina,
       COUNT(*)                                                           AS vuelos,
       SUM(o.capacidad)                                                   AS asientos_ofrecidos,
       SUM(o.usados)                                                      AS pasajeros_volados,
       CAST(SUM(o.usados) * 1.0 / SUM(o.capacidad) AS DECIMAL(7,4))       AS factor_ponderado,
       CAST(AVG(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS promedio_simple_factores,
       CAST(MIN(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS factor_minimo,
       CAST(MAX(o.usados * 1.0 / o.capacidad) AS DECIMAL(7,4))            AS factor_maximo,
       SUM(CASE WHEN o.plazas_ocupadas = o.capacidad THEN 1 ELSE 0 END)   AS vuelos_agotados_al_cierre
FROM rpt.v_ocupacion_vuelo_cabina AS o
WHERE o.estado_vuelo = 'ATERRIZADO'
  AND o.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
GROUP BY GROUPING SETS ((o.ruta, o.codigo_cabina), (o.codigo_cabina))
HAVING COUNT(*) >= @min_vuelos
ORDER BY o.codigo_cabina, GROUPING(o.ruta), factor_ponderado DESC;
```

</details>

**Resultado ejecutado**

| ruta | codigo_cabina | vuelos | asientos_ofrecidos | pasajeros_volados | factor_ponderado | promedio_simple_factores | factor_minimo | factor_maximo | vuelos_agotados_al_cierre |
|---|---|---|---|---|---|---|---|---|---|
| BOS-MCO | ECO | 43 | 6450 | 5086 | 0.7885 | 0.7885 | 0.5467 | 0.9067 | 0 |
| ORD-JFK | ECO | 118 | 16992 | 12812 | 0.7540 | 0.7540 | 0.5000 | 0.9444 | 0 |
| JFK-LAX | ECO | 119 | 19992 | 14874 | 0.7440 | 0.7440 | 0.4524 | 0.9107 | 0 |
| ATL-DEN | ECO | 61 | 9150 | 6804 | 0.7436 | 0.7436 | 0.5067 | 0.9067 | 0 |
| DFW-PHX | ECO | 60 | 8640 | 6379 | 0.7383 | 0.7383 | 0.5139 | 0.9306 | 0 |
| DFW-ORD | ECO | 61 | 8784 | 6309 | 0.7182 | 0.7182 | 0.4444 | 0.9236 | 0 |
| HNL-LAX | ECO | 60 | 10080 | 7113 | 0.7057 | 0.7057 | 0.3571 | 0.9226 | 0 |
| MCO-BOS | ECO | 43 | 6450 | 4548 | 0.7051 | 0.7051 | 0.4867 | 0.9333 | 0 |
| MIA-JFK | ECO | 120 | 18000 | 12578 | 0.6988 | 0.6988 | 0.4333 | 0.9200 | 0 |
| PHX-DFW | ECO | 61 | 8784 | 6124 | 0.6972 | 0.6972 | 0.4236 | 0.9097 | 0 |
| DEN-SEA | ECO | 61 | 3904 | 2677 | 0.6857 | 0.6857 | 0.4688 | 0.8594 | 0 |
| JFK-LAS | ECO | 61 | 10248 | 6997 | 0.6828 | 0.6828 | 0.3929 | 0.8988 | 0 |
| LAS-JFK | ECO | 60 | 10080 | 6856 | 0.6802 | 0.6802 | 0.4821 | 0.8929 | 0 |
| JFK-ORD | ECO | 121 | 17424 | 11834 | 0.6792 | 0.6792 | 0.4028 | 0.9306 | 0 |
| MIA-ATL | ECO | 119 | 7616 | 5038 | 0.6615 | 0.6615 | 0.3906 | 0.9375 | 0 |

_Se muestran 15 de 46 filas; el resultado completo está en el CSV._

**Interpretación**

En la cabina económica el factor de ocupación ponderado del período es 68,9 % y el promedio simple de los factores por vuelo es 68,5 %; en VIP, 53,0 % y 53,1 %. La diferencia entre ambas medidas aparece porque los aviones tienen capacidades distintas: el factor ponderado responde a «qué parte de los asientos ofrecidos se usó» y es el que corresponde para la red. Por ruta, en económica va de 61,5 % (DEN-ATL) a 78,8 % (BOS-MCO); en VIP, de 49,1 % a 57,3 %. Hubo 4 cabinas VIP agotadas al cierre de la venta y ninguna económica. La menor ocupación VIP es un resultado de los parámetros del generador y no permite concluir nada sobre la demanda real de esa cabina.

## Q03 · Ventas, cobros y reembolsos por mes

- **Pregunta:** ¿Cuánto se vendió, cuánto se cobró y cuánto se devolvió cada mes?
- **Utilidad:** flujo de caja comercial; distingue el valor vendido del dinero recibido.
- **Granularidad:** una fila por mes calendario (UTC).
- **Filtros:** eventos entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** ventas brutas = SUM(precio final) de los tiquetes creados en el mes (incluye los que luego se cancelaron); ventas vigentes = las no canceladas; cobros = SUM(pagos CONFIRMADOS) por fecha de confirmación; reembolsos = SUM(reembolsos) por fecha de reembolso; cobro neto = cobros - reembolsos. Cada medida se agrega por SU PROPIA fecha en una CTE separada: unir pagos y reembolsos fila a fila multiplicaría importes.
- **Técnicas:** CTE múltiples, UNION, LEFT JOIN, agregaciones condicionales.
- **Parámetros usados:** `@fecha_desde` = 2026-07-01, `@fecha_hasta` = 2026-12-31
- **Archivos:** `sql/consultas/Q03_ventas_cobros_reembolsos_mes.sql` → `reports/resultados/Q03_ventas_cobros_reembolsos_mes.csv` (4 filas, 974 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q03 · Ventas, cobros y reembolsos por mes
   Pregunta     : ¿Cuánto se vendió, cuánto se cobró y cuánto se devolvió cada mes?
   Utilidad     : flujo de caja comercial; distingue el valor vendido del dinero recibido.
   Granularidad : una fila por mes calendario (UTC).
   Filtros      : eventos entre @fecha_desde y @fecha_hasta.
   Fórmulas     : ventas brutas = SUM(precio final) de los tiquetes creados en el mes (incluye los
                  que luego se cancelaron); ventas vigentes = las no canceladas;
                  cobros = SUM(pagos CONFIRMADOS) por fecha de confirmación;
                  reembolsos = SUM(reembolsos) por fecha de reembolso;
                  cobro neto = cobros - reembolsos.
                  Cada medida se agrega por SU PROPIA fecha en una CTE separada: unir pagos y
                  reembolsos fila a fila multiplicaría importes.
   Técnicas     : CTE múltiples, UNION, LEFT JOIN, agregaciones condicionales.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-12-31';   -- @param

WITH ventas AS (
    SELECT DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1) AS mes,
           COUNT(*)                                                         AS tiquetes_vendidos,
           SUM(precio_final_usd)                                            AS ventas_brutas_usd,
           SUM(CASE WHEN codigo_estado <> 'CANCELADO' THEN precio_final_usd ELSE 0 END) AS ventas_vigentes_usd
    FROM ven.tiquete
    WHERE CAST(creado_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(creado_utc), MONTH(creado_utc), 1)
), cobros AS (
    SELECT DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1) AS mes,
           COUNT(*) AS pagos_confirmados, SUM(monto_usd) AS cobros_usd
    FROM ven.pago
    WHERE codigo_estado = 'CONFIRMADO' AND CAST(fecha_resolucion_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(fecha_resolucion_utc), MONTH(fecha_resolucion_utc), 1)
), reembolsos AS (
    SELECT DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1) AS mes,
           SUM(monto_usd) AS reembolsos_usd
    FROM ven.reembolso
    WHERE CAST(fecha_reembolso_utc AS DATE) BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY DATEFROMPARTS(YEAR(fecha_reembolso_utc), MONTH(fecha_reembolso_utc), 1)
), meses AS (
    SELECT mes FROM ventas UNION SELECT mes FROM cobros UNION SELECT mes FROM reembolsos
)
SELECT m.mes,
       ISNULL(v.tiquetes_vendidos, 0)                          AS tiquetes_vendidos,
       ISNULL(v.ventas_brutas_usd, 0)                          AS ventas_brutas_usd,
       ISNULL(v.ventas_vigentes_usd, 0)                        AS ventas_vigentes_usd,
       ISNULL(c.pagos_confirmados, 0)                          AS pagos_confirmados,
       ISNULL(c.cobros_usd, 0)                                 AS cobros_usd,
       ISNULL(r.reembolsos_usd, 0)                             AS reembolsos_usd,
       ISNULL(c.cobros_usd, 0) - ISNULL(r.reembolsos_usd, 0)   AS cobro_neto_usd
FROM meses AS m
LEFT JOIN ventas     AS v ON v.mes = m.mes
LEFT JOIN cobros     AS c ON c.mes = m.mes
LEFT JOIN reembolsos AS r ON r.mes = m.mes
ORDER BY m.mes;
```

</details>

**Resultado ejecutado**

| mes | tiquetes_vendidos | ventas_brutas_usd | ventas_vigentes_usd | pagos_confirmados | cobros_usd | reembolsos_usd | cobro_neto_usd |
|---|---|---|---|---|---|---|---|
| 2026-07-01 | 48392 | 9965346.08 | 9197336.45 | 54868 | 9774572.77 | 219755.72 | 9554817.05 |
| 2026-08-01 | 70363 | 15591245.82 | 14441036.70 | 79778 | 15285358.39 | 482237.63 | 14803120.76 |
| 2026-09-01 | 103529 | 23736794.26 | 22104440.77 | 118289 | 23374990.21 | 1001647.25 | 22373342.96 |
| 2026-10-01 | 101434 | 24224876.63 | 22647526.23 | 115697 | 23833321.92 | 1327161.44 | 22506160.48 |

**Interpretación**

Entre julio y octubre de 2026 se vendieron 323 718 tiquetes por 73,52 millones de USD brutos (68,39 millones siguen vigentes tras cancelaciones). Los cobros confirmados suman 72,27 millones y los reembolsos 3,03 millones, con un cobro neto de 69,24 millones. Ventas, cobros y reembolsos se agregan cada uno por su propia fecha; por eso en un mes los cobros pueden diferir de las ventas: hay reservas pagadas en dos o tres partes, reservas que vencen sin pagar y reembolsos de ventas de meses anteriores. Que los cobros superen a las ventas vigentes no es un error: incluyen dinero que luego se devolvió o que se retuvo como penalidad (la identidad completa se verifica en Q19). No se calcula rentabilidad porque el modelo no registra costos.

## Q04 · Saldos pendientes de reservas a la fecha de corte

- **Pregunta:** ¿Cuánto dinero está comprometido en reservas aún no pagadas y cuándo vencen?
- **Utilidad:** gestión de cobranza y previsión de plazas que pueden liberarse por vencimiento.
- **Granularidad:** una fila por situación de pago y plazo restante.
- **Filtros:** tiquetes en estado RESERVADO (las cancelaciones y emisiones no tienen saldo).
- **Fórmulas:** saldo pendiente = precio final - pagos confirmados; horas al vencimiento = límite de pago - fecha de corte de los datos (ref.parametro FECHA_CORTE_DATOS).
- **Técnicas:** JOIN con vista financiera (pagos ya agregados por tiquete), CASE, GROUP BY.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q04_saldos_pendientes.sql` → `reports/resultados/Q04_saldos_pendientes.csv` (7 filas, 54 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q04 · Saldos pendientes de reservas a la fecha de corte
   Pregunta     : ¿Cuánto dinero está comprometido en reservas aún no pagadas y cuándo vencen?
   Utilidad     : gestión de cobranza y previsión de plazas que pueden liberarse por vencimiento.
   Granularidad : una fila por situación de pago y plazo restante.
   Filtros      : tiquetes en estado RESERVADO (las cancelaciones y emisiones no tienen saldo).
   Fórmula      : saldo pendiente = precio final - pagos confirmados; horas al vencimiento =
                  límite de pago - fecha de corte de los datos (ref.parametro FECHA_CORTE_DATOS).
   Técnicas     : JOIN con vista financiera (pagos ya agregados por tiquete), CASE, GROUP BY.
   ============================================================================= */
DECLARE @fecha_corte DATETIME2(0) = (SELECT CAST(valor AS DATETIME2(0)) FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS');

WITH reservas AS (
    SELECT f.id_tiquete, f.precio_final_usd, f.cobrado_usd, f.saldo_pendiente_usd, f.pendiente_confirmacion_usd,
           DATEDIFF(HOUR, @fecha_corte, t.fecha_limite_pago_utc) AS horas_al_vencimiento
    FROM rpt.v_tiquete_financiero AS f
    JOIN ven.tiquete AS t ON t.id_tiquete = f.id_tiquete
    WHERE f.codigo_estado = 'RESERVADO'
)
SELECT CASE WHEN cobrado_usd = 0 AND pendiente_confirmacion_usd = 0 THEN '1. Sin pagos'
            WHEN cobrado_usd = 0 THEN '2. Pago en espera de confirmación'
            ELSE '3. Pago parcial' END                                  AS situacion,
       CASE WHEN horas_al_vencimiento < 24 THEN 'a. vence en menos de 24 h'
            WHEN horas_al_vencimiento < 48 THEN 'b. vence en 24-48 h'
            ELSE 'c. vence en 48 h o más' END                           AS plazo,
       COUNT(*)                                                         AS tiquetes,
       SUM(precio_final_usd)                                            AS valor_reservado_usd,
       SUM(cobrado_usd)                                                 AS abonado_usd,
       SUM(saldo_pendiente_usd)                                         AS saldo_pendiente_usd
FROM reservas
GROUP BY CASE WHEN cobrado_usd = 0 AND pendiente_confirmacion_usd = 0 THEN '1. Sin pagos'
              WHEN cobrado_usd = 0 THEN '2. Pago en espera de confirmación'
              ELSE '3. Pago parcial' END,
         CASE WHEN horas_al_vencimiento < 24 THEN 'a. vence en menos de 24 h'
              WHEN horas_al_vencimiento < 48 THEN 'b. vence en 24-48 h'
              ELSE 'c. vence en 48 h o más' END
ORDER BY situacion, plazo;
```

</details>

**Resultado ejecutado**

| situacion | plazo | tiquetes | valor_reservado_usd | abonado_usd | saldo_pendiente_usd |
|---|---|---|---|---|---|
| 1. Sin pagos | a. vence en menos de 24 h | 40 | 9955.55 | 0.00 | 9955.55 |
| 1. Sin pagos | b. vence en 24-48 h | 44 | 10013.56 | 0.00 | 10013.56 |
| 1. Sin pagos | c. vence en 48 h o más | 64 | 15357.21 | 0.00 | 15357.21 |
| 2. Pago en espera de confirmación | c. vence en 48 h o más | 11 | 2466.14 | 0.00 | 2466.14 |
| 3. Pago parcial | a. vence en menos de 24 h | 78 | 17536.07 | 8497.72 | 9038.35 |
| 3. Pago parcial | b. vence en 24-48 h | 225 | 56266.65 | 27204.83 | 29061.82 |
| 3. Pago parcial | c. vence en 48 h o más | 362 | 87919.23 | 40868.30 | 47050.93 |

**Interpretación**

A la fecha de corte quedan 824 reservas pendientes de pago por 199 514,41 USD, de los que ya se abonaron 76 570,85 USD y faltan 122 943,56 USD. De ellas, 148 no tienen ningún pago, 11 tienen un pago en espera de confirmación y 665 tienen pagos parciales; 118 vencen en menos de 24 horas. Es el tipo de lista que un equipo de cobranzas usaría para priorizar recordatorios, porque una reserva que vence libera la plaza y obliga a devolver lo abonado (Q05).

## Q05 · Cancelaciones con reembolso: motivo, regla y cabina

- **Pregunta:** ¿Cuánto se devuelve y cuánto se retiene según la causa de la cancelación?
- **Utilidad:** evaluar el costo de la política de cancelación y el efecto de la regla de 24 h.
- **Granularidad:** una fila por motivo, regla aplicada y cabina.
- **Filtros:** tiquetes CANCELADOS.
- **Fórmulas:** la regla y el porcentaje se recalculan con ven.fn_politica_reembolso (la misma función que usa el procedimiento de cancelación); tasa de reembolso = reembolsado / cobrado (NULL si no hubo cobro: distingue "sin dinero que devolver" de "0 % devuelto"); penalidad retenida = cobrado - reembolsado.
- **Técnicas:** CTE, CROSS APPLY con función de tabla en línea, NULLIF, agregaciones.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q05_reembolsos.sql` → `reports/resultados/Q05_reembolsos.csv` (8 filas, 1724 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q05 · Cancelaciones con reembolso: motivo, regla y cabina
   Pregunta     : ¿Cuánto se devuelve y cuánto se retiene según la causa de la cancelación?
   Utilidad     : evaluar el costo de la política de cancelación y el efecto de la regla de 24 h.
   Granularidad : una fila por motivo, regla aplicada y cabina.
   Filtros      : tiquetes CANCELADOS.
   Fórmulas     : la regla y el porcentaje se recalculan con ven.fn_politica_reembolso (la misma función
                  que usa el procedimiento de cancelación); tasa de reembolso = reembolsado / cobrado
                  (NULL si no hubo cobro: distingue "sin dinero que devolver" de "0 % devuelto");
                  penalidad retenida = cobrado - reembolsado.
   Técnicas     : CTE, CROSS APPLY con función de tabla en línea, NULLIF, agregaciones.
   ============================================================================= */
WITH cancelados AS (
    SELECT f.id_tiquete, f.codigo_cabina, t.codigo_motivo_cancelacion, f.cobrado_usd, f.reembolsado_usd,
           f.penalidad_retenida_usd, p.regla_aplicada, p.porcentaje_reembolso
    FROM rpt.v_tiquete_financiero AS f
    JOIN ven.tiquete AS t ON t.id_tiquete = f.id_tiquete
    CROSS APPLY ven.fn_politica_reembolso(t.id_tiquete, t.codigo_motivo_cancelacion, t.fecha_cancelacion_utc) AS p
    WHERE f.codigo_estado = 'CANCELADO'
)
SELECT codigo_motivo_cancelacion                                       AS motivo,
       regla_aplicada                                                  AS regla,
       codigo_cabina,
       COUNT(*)                                                        AS tiquetes,
       SUM(CASE WHEN cobrado_usd = 0 THEN 1 ELSE 0 END)                AS sin_cobro,
       CAST(AVG(porcentaje_reembolso) AS DECIMAL(5,1))                 AS porcentaje_politica_medio,
       SUM(cobrado_usd)                                                AS cobrado_usd,
       SUM(reembolsado_usd)                                            AS reembolsado_usd,
       SUM(penalidad_retenida_usd)                                     AS penalidad_retenida_usd,
       CAST(SUM(reembolsado_usd) / NULLIF(SUM(cobrado_usd), 0) AS DECIMAL(7,4)) AS tasa_reembolso
FROM cancelados
GROUP BY codigo_motivo_cancelacion, regla_aplicada, codigo_cabina
ORDER BY motivo, regla, codigo_cabina;
```

</details>

**Resultado ejecutado**

| motivo | regla | codigo_cabina | tiquetes | sin_cobro | porcentaje_politica_medio | cobrado_usd | reembolsado_usd | penalidad_retenida_usd | tasa_reembolso |
|---|---|---|---|---|---|---|---|---|---|
| VENCIMIENTO | REEMBOLSO_TOTAL | ECO | 4467 | 3874 | 100.0 | 48400.06 | 48400.06 | 0.00 | 1.0000 |
| VENCIMIENTO | REEMBOLSO_TOTAL | VIP | 365 | 310 | 100.0 | 12389.12 | 12389.12 | 0.00 | 1.0000 |
| VOLUNTARIA | POLITICA_CABINA | ECO | 10101 | 2 | 56.8 | 1989653.45 | 1122239.25 | 867414.20 | 0.5640 |
| VOLUNTARIA | POLITICA_CABINA | VIP | 909 | 0 | 79.9 | 502673.14 | 400042.68 | 102630.46 | 0.7958 |
| VOLUNTARIA | REGLA_24H | ECO | 4434 | 8 | 100.0 | 829879.38 | 829879.38 | 0.00 | 1.0000 |
| VOLUNTARIA | REGLA_24H | VIP | 387 | 0 | 100.0 | 196456.56 | 196456.56 | 0.00 | 1.0000 |
| VUELO_CANCELADO | REEMBOLSO_TOTAL | ECO | 1878 | 1 | 100.0 | 329667.28 | 329667.28 | 0.00 | 1.0000 |
| VUELO_CANCELADO | REEMBOLSO_TOTAL | VIP | 187 | 0 | 100.0 | 91727.71 | 91727.71 | 0.00 | 1.0000 |

**Interpretación**

Se cancelaron 22 728 tiquetes. Sobre 4,00 millones de USD cobrados en ellos se reembolsaron 3,03 millones y se retuvieron 0,97 millones como penalidad. La regla de 24 horas y las cancelaciones de vuelo devuelven el 100 %; las cancelaciones voluntarias fuera de esa regla siguen la política por cabina, con un porcentaje medio aplicado de 56,8 % en económica y 79,9 % en VIP. En las reservas vencidas, 4 184 de 4 832 no tenían ningún cobro; la consulta las cuenta aparte (`sin_cobro`) y define la tasa de reembolso como NULL cuando no hubo cobro («no había nada que devolver»), que es distinto de un 0 % de reembolso. La regla y el porcentaje se recalculan con la misma función que usa el procedimiento de cancelación, y la prueba PR-22 confirma que los 22 728 reembolsos cargados coinciden con ella.

## Q06 · Precio medio y descuento efectivo por ruta y cabina

- **Pregunta:** ¿Cuánto paga en promedio un pasajero y cuánto se resigna en descuentos?
- **Utilidad:** evaluar política de precios y promociones por mercado.
- **Granularidad:** una fila por ruta y cabina.
- **Filtros:** tiquetes vendidos entre @fecha_desde y @fecha_hasta (fecha de venta UTC), excluidos los vencidos sin pago.
- **Fórmulas:** precio medio final = AVG(precio final); tasa de descuento efectiva = SUM(monto descontado) / SUM(precio base) (ponderada por importe); penetración = tiquetes con descuento / tiquetes.
- **Técnicas:** GROUP BY, agregaciones condicionales, división protegida con NULLIF.
- **Parámetros usados:** `@fecha_desde` = 2026-07-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q06_precios_y_descuentos.sql` → `reports/resultados/Q06_precios_y_descuentos.csv` (44 filas, 280 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q06 · Precio medio y descuento efectivo por ruta y cabina
   Pregunta     : ¿Cuánto paga en promedio un pasajero y cuánto se resigna en descuentos?
   Utilidad     : evaluar política de precios y promociones por mercado.
   Granularidad : una fila por ruta y cabina.
   Filtros      : tiquetes vendidos entre @fecha_desde y @fecha_hasta (fecha de venta UTC), excluidos los vencidos sin pago.
   Fórmulas     : precio medio final = AVG(precio final); tasa de descuento efectiva =
                  SUM(monto descontado) / SUM(precio base) (ponderada por importe);
                  penetración = tiquetes con descuento / tiquetes.
   Técnicas     : GROUP BY, agregaciones condicionales, división protegida con NULLIF.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.ruta,
       v.codigo_cabina,
       COUNT(*)                                                                          AS tiquetes,
       CAST(AVG(v.precio_base_usd) AS DECIMAL(10,2))                                     AS precio_base_medio_usd,
       CAST(AVG(v.precio_final_usd) AS DECIMAL(10,2))                                    AS precio_final_medio_usd,
       CAST(SUM(v.monto_descuento_usd) / NULLIF(SUM(v.precio_base_usd), 0) AS DECIMAL(7,4)) AS tasa_descuento_efectiva,
       CAST(SUM(CASE WHEN v.porcentaje_descuento > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS penetracion_descuentos,
       MIN(v.precio_final_usd)                                                           AS precio_final_minimo_usd,
       MAX(v.precio_final_usd)                                                           AS precio_final_maximo_usd
FROM rpt.v_venta AS v
WHERE v.fecha_venta BETWEEN @fecha_desde AND @fecha_hasta
  AND NOT (v.codigo_estado = 'CANCELADO' AND v.codigo_motivo_cancelacion = 'VENCIMIENTO')
GROUP BY v.ruta, v.codigo_cabina
ORDER BY v.codigo_cabina, precio_final_medio_usd DESC;
```

</details>

**Resultado ejecutado**

| ruta | codigo_cabina | tiquetes | precio_base_medio_usd | precio_final_medio_usd | tasa_descuento_efectiva | penetracion_descuentos | precio_final_minimo_usd | precio_final_maximo_usd |
|---|---|---|---|---|---|---|---|---|
| HNL-LAX | ECO | 12529 | 331.73 | 320.03 | 0.0353 | 0.2277 | 253.59 | 364.99 |
| LAX-HNL | ECO | 11374 | 331.63 | 319.96 | 0.0352 | 0.2259 | 253.59 | 364.99 |
| LAX-JFK | ECO | 22823 | 323.44 | 311.84 | 0.0359 | 0.2331 | 247.19 | 354.99 |
| JFK-LAX | ECO | 26363 | 323.26 | 311.49 | 0.0364 | 0.2340 | 247.19 | 354.99 |
| JFK-LAS | ECO | 12331 | 295.64 | 285.04 | 0.0359 | 0.2272 | 227.99 | 307.99 |
| LAS-JFK | ECO | 12342 | 295.60 | 284.65 | 0.0370 | 0.2335 | 227.99 | 307.99 |
| DEN-ATL | ECO | 9882 | 181.84 | 175.28 | 0.0361 | 0.2293 | 139.99 | 188.99 |
| ATL-DEN | ECO | 11842 | 181.64 | 175.26 | 0.0351 | 0.2263 | 139.99 | 188.99 |
| MCO-BOS | ECO | 8009 | 173.33 | 167.25 | 0.0351 | 0.2265 | 133.59 | 179.99 |
| BOS-MCO | ECO | 8745 | 173.15 | 166.96 | 0.0358 | 0.2294 | 133.59 | 179.99 |
| MIA-JFK | ECO | 22404 | 169.11 | 163.10 | 0.0356 | 0.2279 | 130.39 | 175.99 |
| JFK-MIA | ECO | 21213 | 169.18 | 163.03 | 0.0364 | 0.2323 | 130.39 | 175.99 |
| SEA-DEN | ECO | 4598 | 163.27 | 157.53 | 0.0352 | 0.2273 | 125.59 | 169.99 |
| DEN-SEA | ECO | 4801 | 163.07 | 157.39 | 0.0348 | 0.2254 | 125.59 | 169.99 |
| PHX-DFW | ECO | 10678 | 145.17 | 140.21 | 0.0342 | 0.2185 | 111.99 | 150.99 |

_Se muestran 15 de 44 filas; el resultado completo está en el CSV._

**Interpretación**

El precio final medio en económica va de 104,07 USD (MIA-ATL) a 320,03 USD (HNL-LAX) y en VIP llega a 902,97 USD (LAX-HNL); el orden sigue la distancia porque así se construyeron las tarifas sintéticas. La tasa de descuento efectiva, ponderada por importe, se mantiene entre 3,4 % y 3,8 % en económica y entre 0,9 % y 1,5 % en VIP; la penetración de descuentos es de 22 % a 23 % en económica y de 9 % a 14 % en VIP. La tasa efectiva es mucho menor que los porcentajes nominales (10 % a 20 %) porque se reparte entre todos los tiquetes, con y sin descuento.

## Q07 · Ventas por canal y punto de venta

- **Pregunta:** ¿Qué peso tienen los canales web y físico y cada punto de venta?
- **Utilidad:** dimensionar mostradores, oficinas y canales digitales.
- **Granularidad:** una fila por canal y localización de venta.
- **Filtros:** tiquetes no cancelados vendidos entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** participación = ventas del punto / ventas totales (SUM() OVER ()). participación en el canal = ventas del punto / ventas del canal (SUM() OVER (PARTITION BY canal)).
- **Técnicas:** GROUP BY, funciones de ventana sobre agregados.
- **Parámetros usados:** `@fecha_desde` = 2026-07-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q07_ventas_por_canal.sql` → `reports/resultados/Q07_ventas_por_canal.csv` (18 filas, 299 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q07 · Ventas por canal y punto de venta
   Pregunta     : ¿Qué peso tienen los canales web y físico y cada punto de venta?
   Utilidad     : dimensionar mostradores, oficinas y canales digitales.
   Granularidad : una fila por canal y localización de venta.
   Filtros      : tiquetes no cancelados vendidos entre @fecha_desde y @fecha_hasta.
   Fórmulas     : participación = ventas del punto / ventas totales (SUM() OVER ()).
                  participación en el canal = ventas del punto / ventas del canal (SUM() OVER (PARTITION BY canal)).
   Técnicas     : GROUP BY, funciones de ventana sobre agregados.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-07-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.canal,
       v.tipo_localizacion,
       v.codigo_localizacion,
       COUNT(DISTINCT v.id_compra)                                                    AS compras,
       COUNT(*)                                                                       AS tiquetes,
       SUM(v.precio_final_usd)                                                        AS ventas_usd,
       CAST(SUM(v.precio_final_usd) * 1.0 / SUM(SUM(v.precio_final_usd)) OVER () AS DECIMAL(7,4)) AS participacion_total,
       CAST(SUM(v.precio_final_usd) * 1.0 / SUM(SUM(v.precio_final_usd)) OVER (PARTITION BY v.canal) AS DECIMAL(7,4)) AS participacion_en_canal
FROM rpt.v_venta AS v
WHERE v.fecha_venta BETWEEN @fecha_desde AND @fecha_hasta
  AND v.codigo_estado <> 'CANCELADO'
GROUP BY v.canal, v.tipo_localizacion, v.codigo_localizacion
ORDER BY v.canal, ventas_usd DESC;
```

</details>

**Resultado ejecutado**

| canal | tipo_localizacion | codigo_localizacion | compras | tiquetes | ventas_usd | participacion_total | participacion_en_canal |
|---|---|---|---|---|---|---|---|
| FISICO | AER | AER-JFK | 8918 | 16524 | 4158278.69 | 0.0608 | 0.2030 |
| FISICO | OFI | OFI-NYC | 7268 | 13182 | 3320355.69 | 0.0486 | 0.1621 |
| FISICO | AER | AER-LAX | 3715 | 6877 | 2492252.17 | 0.0364 | 0.1217 |
| FISICO | OFI | OFI-CHI | 4642 | 8584 | 1782077.30 | 0.0261 | 0.0870 |
| FISICO | OFI | OFI-MIA | 4469 | 8216 | 1738103.53 | 0.0254 | 0.0848 |
| FISICO | AER | AER-MIA | 3589 | 6566 | 1080803.88 | 0.0158 | 0.0528 |
| FISICO | AER | AER-ORD | 3599 | 6722 | 978451.57 | 0.0143 | 0.0478 |
| FISICO | AER | AER-HNL | 1421 | 2610 | 945026.51 | 0.0138 | 0.0461 |
| FISICO | AER | AER-LAS | 1367 | 2511 | 838568.09 | 0.0123 | 0.0409 |
| FISICO | AER | AER-DFW | 2521 | 4720 | 735528.53 | 0.0108 | 0.0359 |
| FISICO | AER | AER-ATL | 2349 | 4343 | 716163.29 | 0.0105 | 0.0350 |
| FISICO | AER | AER-DEN | 1528 | 2784 | 550357.99 | 0.0080 | 0.0269 |
| FISICO | AER | AER-PHX | 1137 | 2063 | 336492.83 | 0.0049 | 0.0164 |
| FISICO | AER | AER-BOS | 962 | 1760 | 319480.47 | 0.0047 | 0.0156 |
| FISICO | AER | AER-MCO | 866 | 1599 | 296980.30 | 0.0043 | 0.0145 |

_Se muestran 15 de 18 filas; el resultado completo está en el CSV._

**Interpretación**

El canal web concentra el 70,0 % de las ventas vigentes (46,0 % el sitio y 24,0 % la aplicación). En el canal físico destacan el mostrador de JFK (6,1 % del total y 20,3 % del canal físico) y la oficina de Nueva York (4,9 %). La participación en el canal y en el total se calcula con funciones de ventana sobre los agregados, de modo que los porcentajes suman 100 % sin consultas adicionales. La mezcla de canales es un supuesto del generador.

## Q08 · Compradores y pasajeros registrados frente a no registrados

- **Pregunta:** ¿Qué parte del negocio proviene de clientes con cuenta y cómo se comportan?
- **Utilidad:** justificar inversión en el programa de clientes y medir la compra sin registro.
- **Granularidad:** una fila por condición del comprador (registrado o no en el momento de la compra).
- **Filtros:** tiquetes vendidos hasta la fecha de corte.
- **Fórmulas:** registrado = existía cuenta (ven.cliente) con fecha de registro <= fecha de venta (LEFT JOIN: sin fila en cliente => no registrado); tiquetes por compra = tiquetes / compras.
- **Técnicas:** LEFT JOIN (en la vista rpt.v_venta), CASE, COUNT DISTINCT, agregaciones.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q08_registrados_vs_no_registrados.sql` → `reports/resultados/Q08_registrados_vs_no_registrados.csv` (2 filas, 403 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q08 · Compradores y pasajeros registrados frente a no registrados
   Pregunta     : ¿Qué parte del negocio proviene de clientes con cuenta y cómo se comportan?
   Utilidad     : justificar inversión en el programa de clientes y medir la compra sin registro.
   Granularidad : una fila por condición del comprador (registrado o no en el momento de la compra).
   Filtros      : tiquetes vendidos hasta la fecha de corte.
   Fórmulas     : registrado = existía cuenta (ven.cliente) con fecha de registro <= fecha de venta
                  (LEFT JOIN: sin fila en cliente => no registrado); tiquetes por compra = tiquetes / compras.
   Técnicas     : LEFT JOIN (en la vista rpt.v_venta), CASE, COUNT DISTINCT, agregaciones.
   ============================================================================= */
SELECT CASE WHEN v.comprador_registrado = 1 THEN 'Registrado' ELSE 'No registrado' END     AS comprador,
       COUNT(DISTINCT v.id_compra)                                                           AS compras,
       COUNT(DISTINCT v.id_persona_comprador)                                                AS compradores_distintos,
       COUNT(*)                                                                              AS tiquetes,
       CAST(COUNT(*) * 1.0 / COUNT(DISTINCT v.id_compra) AS DECIMAL(6,2))                    AS tiquetes_por_compra,
       SUM(CASE WHEN v.pasajero_registrado = 1 THEN 1 ELSE 0 END)                            AS pasajeros_registrados,
       SUM(v.precio_final_usd)                                                               AS ventas_brutas_usd,
       CAST(AVG(v.precio_final_usd) AS DECIMAL(10,2))                                        AS precio_medio_usd,
       CAST(SUM(CASE WHEN v.codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_cancelacion,
       CAST(SUM(CASE WHEN v.canal = 'WEB' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS proporcion_web
FROM rpt.v_venta AS v
GROUP BY CASE WHEN v.comprador_registrado = 1 THEN 'Registrado' ELSE 'No registrado' END
ORDER BY comprador DESC;
```

</details>

**Resultado ejecutado**

| comprador | compras | compradores_distintos | tiquetes | tiquetes_por_compra | pasajeros_registrados | ventas_brutas_usd | precio_medio_usd | tasa_cancelacion | proporcion_web |
|---|---|---|---|---|---|---|---|---|---|
| Registrado | 70828 | 22701 | 135656 | 1.92 | 81380 | 30483960.07 | 224.72 | 0.0700 | 0.6994 |
| No registrado | 98100 | 98100 | 188062 | 1.92 | 8374 | 43034302.72 | 228.83 | 0.0703 | 0.7014 |

**Interpretación**

El 41,9 % de las compras las hizo un comprador registrado (el generador usa 42 %), lo que valida la lógica de la vista: «registrado» significa que la cuenta existía en el momento de la compra. Los registrados son 22 701 compradores distintos con 70 828 compras; las compras sin registro (98 100) no se pueden atribuir a una misma persona de forma fiable, por lo que cada una cuenta como un comprador distinto. Esto es una limitación de la compra sin registro, no de la consulta. Precio medio, tiquetes por compra, tasa de cancelación y uso del canal web son casi iguales en ambos grupos porque el generador no los diferencia; con datos reales esta consulta sería el punto de partida para compararlos.

## Q09 · Tasa de cancelación por ruta y motivo

- **Pregunta:** ¿Dónde se cancelan más tiquetes y por qué causa?
- **Utilidad:** separar cancelaciones voluntarias (demanda) de las operativas (vuelos cancelados).
- **Granularidad:** una fila por ruta.
- **Filtros:** tiquetes de vuelos con salida entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** denominador = tiquetes vendidos (todos los estados); tasa por motivo = tiquetes cancelados por ese motivo / tiquetes vendidos.
- **Técnicas:** agregación condicional (pivote con CASE), GROUP BY, ORDER BY por expresión.
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q09_cancelaciones_por_ruta.sql` → `reports/resultados/Q09_cancelaciones_por_ruta.csv` (22 filas, 133 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q09 · Tasa de cancelación por ruta y motivo
   Pregunta     : ¿Dónde se cancelan más tiquetes y por qué causa?
   Utilidad     : separar cancelaciones voluntarias (demanda) de las operativas (vuelos cancelados).
   Granularidad : una fila por ruta.
   Filtros      : tiquetes de vuelos con salida entre @fecha_desde y @fecha_hasta.
   Fórmulas     : denominador = tiquetes vendidos (todos los estados);
                  tasa por motivo = tiquetes cancelados por ese motivo / tiquetes vendidos.
   Técnicas     : agregación condicional (pivote con CASE), GROUP BY, ORDER BY por expresión.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

SELECT v.ruta,
       COUNT(*)                                                                                   AS tiquetes_vendidos,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VOLUNTARIA' THEN 1 ELSE 0 END)                AS cancel_voluntarias,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VUELO_CANCELADO' THEN 1 ELSE 0 END)           AS cancel_por_vuelo,
       SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VENCIMIENTO' THEN 1 ELSE 0 END)               AS cancel_por_vencimiento,
       CAST(SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VOLUNTARIA' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4))      AS tasa_voluntaria,
       CAST(SUM(CASE WHEN v.codigo_motivo_cancelacion = 'VUELO_CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_por_vuelo,
       CAST(SUM(CASE WHEN v.codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4))                   AS tasa_total
FROM rpt.v_venta AS v
WHERE v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
GROUP BY v.ruta
ORDER BY tasa_total DESC;
```

</details>

**Resultado ejecutado**

| ruta | tiquetes_vendidos | cancel_voluntarias | cancel_por_vuelo | cancel_por_vencimiento | tasa_voluntaria | tasa_por_vuelo | tasa_total |
|---|---|---|---|---|---|---|---|
| ORD-DFW | 6857 | 347 | 226 | 103 | 0.0506 | 0.0330 | 0.0986 |
| ATL-MIA | 6282 | 300 | 189 | 103 | 0.0478 | 0.0301 | 0.0942 |
| DEN-ATL | 6685 | 322 | 179 | 83 | 0.0482 | 0.0268 | 0.0874 |
| ORD-JFK | 15903 | 785 | 340 | 248 | 0.0494 | 0.0214 | 0.0863 |
| JFK-LAX | 18471 | 851 | 397 | 295 | 0.0461 | 0.0215 | 0.0835 |
| DFW-PHX | 7876 | 399 | 129 | 116 | 0.0507 | 0.0164 | 0.0818 |
| MIA-ATL | 6654 | 331 | 90 | 104 | 0.0497 | 0.0135 | 0.0789 |
| MIA-JFK | 15209 | 724 | 136 | 245 | 0.0476 | 0.0089 | 0.0727 |
| LAX-JFK | 15812 | 799 | 118 | 228 | 0.0505 | 0.0075 | 0.0724 |
| SEA-DEN | 3347 | 172 | 0 | 65 | 0.0514 | 0.0000 | 0.0708 |
| JFK-LAS | 8598 | 447 | 0 | 136 | 0.0520 | 0.0000 | 0.0678 |
| JFK-ORD | 14517 | 631 | 119 | 230 | 0.0435 | 0.0082 | 0.0675 |
| HNL-LAX | 8842 | 457 | 0 | 136 | 0.0517 | 0.0000 | 0.0671 |
| MCO-BOS | 5404 | 288 | 0 | 73 | 0.0533 | 0.0000 | 0.0668 |
| DEN-SEA | 3455 | 189 | 0 | 38 | 0.0547 | 0.0000 | 0.0657 |

_Se muestran 15 de 22 filas; el resultado completo está en el CSV._

**Interpretación**

En los vuelos de septiembre y octubre se vendieron 203 846 tiquetes: el 4,87 % se canceló de forma voluntaria (generador: 5 %), el 0,94 % por cancelación del vuelo y el 1,51 % por vencimiento de la reserva. La tasa voluntaria por ruta oscila entre 4,4 % y 5,5 %, dentro de lo esperable por azar con estos volúmenes. Las diferencias en la tasa total entre rutas se deben sobre todo a las cancelaciones de vuelos (por ejemplo, ORD-DFW 3,3 %), que son eventos poco frecuentes y concentrados.

## Q10 · Utilización de la flota

- **Pregunta:** ¿Cuántas horas diarias vuela cada avión y cuáles están subutilizados?
- **Utilidad:** planificación de flota, reservas y mantenimiento.
- **Granularidad:** una fila por avión.
- **Filtros:** vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** horas bloque programadas = SUM(minutos programados) / 60; utilización media = horas bloque / días del período (no solo días con vuelos); días activos = días con al menos un vuelo.
- **Técnicas:** LEFT JOIN (incluye aviones sin vuelos), agregación sobre vista, RANK().
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q10_utilizacion_flota.sql` → `reports/resultados/Q10_utilizacion_flota.csv` (17 filas, 25 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q10 · Utilización de la flota
   Pregunta     : ¿Cuántas horas diarias vuela cada avión y cuáles están subutilizados?
   Utilidad     : planificación de flota, reservas y mantenimiento.
   Granularidad : una fila por avión.
   Filtros      : vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta.
   Fórmulas     : horas bloque programadas = SUM(minutos programados) / 60;
                  utilización media = horas bloque / días del período (no solo días con vuelos);
                  días activos = días con al menos un vuelo.
   Técnicas     : LEFT JOIN (incluye aviones sin vuelos), agregación sobre vista, RANK().
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH uso AS (
    SELECT u.id_avion, COUNT(*) AS dias_activos, SUM(u.vuelos) AS vuelos,
           SUM(u.minutos_bloque_programados) AS minutos_programados, SUM(u.minutos_bloque_reales) AS minutos_reales
    FROM rpt.v_utilizacion_avion_dia AS u
    WHERE u.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY u.id_avion
)
SELECT a.matricula,
       m.modelo,
       a.estado_operativo,
       ISNULL(u.dias_activos, 0)                                                     AS dias_activos,
       ISNULL(u.vuelos, 0)                                                           AS vuelos,
       CAST(ISNULL(u.minutos_programados, 0) / 60.0 AS DECIMAL(9,1))                 AS horas_bloque_programadas,
       CAST(ISNULL(u.minutos_reales, 0) / 60.0 AS DECIMAL(9,1))                      AS horas_bloque_reales,
       CAST(ISNULL(u.minutos_programados, 0) / 60.0 / (DATEDIFF(DAY, @fecha_desde, @fecha_hasta) + 1) AS DECIMAL(5,2)) AS horas_promedio_por_dia,
       RANK() OVER (ORDER BY ISNULL(u.minutos_programados, 0) DESC)                  AS rango_utilizacion
FROM ops.avion AS a
JOIN ops.configuracion_asientos AS c ON c.id_configuracion = a.id_configuracion
JOIN ref.modelo_avion AS m ON m.id_modelo = c.id_modelo
LEFT JOIN uso AS u ON u.id_avion = a.id_avion
ORDER BY rango_utilizacion, a.matricula;
```

</details>

**Resultado ejecutado**

| matricula | modelo | estado_operativo | dias_activos | vuelos | horas_bloque_programadas | horas_bloque_reales | horas_promedio_por_dia | rango_utilizacion |
|---|---|---|---|---|---|---|---|---|
| N323XA | A321neo | ACTIVO | 58 | 116 | 681.5 | 666.9 | 11.17 | 1 |
| N322XA | A321neo | ACTIVO | 58 | 115 | 656.0 | 646.3 | 10.75 | 2 |
| N321XA | A321neo | ACTIVO | 58 | 114 | 650.8 | 634.7 | 10.67 | 3 |
| N201XA | A320neo | ACTIVO | 58 | 231 | 644.9 | 635.3 | 10.57 | 4 |
| N324XA | A321neo | ACTIVO | 58 | 116 | 609.0 | 602.7 | 9.98 | 5 |
| N801XA | 737-800 | ACTIVO | 58 | 228 | 465.8 | 460.5 | 7.64 | 6 |
| N175XA | E175 | ACTIVO | 58 | 226 | 395.5 | 389.7 | 6.48 | 7 |
| N203XA | A320neo | ACTIVO | 58 | 114 | 347.2 | 343.7 | 5.69 | 8 |
| N176XA | E175 | ACTIVO | 58 | 116 | 309.3 | 307.2 | 5.07 | 9 |
| N803XA | 737-800 | ACTIVO | 58 | 115 | 263.4 | 261.7 | 4.32 | 10 |
| N802XA | 737-800 | ACTIVO | 58 | 114 | 246.8 | 244.3 | 4.05 | 11 |
| N202XA | A320neo | ACTIVO | 40 | 80 | 230.0 | 228.0 | 3.77 | 12 |
| N325XA | A321neo | ACTIVO | 12 | 23 | 129.1 | 123.3 | 2.12 | 13 |
| N204XA | A320neo | ACTIVO | 9 | 24 | 69.0 | 68.2 | 1.13 | 14 |
| N804XA | 737-800 | ACTIVO | 9 | 24 | 51.3 | 50.8 | 0.84 | 15 |

_Se muestran 15 de 17 filas; el resultado completo está en el CSV._

**Interpretación**

Los A321neo de las líneas transcontinentales y de Hawái promedian entre 10,0 y 11,2 horas de bloque programadas por día; los Embraer E175, entre 5,1 y 6,5 horas; los aviones de reserva (N325XA, N204XA, N804XA, N177XA) vuelan solo los días de mantenimiento programado del titular, de 0,6 a 2,1 horas por día del período; y N805XA no vuela porque está en mantenimiento. La utilización se divide entre todos los días del período, no solo entre los días con vuelo, para no sobrestimarla. Las horas reales son algo menores que las programadas por dos razones del generador: la duración real se genera entre el 93 % y el 105 % de la programada (media 99 %), y los vuelos del final del período que no habían aterrizado a la fecha de corte no suman horas reales.

## Q11 · Distribución de la demanda por día de la semana y franja horaria

- **Pregunta:** ¿Qué días y horas de salida concentran la demanda?
- **Utilidad:** ajustar frecuencias y horarios de la programación semanal.
- **Granularidad:** una fila por día de la semana (ISO, 1 = lunes) y franja de salida local.
- **Filtros:** vuelos ATERRIZADOS con fecha local entre @fecha_desde y @fecha_hasta.
- **Fórmulas:** factor = pasajeros volados / asientos ofrecidos (ponderado). El día se calcula sin depender de SET DATEFIRST (vista rpt.v_vuelo).
- **Técnicas:** CTE, CASE para franjas, GROUP BY de dos dimensiones.
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q11_demanda_dia_hora.sql` → `reports/resultados/Q11_demanda_dia_hora.csv` (28 filas, 140 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q11 · Distribución de la demanda por día de la semana y franja horaria
   Pregunta     : ¿Qué días y horas de salida concentran la demanda?
   Utilidad     : ajustar frecuencias y horarios de la programación semanal.
   Granularidad : una fila por día de la semana (ISO, 1 = lunes) y franja de salida local.
   Filtros      : vuelos ATERRIZADOS con fecha local entre @fecha_desde y @fecha_hasta.
   Fórmula      : factor = pasajeros volados / asientos ofrecidos (ponderado).
                  El día se calcula sin depender de SET DATEFIRST (vista rpt.v_vuelo).
   Técnicas     : CTE, CASE para franjas, GROUP BY de dos dimensiones.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT v.dia_semana_iso,
           CASE WHEN v.hora_salida_local < 9 THEN '1. Madrugada-mañana (<09h)'
                WHEN v.hora_salida_local < 13 THEN '2. Media mañana (09-13h)'
                WHEN v.hora_salida_local < 18 THEN '3. Tarde (13-18h)'
                ELSE '4. Noche (>=18h)' END AS franja,
           o.capacidad, o.usados
    FROM rpt.v_vuelo AS v
    JOIN rpt.v_ocupacion_vuelo_cabina AS o ON o.id_vuelo = v.id_vuelo
    WHERE v.codigo_estado = 'ATERRIZADO' AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
)
SELECT dia_semana_iso,
       CHOOSE(dia_semana_iso, 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo') AS dia,
       franja,
       SUM(usados)                                                   AS pasajeros_volados,
       SUM(capacidad)                                                AS asientos_ofrecidos,
       CAST(SUM(usados) * 1.0 / SUM(capacidad) AS DECIMAL(7,4))      AS factor_ocupacion
FROM base
GROUP BY dia_semana_iso, franja
ORDER BY dia_semana_iso, franja;
```

</details>

**Resultado ejecutado**

| dia_semana_iso | dia | franja | pasajeros_volados | asientos_ofrecidos | factor_ocupacion |
|---|---|---|---|---|---|
| 1 | lunes | 1. Madrugada-mañana (<09h) | 7288 | 10880 | 0.6699 |
| 1 | lunes | 2. Media mañana (09-13h) | 7350 | 10448 | 0.7035 |
| 1 | lunes | 3. Tarde (13-18h) | 6889 | 10272 | 0.6707 |
| 1 | lunes | 4. Noche (>=18h) | 3067 | 4366 | 0.7025 |
| 2 | martes | 1. Madrugada-mañana (<09h) | 6543 | 10594 | 0.6176 |
| 2 | martes | 2. Media mañana (09-13h) | 6614 | 10220 | 0.6472 |
| 2 | martes | 3. Tarde (13-18h) | 6759 | 11396 | 0.5931 |
| 2 | martes | 4. Noche (>=18h) | 3175 | 5198 | 0.6108 |
| 3 | miércoles | 1. Madrugada-mañana (<09h) | 6094 | 10330 | 0.5899 |
| 3 | miércoles | 2. Media mañana (09-13h) | 6330 | 10296 | 0.6148 |
| 3 | miércoles | 3. Tarde (13-18h) | 6526 | 11130 | 0.5863 |
| 3 | miércoles | 4. Noche (>=18h) | 3223 | 5274 | 0.6111 |
| 4 | jueves | 1. Madrugada-mañana (<09h) | 8420 | 12164 | 0.6922 |
| 4 | jueves | 2. Media mañana (09-13h) | 8193 | 11594 | 0.7067 |
| 4 | jueves | 3. Tarde (13-18h) | 7682 | 11480 | 0.6692 |

_Se muestran 15 de 28 filas; el resultado completo está en el CSV._

**Interpretación**

La ocupación más alta se da los viernes (72 % a 78 % según la franja) y los domingos; la más baja, martes y miércoles (59 % a 65 %). El patrón reproduce los factores por día de la semana del generador (viernes 1,08; miércoles 0,88), lo que valida el cálculo del día ISO, que no depende de `SET DATEFIRST`. Las franjas nocturnas ofrecen menos asientos porque hay menos salidas después de las 18 h; por eso se presenta el factor de ocupación y no solo el número de pasajeros.

## Q12 · Anticipación de la compra y precio pagado

- **Pregunta:** ¿Con cuánta anticipación compran los pasajeros y cuánto pagan según esa anticipación?
- **Utilidad:** diseñar promociones de compra anticipada y estimar ventas futuras.
- **Granularidad:** una fila por tramo de anticipación (días entre la venta y la salida).
- **Filtros:** tiquetes de vuelos ya operados entre @fecha_desde y @fecha_hasta (curva completa).
- **Fórmulas:** participación = tiquetes del tramo / total (SUM() OVER ()); precio medio por cabina. El precio depende de la tarifa vigente en la fecha de venta y del descuento; la relación es descriptiva y no demuestra causalidad.
- **Técnicas:** CTE, CASE, función de ventana sobre agregados, pivote por cabina.
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q12_anticipacion_compra.sql` → `reports/resultados/Q12_anticipacion_compra.csv` (5 filas, 133 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q12 · Anticipación de la compra y precio pagado
   Pregunta     : ¿Con cuánta anticipación compran los pasajeros y cuánto pagan según esa anticipación?
   Utilidad     : diseñar promociones de compra anticipada y estimar ventas futuras.
   Granularidad : una fila por tramo de anticipación (días entre la venta y la salida).
   Filtros      : tiquetes de vuelos ya operados entre @fecha_desde y @fecha_hasta (curva completa).
   Fórmulas     : participación = tiquetes del tramo / total (SUM() OVER ()); precio medio por cabina.
                  El precio depende de la tarifa vigente en la fecha de venta y del descuento; la
                  relación es descriptiva y no demuestra causalidad.
   Técnicas     : CTE, CASE, función de ventana sobre agregados, pivote por cabina.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT CASE WHEN dias_anticipacion < 7 THEN '1. 0-6 días'
                WHEN dias_anticipacion < 14 THEN '2. 7-13 días'
                WHEN dias_anticipacion < 30 THEN '3. 14-29 días'
                WHEN dias_anticipacion < 60 THEN '4. 30-59 días'
                ELSE '5. 60 días o más' END AS tramo,
           codigo_cabina, precio_final_usd, porcentaje_descuento
    FROM rpt.v_venta
    WHERE fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
)
SELECT tramo,
       COUNT(*)                                                                         AS tiquetes,
       CAST(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER () AS DECIMAL(7,4))                     AS participacion,
       CAST(AVG(CASE WHEN codigo_cabina = 'ECO' THEN precio_final_usd END) AS DECIMAL(10,2)) AS precio_medio_eco_usd,
       CAST(AVG(CASE WHEN codigo_cabina = 'VIP' THEN precio_final_usd END) AS DECIMAL(10,2)) AS precio_medio_vip_usd,
       CAST(SUM(CASE WHEN porcentaje_descuento > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS penetracion_descuentos
FROM base
GROUP BY tramo
ORDER BY tramo;
```

</details>

**Resultado ejecutado**

| tramo | tiquetes | participacion | precio_medio_eco_usd | precio_medio_vip_usd | penetracion_descuentos |
|---|---|---|---|---|---|
| 1. 0-6 días | 34958 | 0.1715 | 206.82 | 573.34 | 0.1362 |
| 2. 7-13 días | 30675 | 0.1505 | 205.31 | 556.84 | 0.1380 |
| 3. 14-29 días | 46210 | 0.2267 | 202.26 | 558.59 | 0.1322 |
| 4. 30-59 días | 52182 | 0.2560 | 191.05 | 538.76 | 0.2591 |
| 5. 60 días o más | 39821 | 0.1953 | 179.94 | 536.27 | 0.4712 |

**Interpretación**

El 17,2 % de los tiquetes se compró con menos de 7 días de anticipación y el 19,5 % con 60 días o más. El precio medio en económica baja de 206,82 USD (0-6 días) a 179,94 USD (60 días o más) y la penetración de descuentos sube de 13,6 % a 47,1 %. Ambos hechos se explican por cómo están construidas las reglas sintéticas (el descuento `ANTICIPA15` exige anticipación y las tarifas cambian de versión con el tiempo); la consulta describe esa asociación, pero no demuestra que comprar antes «cause» un precio menor en un mercado real.

## Q13 · Clientes registrados de mayor valor

- **Pregunta:** ¿Qué clientes registrados generan más cobro neto?
- **Utilidad:** segmentación para fidelización (niveles de lealtad, beneficios).
- **Granularidad:** una fila por cliente (los @top primeros).
- **Filtros:** compras realizadas como comprador registrado.
- **Fórmulas:** cobro neto por cliente = SUM(pagos confirmados - reembolsos) de sus tiquetes, calculado desde rpt.v_tiquete_financiero (ya agregado por tiquete, sin duplicar).
- **Técnicas:** CTE, JOIN, DENSE_RANK(), TOP con parámetro.
- **Parámetros usados:** `@top` = 10
- **Archivos:** `sql/consultas/Q13_clientes_mayor_valor.sql` → `reports/resultados/Q13_clientes_mayor_valor.csv` (10 filas, 550 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q13 · Clientes registrados de mayor valor
   Pregunta     : ¿Qué clientes registrados generan más cobro neto?
   Utilidad     : segmentación para fidelización (niveles de lealtad, beneficios).
   Granularidad : una fila por cliente (los @top primeros).
   Filtros      : compras realizadas como comprador registrado.
   Fórmulas     : cobro neto por cliente = SUM(pagos confirmados - reembolsos) de sus tiquetes,
                  calculado desde rpt.v_tiquete_financiero (ya agregado por tiquete, sin duplicar).
   Técnicas     : CTE, JOIN, DENSE_RANK(), TOP con parámetro.
   ============================================================================= */
DECLARE @top INT = 10;   -- @param

WITH por_cliente AS (
    SELECT c.id_persona_comprador AS id_persona,
           COUNT(DISTINCT c.id_compra) AS compras,
           COUNT(*)                    AS tiquetes,
           SUM(f.cobro_neto_usd)       AS cobro_neto_usd
    FROM ven.compra AS c
    JOIN ven.cliente AS cl ON cl.id_persona = c.id_persona_comprador AND cl.fecha_registro_utc <= c.fecha_compra_utc
    JOIN rpt.v_tiquete_financiero AS f ON f.id_compra = c.id_compra
    GROUP BY c.id_persona_comprador
)
SELECT TOP (@top)
       DENSE_RANK() OVER (ORDER BY p.cobro_neto_usd DESC) AS rango,
       cl.numero_viajero,
       cl.nivel_lealtad,
       p.compras,
       p.tiquetes,
       p.cobro_neto_usd,
       CAST(p.cobro_neto_usd / p.tiquetes AS DECIMAL(10,2)) AS cobro_neto_por_tiquete_usd
FROM por_cliente AS p
JOIN ven.cliente AS cl ON cl.id_persona = p.id_persona
ORDER BY rango, cl.numero_viajero;
```

</details>

**Resultado ejecutado**

| rango | numero_viajero | nivel_lealtad | compras | tiquetes | cobro_neto_usd | cobro_neto_por_tiquete_usd |
|---|---|---|---|---|---|---|
| 1 | VF00000001 | BASICO | 228 | 427 | 79822.33 | 186.94 |
| 2 | VF00000717 | BASICO | 85 | 165 | 30793.50 | 186.63 |
| 3 | VF00001433 | PLATA | 60 | 118 | 25275.01 | 214.20 |
| 4 | VF00003581 | BASICO | 38 | 97 | 23150.97 | 238.67 |
| 5 | VF00007680 | PLATA | 59 | 100 | 20626.68 | 206.27 |
| 6 | VF00015359 | BASICO | 50 | 84 | 18345.27 | 218.40 |
| 7 | VF00001111 | BASICO | 39 | 75 | 17521.47 | 233.62 |
| 8 | VF00007161 | BASICO | 23 | 67 | 16046.56 | 239.50 |
| 9 | VF00000073 | BASICO | 35 | 61 | 14448.22 | 236.86 |
| 10 | VF00000270 | BASICO | 24 | 61 | 14340.15 | 235.08 |

**Interpretación**

Los diez clientes registrados de mayor cobro neto suman entre 14 340 y 79 822 USD cada uno. El primero (VF00000001) acumula 228 compras y 427 tiquetes en cuatro meses, consecuencia de la distribución de Pareto del generador. En datos reales, un valor así merecería revisión (podría tratarse de una cuenta corporativa o de una agencia) antes de tomar decisiones de fidelización. El cobro neto se toma de la vista financiera, que agrega pagos y reembolsos por tiquete antes de unir, para no duplicar importes.

## Q14 · Registros sin actividad (anti-joins)

- **Pregunta:** ¿Qué clientes, rutas, aviones y descuentos no tienen actividad?
- **Utilidad:** limpieza comercial, rutas en evaluación, flota de reserva y campañas sin uso.
- **Granularidad:** una fila por categoría.
- **Filtros:** situación a la fecha de corte.
- **Fórmulas:** conteo de filas sin correspondencia (LEFT JOIN ... IS NULL / NOT EXISTS).
- **Técnicas:** LEFT JOIN con IS NULL, NOT EXISTS, UNION ALL.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q14_registros_sin_actividad.sql` → `reports/resultados/Q14_registros_sin_actividad.csv` (5 filas, 83 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q14 · Registros sin actividad (anti-joins)
   Pregunta     : ¿Qué clientes, rutas, aviones y descuentos no tienen actividad?
   Utilidad     : limpieza comercial, rutas en evaluación, flota de reserva y campañas sin uso.
   Granularidad : una fila por categoría.
   Filtros      : situación a la fecha de corte.
   Fórmula      : conteo de filas sin correspondencia (LEFT JOIN ... IS NULL / NOT EXISTS).
   Técnicas     : LEFT JOIN con IS NULL, NOT EXISTS, UNION ALL.
   ============================================================================= */
SELECT 'Clientes registrados sin compras' AS categoria, COUNT(*) AS cantidad
FROM ven.cliente AS cl
LEFT JOIN ven.compra AS c ON c.id_persona_comprador = cl.id_persona
WHERE c.id_compra IS NULL
UNION ALL
SELECT 'Rutas sin programación (en evaluación)', COUNT(*)
FROM ops.ruta AS r
WHERE NOT EXISTS (SELECT 1 FROM ops.programacion AS p WHERE p.id_ruta = r.id_ruta)
UNION ALL
SELECT 'Aviones sin vuelos asignados', COUNT(*)
FROM ops.avion AS a
LEFT JOIN ops.vuelo AS v ON v.id_avion = a.id_avion
WHERE v.id_vuelo IS NULL
UNION ALL
SELECT 'Descuentos nunca aplicados', COUNT(*)
FROM ven.descuento AS d
WHERE NOT EXISTS (SELECT 1 FROM ven.tiquete AS t WHERE t.id_descuento = d.id_descuento)
UNION ALL
SELECT 'Empleados de cabina o vuelo sin asignaciones', COUNT(*)
FROM rh.empleado AS e
JOIN rh.cargo AS c ON c.codigo_cargo = e.codigo_cargo AND c.categoria_tripulacion IS NOT NULL
WHERE NOT EXISTS (SELECT 1 FROM ops.asignacion_tripulacion AS a WHERE a.id_empleado = e.id_empleado)
ORDER BY 1;   -- orden determinista del UNION ALL (por categoría)
```

</details>

**Resultado ejecutado**

| categoria | cantidad |
|---|---|
| Aviones sin vuelos asignados | 1 |
| Clientes registrados sin compras | 7299 |
| Descuentos nunca aplicados | 2 |
| Empleados de cabina o vuelo sin asignaciones | 0 |
| Rutas sin programación (en evaluación) | 2 |

**Interpretación**

Hay 7 299 clientes registrados sin ninguna compra, 2 rutas sin programación (BOS-ORD y ORD-BOS, en evaluación), 1 avión sin vuelos (N805XA, en mantenimiento), 2 descuentos nunca aplicados (`INVIERNO25`, cuya vigencia empieza después del corte, y `VIPPLUS5`, ver Q20) y ningún tripulante sin asignaciones. Son consultas de calidad de datos: muestran registros que existen pero no participan en la operación y que conviene revisar.

## Q15 · Puntualidad y cancelaciones operativas por ruta

- **Pregunta:** ¿Qué rutas llegan a tiempo y cuáles acumulan demoras o cancelaciones?
- **Utilidad:** gestión operativa y de servicio.
- **Granularidad:** una fila por ruta.
- **Filtros:** vuelos con fecha local entre @fecha_desde y @fecha_hasta y salida anterior a la fecha de corte.
- **Fórmulas:** a tiempo = llegada real menos de 15 min después de la programada (criterio usado por la estadística de puntualidad de EE. UU.); % a tiempo = a tiempo / vuelos ATERRIZADOS; tasa de cancelación = CANCELADOS / (ATERRIZADOS + CANCELADOS); p90 con PERCENTILE_CONT.
- **Técnicas:** CTE, PERCENTILE_CONT ... OVER (PARTITION BY), agregación condicional.
- **Parámetros usados:** `@fecha_desde` = 2026-09-01, `@fecha_hasta` = 2026-10-31
- **Archivos:** `sql/consultas/Q15_puntualidad.sql` → `reports/resultados/Q15_puntualidad.csv` (22 filas, 49 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q15 · Puntualidad y cancelaciones operativas por ruta
   Pregunta     : ¿Qué rutas llegan a tiempo y cuáles acumulan demoras o cancelaciones?
   Utilidad     : gestión operativa y de servicio.
   Granularidad : una fila por ruta.
   Filtros      : vuelos con fecha local entre @fecha_desde y @fecha_hasta y salida anterior a la fecha de corte.
   Fórmulas     : a tiempo = llegada real menos de 15 min después de la programada (criterio usado por
                  la estadística de puntualidad de EE. UU.); % a tiempo = a tiempo / vuelos ATERRIZADOS;
                  tasa de cancelación = CANCELADOS / (ATERRIZADOS + CANCELADOS); p90 con PERCENTILE_CONT.
   Técnicas     : CTE, PERCENTILE_CONT ... OVER (PARTITION BY), agregación condicional.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-09-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-31';   -- @param

WITH base AS (
    SELECT v.ruta, v.codigo_estado, v.demora_llegada_min,
           PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY v.demora_llegada_min) OVER (PARTITION BY v.ruta) AS p90_demora
    FROM rpt.v_vuelo AS v
    WHERE v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
      AND v.codigo_estado IN ('ATERRIZADO', 'CANCELADO')
)
SELECT ruta,
       SUM(CASE WHEN codigo_estado = 'ATERRIZADO' THEN 1 ELSE 0 END)                         AS vuelos_operados,
       SUM(CASE WHEN codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END)                          AS vuelos_cancelados,
       CAST(SUM(CASE WHEN codigo_estado = 'ATERRIZADO' AND demora_llegada_min < 15 THEN 1 ELSE 0 END) * 1.0
            / NULLIF(SUM(CASE WHEN codigo_estado = 'ATERRIZADO' THEN 1 ELSE 0 END), 0) AS DECIMAL(7,4)) AS puntualidad,
       CAST(AVG(CASE WHEN codigo_estado = 'ATERRIZADO' THEN demora_llegada_min * 1.0 END) AS DECIMAL(7,1)) AS demora_media_llegada_min,
       CAST(MAX(p90_demora) AS DECIMAL(7,1))                                                AS p90_demora_llegada_min,
       CAST(SUM(CASE WHEN codigo_estado = 'CANCELADO' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS DECIMAL(7,4)) AS tasa_cancelacion
FROM base
GROUP BY ruta
ORDER BY puntualidad;
```

</details>

**Resultado ejecutado**

| ruta | vuelos_operados | vuelos_cancelados | puntualidad | demora_media_llegada_min | p90_demora_llegada_min | tasa_cancelacion |
|---|---|---|---|---|---|---|
| HNL-LAX | 60 | 0 | 0.7000 | 18.0 | 97.4 | 0.0000 |
| MIA-ATL | 119 | 2 | 0.7143 | 17.8 | 59.8 | 0.0165 |
| LAX-HNL | 61 | 0 | 0.7377 | 9.0 | 33.0 | 0.0000 |
| DFW-ORD | 61 | 0 | 0.7377 | 15.3 | 61.0 | 0.0000 |
| MIA-JFK | 120 | 1 | 0.7583 | 13.5 | 53.4 | 0.0083 |
| JFK-LAX | 119 | 3 | 0.7647 | 10.7 | 45.2 | 0.0246 |
| MCO-BOS | 43 | 0 | 0.7674 | 7.6 | 22.0 | 0.0000 |
| PHX-DFW | 61 | 0 | 0.7705 | 10.7 | 40.0 | 0.0000 |
| JFK-LAS | 61 | 0 | 0.7705 | 9.5 | 22.0 | 0.0000 |
| LAX-JFK | 119 | 1 | 0.7731 | 15.1 | 72.0 | 0.0083 |
| LAS-JFK | 60 | 0 | 0.7833 | 15.1 | 55.0 | 0.0000 |
| DFW-PHX | 60 | 1 | 0.7833 | 15.7 | 67.2 | 0.0164 |
| DEN-SEA | 61 | 0 | 0.7869 | 12.0 | 34.0 | 0.0000 |
| SEA-DEN | 61 | 0 | 0.7869 | 17.8 | 55.0 | 0.0000 |
| ORD-JFK | 118 | 3 | 0.7966 | 11.0 | 36.5 | 0.0248 |

_Se muestran 15 de 22 filas; el resultado completo está en el CSV._

**Interpretación**

De 1 767 vuelos operados, el 78,4 % llegó con menos de 15 minutos de demora; por ruta, entre 70,0 % (HNL-LAX) y 85,2 % (ATL-DEN). Se cancelaron 20 vuelos (1,1 %). El percentil 90 de la demora de llegada distingue rutas con demoras ocasionales largas (HNL-LAX, 97 minutos) de rutas con demoras frecuentes pero cortas. Las demoras se generan al azar y se propagan por avión, por lo que las diferencias entre rutas no deben atribuirse a aeropuertos ni a horarios.

## Q16 · Disponibilidad de los próximos vuelos

- **Pregunta:** ¿Cuántas plazas quedan por vender en los vuelos de los próximos días y a qué precio?
- **Utilidad:** consulta operativa de venta (CU-06) y alerta de vuelos con baja preventa.
- **Granularidad:** una fila por vuelo y cabina.
- **Filtros:** vuelos PROGRAMADOS o DEMORADOS con salida en los @dias días posteriores a la fecha de corte; @origen opcional (NULL = todos).
- **Fórmulas:** disponibles = capacidad - plazas ocupadas; tarifa = la vigente en la fecha de corte.
- **Técnicas:** OUTER APPLY con TOP (1), filtros temporales con parámetros, ISNULL.
- **Parámetros usados:** `@dias` = 3, `@origen` = None
- **Archivos:** `sql/consultas/Q16_disponibilidad_proximos_vuelos.sql` → `reports/resultados/Q16_disponibilidad_proximos_vuelos.csv` (170 filas, 52 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q16 · Disponibilidad de los próximos vuelos
   Pregunta     : ¿Cuántas plazas quedan por vender en los vuelos de los próximos días y a qué precio?
   Utilidad     : consulta operativa de venta (CU-06) y alerta de vuelos con baja preventa.
   Granularidad : una fila por vuelo y cabina.
   Filtros      : vuelos PROGRAMADOS o DEMORADOS con salida en los @dias días posteriores a la fecha de corte;
                  @origen opcional (NULL = todos).
   Fórmulas     : disponibles = capacidad - plazas ocupadas; tarifa = la vigente en la fecha de corte.
   Técnicas     : OUTER APPLY con TOP (1), filtros temporales con parámetros, ISNULL.
   ============================================================================= */
DECLARE @dias INT = 3;                  -- @param
DECLARE @origen CHAR(3) = NULL;         -- @param
DECLARE @fecha_corte DATETIME2(0) = (SELECT CAST(valor AS DATETIME2(0)) FROM ref.parametro WHERE clave = 'FECHA_CORTE_DATOS');

SELECT v.codigo_vuelo, v.ruta, v.salida_programada, o.codigo_cabina, o.estado_vuelo,
       o.capacidad, o.plazas_ocupadas, o.plazas_disponibles, o.factor_ocupacion_vendido,
       tf.precio_base_usd AS tarifa_vigente_usd
FROM rpt.v_ocupacion_vuelo_cabina AS o
JOIN rpt.v_vuelo AS v ON v.id_vuelo = o.id_vuelo
OUTER APPLY (SELECT TOP (1) t.precio_base_usd FROM ven.tarifa AS t
             WHERE t.id_ruta = v.id_ruta AND t.codigo_cabina = o.codigo_cabina
               AND CAST(@fecha_corte AS DATE) BETWEEN t.vigente_desde AND ISNULL(t.vigente_hasta, '99991231')) AS tf
WHERE o.estado_vuelo IN ('PROGRAMADO', 'DEMORADO')
  AND v.salida_programada_utc >= @fecha_corte
  AND v.salida_programada_utc <  DATEADD(DAY, @dias, @fecha_corte)
  AND (@origen IS NULL OR v.origen = @origen)
ORDER BY v.salida_programada_utc, v.codigo_vuelo, o.codigo_cabina;
```

</details>

**Resultado ejecutado**

| codigo_vuelo | ruta | salida_programada | codigo_cabina | estado_vuelo | capacidad | plazas_ocupadas | plazas_disponibles | factor_ocupacion_vendido | tarifa_vigente_usd |
|---|---|---|---|---|---|---|---|---|---|
| XX111 | LAX-JFK | 2026-10-31 22:30:00-07:00 | ECO | PROGRAMADO | 168 | 114 | 54 | 0.6786 | 354.99 |
| XX111 | LAX-JFK | 2026-10-31 22:30:00-07:00 | VIP | PROGRAMADO | 20 | 9 | 11 | 0.4500 | 976.99 |
| XX201 | JFK-MIA | 2026-11-01 06:30:00-05:00 | ECO | PROGRAMADO | 150 | 133 | 17 | 0.8867 | 175.99 |
| XX201 | JFK-MIA | 2026-11-01 06:30:00-05:00 | VIP | PROGRAMADO | 12 | 6 | 6 | 0.5000 | 469.99 |
| XX101 | JFK-LAX | 2026-11-01 07:00:00-05:00 | ECO | PROGRAMADO | 168 | 154 | 14 | 0.9167 | 354.99 |
| XX101 | JFK-LAX | 2026-11-01 07:00:00-05:00 | VIP | PROGRAMADO | 20 | 18 | 2 | 0.9000 | 976.99 |
| XX401 | JFK-ORD | 2026-11-01 07:00:00-05:00 | ECO | PROGRAMADO | 144 | 124 | 20 | 0.8611 | 136.99 |
| XX401 | JFK-ORD | 2026-11-01 07:00:00-05:00 | VIP | PROGRAMADO | 16 | 9 | 7 | 0.5625 | 365.99 |
| XX301 | BOS-MCO | 2026-11-01 07:15:00-05:00 | ECO | PROGRAMADO | 150 | 118 | 32 | 0.7867 | 179.99 |
| XX301 | BOS-MCO | 2026-11-01 07:15:00-05:00 | VIP | PROGRAMADO | 12 | 5 | 7 | 0.4167 | 481.99 |
| XX701 | ATL-MIA | 2026-11-01 07:30:00-05:00 | ECO | PROGRAMADO | 64 | 37 | 27 | 0.5781 | 104.99 |
| XX701 | ATL-MIA | 2026-11-01 07:30:00-05:00 | VIP | PROGRAMADO | 12 | 7 | 5 | 0.5833 | 289.99 |
| XX112 | JFK-LAX | 2026-11-01 08:30:00-05:00 | ECO | PROGRAMADO | 168 | 143 | 25 | 0.8512 | 354.99 |
| XX112 | JFK-LAX | 2026-11-01 08:30:00-05:00 | VIP | PROGRAMADO | 20 | 11 | 9 | 0.5500 | 976.99 |
| XX1101 | JFK-LAS | 2026-11-01 09:00:00-05:00 | ECO | PROGRAMADO | 168 | 134 | 34 | 0.7976 | 307.99 |

_Se muestran 15 de 170 filas; el resultado completo está en el CSV._

**Interpretación**

Para los tres días posteriores al corte hay 85 vuelos programados (170 combinaciones de vuelo y cabina) con su disponibilidad y la tarifa vigente; una de esas cabinas ya está agotada. Es la consulta típica de un canal de venta y muestra el uso de `OUTER APPLY` con `TOP (1)` para tomar la tarifa vigente en una fecha.

## Q17 · Evolución mensual de las ventas (variación y acumulado)

- **Pregunta:** ¿Cómo crece la venta mes a mes desde la apertura?
- **Utilidad:** seguimiento de la curva de arranque de una aerolínea nueva.
- **Granularidad:** una fila por mes de venta y cabina.
- **Filtros:** tiquetes no cancelados vendidos hasta la fecha de corte.
- **Fórmulas:** variación = (ventas del mes - ventas del mes anterior) / ventas del mes anterior (LAG); acumulado = SUM() OVER (ORDER BY mes ROWS UNBOUNDED PRECEDING). El último mes puede estar incompleto según la fecha de corte.
- **Técnicas:** CTE, LAG(), SUM() OVER con marco de ventana, NULLIF.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q17_evolucion_mensual.sql` → `reports/resultados/Q17_evolucion_mensual.csv` (8 filas, 115 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q17 · Evolución mensual de las ventas (variación y acumulado)
   Pregunta     : ¿Cómo crece la venta mes a mes desde la apertura?
   Utilidad     : seguimiento de la curva de arranque de una aerolínea nueva.
   Granularidad : una fila por mes de venta y cabina.
   Filtros      : tiquetes no cancelados vendidos hasta la fecha de corte.
   Fórmulas     : variación = (ventas del mes - ventas del mes anterior) / ventas del mes anterior (LAG);
                  acumulado = SUM() OVER (ORDER BY mes ROWS UNBOUNDED PRECEDING).
                  El último mes puede estar incompleto según la fecha de corte.
   Técnicas     : CTE, LAG(), SUM() OVER con marco de ventana, NULLIF.
   ============================================================================= */
WITH mensual AS (
    SELECT DATEFROMPARTS(YEAR(fecha_venta), MONTH(fecha_venta), 1) AS mes, codigo_cabina,
           COUNT(*) AS tiquetes, SUM(precio_final_usd) AS ventas_usd
    FROM rpt.v_venta
    WHERE codigo_estado <> 'CANCELADO'
    GROUP BY DATEFROMPARTS(YEAR(fecha_venta), MONTH(fecha_venta), 1), codigo_cabina
)
SELECT mes, codigo_cabina, tiquetes, ventas_usd,
       LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes)                         AS ventas_mes_anterior_usd,
       CAST((ventas_usd - LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes))
            / NULLIF(LAG(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes), 0) AS DECIMAL(9,4)) AS variacion,
       SUM(ventas_usd) OVER (PARTITION BY codigo_cabina ORDER BY mes ROWS UNBOUNDED PRECEDING)   AS ventas_acumuladas_usd
FROM mensual
ORDER BY codigo_cabina, mes;
```

</details>

**Resultado ejecutado**

| mes | codigo_cabina | tiquetes | ventas_usd | ventas_mes_anterior_usd | variacion | ventas_acumuladas_usd |
|---|---|---|---|---|---|---|
| 2026-07-01 | ECO | 41192 | 7341089.68 |  |  | 7341089.68 |
| 2026-08-01 | ECO | 59994 | 11607743.41 | 7341089.68 | 0.5812 | 18948833.09 |
| 2026-09-01 | ECO | 88797 | 17872762.62 | 11607743.41 | 0.5397 | 36821595.71 |
| 2026-10-01 | ECO | 87559 | 18464999.78 | 17872762.62 | 0.0331 | 55286595.49 |
| 2026-07-01 | VIP | 3483 | 1856246.77 |  |  | 1856246.77 |
| 2026-08-01 | VIP | 5161 | 2833293.29 | 1856246.77 | 0.5264 | 4689540.06 |
| 2026-09-01 | VIP | 7601 | 4231678.15 | 2833293.29 | 0.4936 | 8921218.21 |
| 2026-10-01 | VIP | 7203 | 4182526.45 | 4231678.15 | -0.0116 | 13103744.66 |

**Interpretación**

Las ventas vigentes crecieron de 9,20 millones de USD en julio a 22,65 millones en octubre. En económica, el crecimiento fue de 58,1 % en agosto, 54,0 % en septiembre y 3,3 % en octubre; en VIP, octubre cayó 1,2 %. El crecimiento inicial refleja el inicio de las ventas (1 de julio) y el de las operaciones (1 de septiembre). Octubre se acerca a un nivel estable, pero con cuatro meses no se puede hablar de tendencia ni de estacionalidad.

## Q18 · Carga de vuelo de la tripulación en 672 horas consecutivas

- **Pregunta:** ¿Cómo se reparte la carga de vuelo y algún piloto excede el límite acumulado?
- **Utilidad:** planificación de personal y control de cumplimiento; control de la regla RN-35.
- **Granularidad:** una fila por rol de vuelo.
- **Filtros:** vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta (28 días = 672 horas, la ventana del límite de 14 CFR 117.23(b)(1)).
- **Fórmulas:** horas por tripulante = minutos de bloque programados / 60 (cota superior del tiempo de vuelo); pilotos sobre el límite = pilotos con más de 100 h en la ventana; vuelos operados sin dos pilotos (debe ser 0: lo impide el trigger de vuelo). El límite se aplica a pilotos; para tripulantes de cabina es solo referencia.
- **Técnicas:** CTE, agregaciones, agregación condicional, subconsulta escalar de control.
- **Parámetros usados:** `@fecha_desde` = 2026-10-01, `@fecha_hasta` = 2026-10-28
- **Archivos:** `sql/consultas/Q18_tripulacion_horas.sql` → `reports/resultados/Q18_tripulacion_horas.csv` (4 filas, 33 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q18 · Carga de vuelo de la tripulación en 672 horas consecutivas
   Pregunta     : ¿Cómo se reparte la carga de vuelo y algún piloto excede el límite acumulado?
   Utilidad     : planificación de personal y control de cumplimiento; control de la regla RN-35.
   Granularidad : una fila por rol de vuelo.
   Filtros      : vuelos no cancelados con fecha local entre @fecha_desde y @fecha_hasta
                  (28 días = 672 horas, la ventana del límite de 14 CFR 117.23(b)(1)).
   Fórmulas     : horas por tripulante = minutos de bloque programados / 60 (cota superior del tiempo de
                  vuelo); pilotos sobre el límite = pilotos con más de 100 h en la ventana;
                  vuelos operados sin dos pilotos (debe ser 0: lo impide el trigger de vuelo).
                  El límite se aplica a pilotos; para tripulantes de cabina es solo referencia.
   Técnicas     : CTE, agregaciones, agregación condicional, subconsulta escalar de control.
   ============================================================================= */
DECLARE @fecha_desde DATE = '2026-10-01';   -- @param
DECLARE @fecha_hasta DATE = '2026-10-28';   -- @param

WITH por_tripulante AS (
    SELECT t.rol_vuelo, t.id_empleado, COUNT(*) AS vuelos, SUM(t.duracion_programada_min) / 60.0 AS horas
    FROM rpt.v_tripulacion_vuelo AS t
    WHERE t.estado_vuelo <> 'CANCELADO' AND t.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
    GROUP BY t.rol_vuelo, t.id_empleado
)
SELECT rol_vuelo,
       COUNT(*)                                                         AS tripulantes,
       SUM(vuelos)                                                      AS asignaciones,
       CAST(MIN(horas) AS DECIMAL(7,1))                                 AS horas_minimas,
       CAST(AVG(horas) AS DECIMAL(7,1))                                 AS horas_promedio,
       CAST(MAX(horas) AS DECIMAL(7,1))                                 AS horas_maximas,
       SUM(CASE WHEN rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL') AND horas > 100 THEN 1 ELSE 0 END) AS pilotos_sobre_100h,
       (SELECT COUNT(*) FROM ops.vuelo AS v
        WHERE v.codigo_estado IN ('EN_VUELO', 'ATERRIZADO') AND v.fecha_salida_local BETWEEN @fecha_desde AND @fecha_hasta
          AND (SELECT COUNT(*) FROM ops.asignacion_tripulacion AS a
               WHERE a.id_vuelo = v.id_vuelo AND a.rol_vuelo IN ('CAPITAN', 'PRIMER_OFICIAL')) < 2) AS vuelos_operados_sin_pilotos
FROM por_tripulante
GROUP BY rol_vuelo
ORDER BY rol_vuelo;
```

</details>

**Resultado ejecutado**

| rol_vuelo | tripulantes | asignaciones | horas_minimas | horas_promedio | horas_maximas | pilotos_sobre_100h | vuelos_operados_sin_pilotos |
|---|---|---|---|---|---|---|---|
| AUXILIAR_VUELO | 140 | 2115 | 17.3 | 52.1 | 94.5 | 0 | 0 |
| CAPITAN | 52 | 815 | 17.3 | 51.1 | 94.5 | 0 | 0 |
| JEFE_CABINA | 52 | 815 | 17.3 | 51.1 | 94.5 | 0 | 0 |
| PRIMER_OFICIAL | 52 | 815 | 17.3 | 51.1 | 94.5 | 0 | 0 |

**Interpretación**

En la ventana de 672 horas consecutivas (1 al 28 de octubre de 2026), cada capitán y primer oficial asignado voló entre 17,3 y 94,5 horas de bloque programadas (media 51,1 h); ningún piloto supera la referencia de 100 horas de 14 CFR 117.23(b)(1), y ningún vuelo operó sin sus dos pilotos. La versión anterior de los datos sintéticos sí la superaba (ver H-16), y fue esta consulta la que lo detectó. La base no impone este límite (SUP-13): la consulta es un control de cumplimiento a posteriori sobre una única ventana, no una verificación de todas las ventanas móviles.

## Q19 · Controles de integridad y conciliación

- **Pregunta:** ¿Los datos son internamente coherentes?
- **Utilidad:** auditoría; cada fila debe devolver 0 diferencias.
- **Granularidad:** una fila por control.
- **Filtros:** ninguno; se revisa toda la base (todos los vuelos, tiquetes, pagos y reembolsos cargados).
- **Fórmulas:** identidad de conciliación (todo el período): cobros - reembolsos = precio final de tiquetes emitidos/usados/no presentados + abonos de reservas vigentes + penalidades retenidas.
- **Técnicas:** UNION ALL de subconsultas con ORDER BY final (orden determinista), agregaciones con pre-agregación (sin abanico de importes).
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q19_controles_conciliacion.sql` → `reports/resultados/Q19_controles_conciliacion.csv` (9 filas, 960 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q19 · Controles de integridad y conciliación
   Pregunta     : ¿Los datos son internamente coherentes?
   Utilidad     : auditoría; cada fila debe devolver 0 diferencias.
   Granularidad : una fila por control.
   Filtros      : ninguno; se revisa toda la base (todos los vuelos, tiquetes,
                  pagos y reembolsos cargados).
   Fórmulas     : identidad de conciliación (todo el período):
                  cobros - reembolsos = precio final de tiquetes emitidos/usados/no presentados
                                       + abonos de reservas vigentes + penalidades retenidas.
   Técnicas     : UNION ALL de subconsultas con ORDER BY final (orden determinista), agregaciones con pre-agregación (sin abanico de importes).
   ============================================================================= */
SELECT 'Inventario distinto de tiquetes que ocupan plaza' AS control,
       COUNT(*) AS filas_con_diferencia, CAST(NULL AS DECIMAL(14,2)) AS diferencia_usd
FROM rpt.v_conciliacion_inventario WHERE diferencia <> 0
UNION ALL
SELECT 'Plazas ocupadas por encima de la capacidad', COUNT(*), NULL
FROM ops.vuelo_cabina WHERE plazas_ocupadas > capacidad
UNION ALL
SELECT 'Asientos duplicados en tiquetes activos', COUNT(*), NULL
FROM (SELECT t.id_vuelo, t.codigo_asiento FROM ven.tiquete AS t
      JOIN ref.estado_tiquete AS e ON e.codigo_estado = t.codigo_estado AND e.ocupa_inventario = 1
      WHERE t.codigo_asiento IS NOT NULL
      GROUP BY t.id_vuelo, t.codigo_asiento HAVING COUNT(*) > 1) AS d
UNION ALL
SELECT 'Cobros confirmados mayores que el precio final', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE cobrado_usd > precio_final_usd
UNION ALL
SELECT 'Reembolsos mayores que lo cobrado', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE reembolsado_usd > cobrado_usd
UNION ALL
SELECT 'Tiquetes emitidos, usados o no presentados sin pago total', COUNT(*), NULL
FROM rpt.v_tiquete_financiero WHERE codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') AND cobrado_usd <> precio_final_usd
UNION ALL
SELECT 'Tiquetes con precio base distinto de su tarifa', COUNT(*), NULL
FROM ven.tiquete AS t JOIN ven.tarifa AS tf ON tf.id_tarifa = t.id_tarifa WHERE t.precio_base_usd <> tf.precio_base_usd
UNION ALL
SELECT 'Vuelos operados con reservas sin pagar', COUNT(DISTINCT t.id_vuelo), NULL
FROM ven.tiquete AS t JOIN ops.vuelo AS v ON v.id_vuelo = t.id_vuelo
WHERE v.codigo_estado IN ('EN_VUELO', 'ATERRIZADO') AND t.codigo_estado = 'RESERVADO'
UNION ALL
SELECT 'Identidad de conciliación de caja (USD)', CASE WHEN x.diferencia = 0 THEN 0 ELSE 1 END, x.diferencia
FROM (SELECT (SELECT SUM(monto_usd) FROM ven.pago WHERE codigo_estado = 'CONFIRMADO')
           - (SELECT ISNULL(SUM(monto_usd), 0) FROM ven.reembolso)
           - (SELECT SUM(CASE WHEN codigo_estado IN ('EMITIDO', 'USADO', 'NO_PRESENTADO') THEN precio_final_usd
                              WHEN codigo_estado = 'RESERVADO' THEN cobrado_usd
                              ELSE penalidad_retenida_usd END)
              FROM rpt.v_tiquete_financiero) AS diferencia) AS x
ORDER BY control;   -- sin ORDER BY, el orden de las filas de un UNION ALL no está garantizado
```

</details>

**Resultado ejecutado**

| control | filas_con_diferencia | diferencia_usd |
|---|---|---|
| Asientos duplicados en tiquetes activos | 0 |  |
| Cobros confirmados mayores que el precio final | 0 |  |
| Identidad de conciliación de caja (USD) | 0 | 0.00 |
| Inventario distinto de tiquetes que ocupan plaza | 0 |  |
| Plazas ocupadas por encima de la capacidad | 0 |  |
| Reembolsos mayores que lo cobrado | 0 |  |
| Tiquetes con precio base distinto de su tarifa | 0 |  |
| Tiquetes emitidos, usados o no presentados sin pago total | 0 |  |
| Vuelos operados con reservas sin pagar | 0 |  |

**Interpretación**

Los nueve controles devuelven cero diferencias: el inventario coincide con los tiquetes que ocupan plaza, no hay sobreventa ni asientos duplicados, ningún tiquete está sobrecobrado ni sobrerreembolsado, no hay tiquetes emitidos sin pago total ni precios distintos de su tarifa, ningún vuelo operó con reservas sin pagar y la identidad de caja (cobros − reembolsos = ventas emitidas + abonos de reservas vigentes + penalidades retenidas) cuadra al centavo. Son las propiedades que las restricciones y los triggers garantizan; la consulta lo comprueba sobre los datos cargados.

## Q20 · Uso y costo de los descuentos

- **Pregunta:** ¿Qué descuentos se usan, cuánto cuestan y a quién benefician?
- **Utilidad:** evaluar campañas y la política de un descuento por tiquete.
- **Granularidad:** una fila por código de descuento (incluye los no usados).
- **Filtros:** tiquetes no cancelados.
- **Fórmulas:** costo = SUM(monto descontado); costo relativo = costo / SUM(precio base de esos tiquetes); participación de registrados = tiquetes de compradores registrados / tiquetes con el código.
- **Técnicas:** LEFT JOIN desde el catálogo (muestra códigos sin uso con 0), agregaciones, ISNULL.
- **Parámetros usados:** ninguno
- **Archivos:** `sql/consultas/Q20_uso_descuentos.sql` → `reports/resultados/Q20_uso_descuentos.csv` (6 filas, 190 ms)

<details><summary>SQL</summary>

```sql
/* =============================================================================
   Q20 · Uso y costo de los descuentos
   Pregunta     : ¿Qué descuentos se usan, cuánto cuestan y a quién benefician?
   Utilidad     : evaluar campañas y la política de un descuento por tiquete.
   Granularidad : una fila por código de descuento (incluye los no usados).
   Filtros      : tiquetes no cancelados.
   Fórmulas     : costo = SUM(monto descontado); costo relativo = costo / SUM(precio base de esos tiquetes);
                  participación de registrados = tiquetes de compradores registrados / tiquetes con el código.
   Técnicas     : LEFT JOIN desde el catálogo (muestra códigos sin uso con 0), agregaciones, ISNULL.
   ============================================================================= */
SELECT d.codigo_descuento,
       d.porcentaje,
       d.codigo_cabina,
       d.solo_clientes_registrados,
       COUNT(v.id_tiquete)                                                             AS tiquetes,
       ISNULL(SUM(v.monto_descuento_usd), 0)                                           AS costo_descuento_usd,
       CAST(SUM(v.monto_descuento_usd) / NULLIF(SUM(v.precio_base_usd), 0) AS DECIMAL(7,4)) AS costo_relativo,
       CAST(SUM(v.comprador_registrado) * 1.0 / NULLIF(COUNT(v.id_tiquete), 0) AS DECIMAL(7,4)) AS participacion_registrados
FROM ven.descuento AS d
LEFT JOIN rpt.v_venta AS v ON v.codigo_descuento = d.codigo_descuento AND v.codigo_estado <> 'CANCELADO'
GROUP BY d.codigo_descuento, d.porcentaje, d.codigo_cabina, d.solo_clientes_registrados
ORDER BY tiquetes DESC, d.codigo_descuento;
```

</details>

**Resultado ejecutado**

| codigo_descuento | porcentaje | codigo_cabina | solo_clientes_registrados | tiquetes | costo_descuento_usd | costo_relativo | participacion_registrados |
|---|---|---|---|---|---|---|---|
| ANTICIPA15 | 15.00 | ECO | False | 25427 | 782256.45 | 0.1500 | 0.4230 |
| LANZAMIENTO20 | 20.00 | ECO | False | 22713 | 908578.40 | 0.2000 | 0.4095 |
| CLIENTE10 | 10.00 |  | True | 9296 | 246608.70 | 0.1000 | 1.0000 |
| OTONO12 | 12.00 |  | False | 8851 | 276077.40 | 0.1200 | 0.4271 |
| INVIERNO25 | 25.00 |  | False | 0 | 0.00 |  |  |
| VIPPLUS5 | 5.00 | VIP | True | 0 | 0.00 |  |  |

**Interpretación**

`ANTICIPA15` (25 427 tiquetes vigentes) y `LANZAMIENTO20` (22 713) son los descuentos más usados y también los de mayor costo (0,78 y 0,91 millones de USD). El costo relativo coincide con el porcentaje nominal porque cada tiquete admite un solo descuento. `VIPPLUS5` nunca se aplica: con la política «se aplica el mayor descuento disponible», todo comprador registrado en VIP también califica para `CLIENTE10`, que es mayor. Es una consecuencia de la regla de negocio, útil para discutir el diseño de promociones; `INVIERNO25` no se usa porque su vigencia empieza el 1 de diciembre de 2026, después de la fecha de corte.
