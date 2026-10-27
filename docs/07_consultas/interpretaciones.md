# Interpretación de los resultados de las consultas

Redactadas a partir de los CSV de `reports/resultados/` generados en la reproducción completa del contenedor (semilla 20261106, fecha de corte 2026-11-01 00:00 UTC). **Todos los datos son sintéticos**: las cifras sirven para comprobar que el modelo y las consultas funcionan y para practicar el análisis, no describen ninguna aerolínea real. Las relaciones son descriptivas; ninguna se interpreta como causal. Cuando un resultado reproduce un supuesto del generador se dice explícitamente, porque en ese caso valida la consulta, no revela nada del negocio.

`generador.py` reúne esos supuestos: probabilidad de comprador registrado 42 %, cancelación voluntaria 5 %, no presentados 4,5 %, factores por día de la semana y reglas de descuentos y tarifas.

## Q01

Se analizaron 1 767 vuelos aterrizados entre septiembre y octubre de 2026. La ocupación por vuelo tiene media de 66,9 % y mediana de 67,0 %, con un rango de 31,6 % a 92,6 %; 77 vuelos superaron el 85 % y 92 quedaron por debajo del 50 %. Los no presentados son el 4,55 % de las plazas vendidas en vuelos operados, cerca del 4,5 % que usa el generador, lo que confirma que la consulta separa bien plazas vendidas y pasajeros volados. La clasificación dentro de cada ruta (`RANK`) permite localizar los vuelos de menor ocupación de cada ruta en lugar de compararlos con rutas de distinta demanda.

## Q02

En la cabina económica el factor de ocupación ponderado del período es 68,9 % y el promedio simple de los factores por vuelo es 68,5 %; en VIP, 53,0 % y 53,1 %. La diferencia entre ambas medidas aparece porque los aviones tienen capacidades distintas: el factor ponderado responde a «qué parte de los asientos ofrecidos se usó» y es el que corresponde para la red. Por ruta, en económica va de 61,5 % (DEN-ATL) a 78,8 % (BOS-MCO); en VIP, de 49,1 % a 57,3 %. Hubo 4 cabinas VIP agotadas al cierre de la venta y ninguna económica. La menor ocupación VIP es un resultado de los parámetros del generador y no permite concluir nada sobre la demanda real de esa cabina.

## Q03

Entre julio y octubre de 2026 se vendieron 323 718 tiquetes por 73,52 millones de USD brutos (68,39 millones siguen vigentes tras cancelaciones). Los cobros confirmados suman 72,27 millones y los reembolsos 3,03 millones, con un cobro neto de 69,24 millones. Ventas, cobros y reembolsos se agregan cada uno por su propia fecha; por eso en un mes los cobros pueden diferir de las ventas: hay reservas pagadas en dos o tres partes, reservas que vencen sin pagar y reembolsos de ventas de meses anteriores. Que los cobros superen a las ventas vigentes no es un error: incluyen dinero que luego se devolvió o que se retuvo como penalidad (la identidad completa se verifica en Q19). No se calcula rentabilidad porque el modelo no registra costos.

## Q04

A la fecha de corte quedan 824 reservas pendientes de pago por 199 514,41 USD, de los que ya se abonaron 76 570,85 USD y faltan 122 943,56 USD. De ellas, 148 no tienen ningún pago, 11 tienen un pago en espera de confirmación y 665 tienen pagos parciales; 118 vencen en menos de 24 horas. Es el tipo de lista que un equipo de cobranzas usaría para priorizar recordatorios, porque una reserva que vence libera la plaza y obliga a devolver lo abonado (Q05).

## Q05

Se cancelaron 22 728 tiquetes. Sobre 4,00 millones de USD cobrados en ellos se reembolsaron 3,03 millones y se retuvieron 0,97 millones como penalidad. La regla de 24 horas y las cancelaciones de vuelo devuelven el 100 %; las cancelaciones voluntarias fuera de esa regla siguen la política por cabina, con un porcentaje medio aplicado de 56,8 % en económica y 79,9 % en VIP. En las reservas vencidas, 4 184 de 4 832 no tenían ningún cobro; la consulta las cuenta aparte (`sin_cobro`) y define la tasa de reembolso como NULL cuando no hubo cobro («no había nada que devolver»), que es distinto de un 0 % de reembolso. La regla y el porcentaje se recalculan con la misma función que usa el procedimiento de cancelación, y la prueba PR-22 confirma que los 22 728 reembolsos cargados coinciden con ella.

## Q06

El precio final medio en económica va de 104,07 USD (MIA-ATL) a 320,03 USD (HNL-LAX) y en VIP llega a 902,97 USD (LAX-HNL); el orden sigue la distancia porque así se construyeron las tarifas sintéticas. La tasa de descuento efectiva, ponderada por importe, se mantiene entre 3,4 % y 3,8 % en económica y entre 0,9 % y 1,5 % en VIP; la penetración de descuentos es de 22 % a 23 % en económica y de 9 % a 14 % en VIP. La tasa efectiva es mucho menor que los porcentajes nominales (10 % a 20 %) porque se reparte entre todos los tiquetes, con y sin descuento.

## Q07

El canal web concentra el 70,0 % de las ventas vigentes (46,0 % el sitio y 24,0 % la aplicación). En el canal físico destacan el mostrador de JFK (6,1 % del total y 20,3 % del canal físico) y la oficina de Nueva York (4,9 %). La participación en el canal y en el total se calcula con funciones de ventana sobre los agregados, de modo que los porcentajes suman 100 % sin consultas adicionales. La mezcla de canales es un supuesto del generador.

## Q08

El 41,9 % de las compras las hizo un comprador registrado (el generador usa 42 %), lo que valida la lógica de la vista: «registrado» significa que la cuenta existía en el momento de la compra. Los registrados son 22 701 compradores distintos con 70 828 compras; las compras sin registro (98 100) no se pueden atribuir a una misma persona de forma fiable, por lo que cada una cuenta como un comprador distinto. Esto es una limitación de la compra sin registro, no de la consulta. Precio medio, tiquetes por compra, tasa de cancelación y uso del canal web son casi iguales en ambos grupos porque el generador no los diferencia; con datos reales esta consulta sería el punto de partida para compararlos.

## Q09

En los vuelos de septiembre y octubre se vendieron 203 846 tiquetes: el 4,87 % se canceló de forma voluntaria (generador: 5 %), el 0,94 % por cancelación del vuelo y el 1,51 % por vencimiento de la reserva. La tasa voluntaria por ruta oscila entre 4,4 % y 5,5 %, dentro de lo esperable por azar con estos volúmenes. Las diferencias en la tasa total entre rutas se deben sobre todo a las cancelaciones de vuelos (por ejemplo, ORD-DFW 3,3 %), que son eventos poco frecuentes y concentrados.

## Q10

Los A321neo de las líneas transcontinentales y de Hawái promedian entre 10,0 y 11,2 horas de bloque programadas por día; los Embraer E175, entre 5,1 y 6,5 horas; los aviones de reserva (N325XA, N204XA, N804XA, N177XA) vuelan solo los días de mantenimiento programado del titular, de 0,6 a 2,1 horas por día del período; y N805XA no vuela porque está en mantenimiento. La utilización se divide entre todos los días del período, no solo entre los días con vuelo, para no sobrestimarla. Las horas reales son algo menores que las programadas por dos razones del generador: la duración real se genera entre el 93 % y el 105 % de la programada (media 99 %), y los vuelos del final del período que no habían aterrizado a la fecha de corte no suman horas reales.

## Q11

La ocupación más alta se da los viernes (72 % a 78 % según la franja) y los domingos; la más baja, martes y miércoles (59 % a 65 %). El patrón reproduce los factores por día de la semana del generador (viernes 1,08; miércoles 0,88), lo que valida el cálculo del día ISO, que no depende de `SET DATEFIRST`. Las franjas nocturnas ofrecen menos asientos porque hay menos salidas después de las 18 h; por eso se presenta el factor de ocupación y no solo el número de pasajeros.

## Q12

El 17,2 % de los tiquetes se compró con menos de 7 días de anticipación y el 19,5 % con 60 días o más. El precio medio en económica baja de 206,82 USD (0-6 días) a 179,94 USD (60 días o más) y la penetración de descuentos sube de 13,6 % a 47,1 %. Ambos hechos se explican por cómo están construidas las reglas sintéticas (el descuento `ANTICIPA15` exige anticipación y las tarifas cambian de versión con el tiempo); la consulta describe esa asociación, pero no demuestra que comprar antes «cause» un precio menor en un mercado real.

## Q13

Los diez clientes registrados de mayor cobro neto suman entre 14 340 y 79 822 USD cada uno. El primero (VF00000001) acumula 228 compras y 427 tiquetes en cuatro meses, consecuencia de la distribución de Pareto del generador. En datos reales, un valor así merecería revisión (podría tratarse de una cuenta corporativa o de una agencia) antes de tomar decisiones de fidelización. El cobro neto se toma de la vista financiera, que agrega pagos y reembolsos por tiquete antes de unir, para no duplicar importes.

## Q14

Hay 7 299 clientes registrados sin ninguna compra, 2 rutas sin programación (BOS-ORD y ORD-BOS, en evaluación), 1 avión sin vuelos (N805XA, en mantenimiento), 2 descuentos nunca aplicados (`INVIERNO25`, cuya vigencia empieza después del corte, y `VIPPLUS5`, ver Q20) y ningún tripulante sin asignaciones. Son consultas de calidad de datos: muestran registros que existen pero no participan en la operación y que conviene revisar.

## Q15

De 1 767 vuelos operados, el 78,4 % llegó con menos de 15 minutos de demora; por ruta, entre 70,0 % (HNL-LAX) y 85,2 % (ATL-DEN). Se cancelaron 20 vuelos (1,1 %). El percentil 90 de la demora de llegada distingue rutas con demoras ocasionales largas (HNL-LAX, 97 minutos) de rutas con demoras frecuentes pero cortas. Las demoras se generan al azar y se propagan por avión, por lo que las diferencias entre rutas no deben atribuirse a aeropuertos ni a horarios.

## Q16

Para los tres días posteriores al corte hay 85 vuelos programados (170 combinaciones de vuelo y cabina) con su disponibilidad y la tarifa vigente; una de esas cabinas ya está agotada. Es la consulta típica de un canal de venta y muestra el uso de `OUTER APPLY` con `TOP (1)` para tomar la tarifa vigente en una fecha.

## Q17

Las ventas vigentes crecieron de 9,20 millones de USD en julio a 22,65 millones en octubre. En económica, el crecimiento fue de 58,1 % en agosto, 54,0 % en septiembre y 3,3 % en octubre; en VIP, octubre cayó 1,2 %. El crecimiento inicial refleja el inicio de las ventas (1 de julio) y el de las operaciones (1 de septiembre). Octubre se acerca a un nivel estable, pero con cuatro meses no se puede hablar de tendencia ni de estacionalidad.

## Q18

En la ventana de 672 horas consecutivas (1 al 28 de octubre de 2026), cada capitán y primer oficial asignado voló entre 17,3 y 94,5 horas de bloque programadas (media 51,1 h); ningún piloto supera la referencia de 100 horas de 14 CFR 117.23(b)(1), y ningún vuelo operó sin sus dos pilotos. La versión anterior de los datos sintéticos sí la superaba (ver H-16), y fue esta consulta la que lo detectó. La base no impone este límite (SUP-13): la consulta es un control de cumplimiento a posteriori sobre una única ventana, no una verificación de todas las ventanas móviles.

## Q19

Los nueve controles devuelven cero diferencias: el inventario coincide con los tiquetes que ocupan plaza, no hay sobreventa ni asientos duplicados, ningún tiquete está sobrecobrado ni sobrerreembolsado, no hay tiquetes emitidos sin pago total ni precios distintos de su tarifa, ningún vuelo operó con reservas sin pagar y la identidad de caja (cobros − reembolsos = ventas emitidas + abonos de reservas vigentes + penalidades retenidas) cuadra al centavo. Son las propiedades que las restricciones y los triggers garantizan; la consulta lo comprueba sobre los datos cargados.

## Q20

`ANTICIPA15` (25 427 tiquetes vigentes) y `LANZAMIENTO20` (22 713) son los descuentos más usados y también los de mayor costo (0,78 y 0,91 millones de USD). El costo relativo coincide con el porcentaje nominal porque cada tiquete admite un solo descuento. `VIPPLUS5` nunca se aplica: con la política «se aplica el mayor descuento disponible», todo comprador registrado en VIP también califica para `CLIENTE10`, que es mayor. Es una consecuencia de la regla de negocio, útil para discutir el diseño de promociones; `INVIERNO25` no se usa porque su vigencia empieza el 1 de diciembre de 2026, después de la fecha de corte.
