# Preguntas de defensa con respuestas razonadas

Las respuestas citan el archivo o la prueba que las respalda. Los datos son sintéticos.

## Requisitos y modelo

**1. ¿Por qué separan persona y cliente en lugar de tener una sola tabla de clientes?**
Porque el enunciado exige que compren también los no registrados y porque comprador y pasajero no siempre coinciden. Toda persona puede comprar o viajar (`ven.persona`); «cliente» es la persona con cuenta (`ven.cliente`, subtipo 1:0..1 con la misma clave). Una sola tabla obligaría a columnas nulas para los no registrados o a duplicar personas. PR-03 prueba la compra sin registro.

**2. ¿Por qué distinguen ruta, programación y vuelo?**
Porque responden a hechos distintos: la ruta es el par origen-destino; la programación, el horario semanal con vigencia; el vuelo, una salida concreta con avión, tripulación, estado y horas reales. El enunciado dice que los vuelos «se generan a partir de una ruta programada»: lo hace `ops.usp_generar_vuelos`, que es idempotente (PR-18).

**3. ¿Copiar el precio en el tiquete no rompe la tercera forma normal?**
No genera anomalías porque el precio del tiquete es un hecho de la venta, no un atributo de la tarifa actual: la dependencia «tarifa → precio» solo vale en el momento de vender. Además se controla: el trigger verifica que la copia coincide con la tarifa vigente al vender, el precio del tiquete es inmutable y una tarifa usada no se edita (PR-05). Sin la copia, cambiar una tarifa alteraría ventas pasadas.

**4. ¿Por qué el asiento no tiene clave foránea hacia el mapa de asientos?**
Porque el mapa depende del avión asignado al vuelo. Para una FK habría que guardar la configuración en el tiquete, que depende transitivamente del vuelo (violaría 3FN) y quedaría desactualizada al cambiar de avión. Se valida con trigger (RN-13, PR-08).

**5. ¿Cómo garantizan que la cabina del tiquete exista en el vuelo y que la tarifa sea de esa cabina?**
Con dos claves foráneas compuestas: `(id_vuelo, codigo_cabina)` → `ops.vuelo_cabina` y `(id_tarifa, codigo_cabina)` → `ven.tarifa`. Es una garantía declarativa: no depende de código.

**6. ¿Por qué un solo descuento por tiquete?**
Es una decisión de negocio explícita para evitar que las promociones se acumulen sin control; se aplica el mayor disponible. Su consecuencia es visible en Q20: `VIPPLUS5` nunca se usa porque todo comprador que califica para él califica también para `CLIENTE10`. Es un hallazgo útil para rediseñar promociones, no un error.

## Implementación e integridad

**7. ¿Por qué usan triggers si muchos recomiendan evitarlos?**
Se usan solo donde una restricción declarativa no alcanza: reglas entre filas o tablas (transiciones de estado, solapes de avión y tripulación, tarifa vigente, inventario). Si esas reglas vivieran solo en procedimientos o en Python, un `INSERT` desde SSMS o una carga masiva las saltaría. Los triggers están escritos en conjunto, con recompilación, y la carga de 323 718 tiquetes con todos activos tarda unos 90 segundos.

**8. ¿Cómo evitan la sobreventa con ventas simultáneas?**
La fila `ops.vuelo_cabina` actúa como semáforo: el trigger la lee con `UPDLOCK`, de modo que la segunda venta del mismo vuelo y cabina espera a que termine la primera; si no hay plaza, error 50020. Un `CHECK (plazas_ocupadas <= capacidad)` es la última barrera. PC-01: 40 sesiones, 12 asientos, exactamente 12 éxitos.

**9. ¿Por qué no usar `SERIALIZABLE` y olvidarse?**
Porque bloquea rangos amplios y genera interbloqueos en toda la base para proteger unas pocas reglas. Bloquear solo la fila del recurso disputado (cupo, tiquete, avión, empleado) da la misma garantía con mucha menos contención. `SNAPSHOT` tampoco basta: no evita la escritura sesgada entre filas distintas.

**10. ¿Qué es la escritura sesgada y dónde podía ocurrir aquí?**
Dos transacciones leen el mismo estado, cada una valida una regla y ambas escriben, de modo que el resultado viola la regla. Ejemplo: dos asignaciones del mismo avión a vuelos solapados, cada una sin ver la otra. Se evita bloqueando primero la fila del avión antes de revisar su agenda (Berenson et al., 1995; Kleppmann, 2017).

**11. ¿Cómo evitan la inyección SQL desde Python?**
Nunca se concatena la entrada del usuario: las consultas declaran sus parámetros (`DECLARE @x … = valor; -- @param`), la aplicación reemplaza el valor por `?` y lo envía como parámetro enlazado de pyodbc. Una prueba de pytest verifica que ningún valor quede en el texto SQL.

**12. ¿Qué pasa si un procedimiento falla a la mitad?**
Todos usan `SET XACT_ABORT ON` y `TRY/CATCH`: la transacción se revierte completa. La demostración lo muestra: un sobrepago rechazado deshace también la persona, la reserva y el pago parcial creados antes en la misma transacción.

## Datos, consultas y resultados

**13. Si los datos son sintéticos, ¿qué valor tienen los resultados?**
Validan el modelo y las consultas, no el negocio. Como el generador fija probabilidades conocidas, una consulta correcta debe recuperarlas: Q08 recupera que el 41,9 % de las compras las hizo un comprador registrado (generador: 42 %) y Q09, un 4,87 % de cancelaciones voluntarias en los vuelos de septiembre y octubre (generador: 5 %). Además, la carga con todas las reglas activas prueba que los datos son coherentes. No se extraen conclusiones de mercado.

**14. ¿Por qué los cobros (72,27 M) superan a las ventas vigentes (68,39 M)?**
Porque miden cosas distintas: los cobros incluyen dinero que luego se reembolsó y penalidades retenidas de tiquetes cancelados, que ya no son ventas vigentes. La identidad completa (cobros − reembolsos = ventas emitidas + abonos de reservas vigentes + penalidades) cuadra con 0,00 USD de diferencia (Q19).

**15. ¿Cómo evitan multiplicar importes al combinar tiquetes, pagos y reembolsos?**
Agregando cada tabla por tiquete antes de unir (vista `rpt.v_tiquete_financiero`) y agregando ventas, cobros y reembolsos por su propia fecha en expresiones separadas. PR-20 muestra el error que se evita: una unión ingenua infla el cobro de 72,27 a 87,78 millones.

**16. ¿Por qué no calculan la rentabilidad por ruta?**
Porque el modelo no registra costos (combustible, tripulación, tasas). Calcular «rentabilidad» con ingresos solamente sería engañoso. Está listado como trabajo futuro.

**17. ¿El precio baja cuando se compra con anticipación?**
En estos datos el precio medio en económica baja de 206,82 a 179,94 USD entre los tramos extremos, pero es una asociación descriptiva producida por las reglas sintéticas (descuento por anticipación y versiones de tarifa). No demuestra causalidad ni describe un mercado real.

**18. ¿Por qué el factor de ocupación ponderado difiere del promedio de los factores por vuelo?**
Porque los aviones tienen capacidades distintas: el promedio simple da el mismo peso a un E175 de 76 asientos que a un A321neo de 188. El ponderado (asientos usados / asientos ofrecidos) responde a cuánto de la oferta se usó y es el que corresponde para la red (Q02).

## Pruebas, nube y proceso

**19. ¿Cómo saben que las pruebas de concurrencia son reales y no secuenciales?**
Cada sesión tiene su propia conexión y todas esperan en una barrera (`threading.Barrier`) para empezar a la vez. La prueba de asignación automática de asiento falló en su primera versión (6 de 30), lo que demuestra que sí había simultaneidad; se corrigió con el semáforo y ahora da 30 de 30.

**20. ¿Está cumplido el requisito de base de datos en la nube?**
No todavía. Está preparado (guía, script de creación en modo simulación, verificación de solo lectura, lista de evidencias y configuración segura), pero no se creó ningún recurso porque requiere una suscripción y la autorización del equipo. Las pruebas locales no lo sustituyen.

**21. ¿Qué cambia entre SQL Server local y Azure SQL Database?**
En Azure no se usa `USE`, la base se crea desde el portal o la CLI, no hay autenticación de Windows (se usa Microsoft Entra ID), el certificado se valida siempre y `READ_COMMITTED_SNAPSHOT` está activo por defecto. El código se escribió para funcionar igual en ambos: sin `USE`, con RCSI también en local y con la configuración de conexión validada por `config.py`.

**22. ¿Por qué aceptan `TrustServerCertificate=yes` en local si es inseguro?**
Solo en `localhost` y manteniendo el cifrado: la instancia local usa un certificado autofirmado que no puede validarse contra una autoridad. El tráfico sigue cifrado; lo que se omite es la verificación de identidad del servidor, irrelevante cuando cliente y servidor son la misma máquina. Para Azure la aplicación rechaza esa opción.

**23. ¿Qué hallazgo les enseñó más?**
Respuesta sugerida (cada integrante puede elegir otro): el de lógica de tres valores (H-04). `NOT (categoria = 'TECNICA')` es *desconocido* cuando la categoría es nula, y un `WHERE` descarta lo desconocido, así que un empleado sin categoría pasaba como capitán. Se corrigió con `ISNULL` y la prueba PR-15 verifica que el rol incompatible se rechace (error 50031).

**24. ¿Cómo se reparte el trabajo del equipo y cómo se evidencia?**
[POR COMPLETAR por el equipo con los aportes reales registrados en `docs/equipo/registro_aportes.md` y el historial de GitHub]. No se debe responder con aportes que no consten en ese registro.

## Referencias citadas en las respuestas

Berenson, H., Bernstein, P., Gray, J., Melton, J., O'Neil, E., & O'Neil, P. (1995). A critique of ANSI SQL isolation levels. En *Proceedings of the 1995 ACM SIGMOD International Conference on Management of Data* (pp. 1–10). https://doi.org/10.1145/223784.223785

Kleppmann, M. (2017). *Designing data-intensive applications*. O'Reilly Media.
