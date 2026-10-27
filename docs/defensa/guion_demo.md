# Guion de la demostración en vivo (2:30)

## Preparación (el día anterior y 15 minutos antes)

- [ ] Base `AerolineaDB` reconstruida con `python -m aerolinea reproducir --confirmar-destruccion` en la laptop que se usará (no en otra).
- [ ] `.env` con `DB_AUTH=windows` y la verificación de conexión funcionando.
- [ ] Entorno virtual activado (`.\.venv\Scripts\Activate.ps1`) en una terminal ya abierta en la carpeta del proyecto.
- [ ] Fuente de la terminal en 18-20 pt y fondo oscuro; ventanas innecesarias cerradas; notificaciones silenciadas.
- [ ] Plan B abierto en otra pestaña: `evidence/contenedor_linux/demo_procedimientos.txt` (o la evidencia equivalente de la laptop).
- [ ] Ensayo cronometrado: la demostración completa debe durar menos de 2:30.

La demostración **no modifica los datos del informe**: la parte A termina con el error que revierte todo y la parte B se revierte con `ROLLBACK` al final.

## Paso 1 · Conexión (20 s)

```powershell
python -m aerolinea verificar-conexion
```

Qué señalar: servidor, edición y versión reales de la laptop; `cifrado = TRUE`; `autenticacion = NTLM/KERBEROS` (Windows). Frase: «la conexión está cifrada y sin contraseñas guardadas».

## Paso 2 · Procedimientos y atomicidad (80 s)

```powershell
python -m aerolinea demo
```

Salida esperada (ejemplo real del contenedor; números de tiquete y vuelo varían):

```
A. Atomicidad: un error de negocio revierte toda la transacción
A1. Persona … sin cuenta; tiquete … RESERVADO por 354.99 USD
A2. Pago parcial 142.00 USD -> saldo 212.99 USD
A3. Sobrepago rechazado por la base: [50135] RN-37: el monto (9999.00 USD) supera el saldo disponible …
A4. Después del error, filas del tiquete …: 0 (se revirtieron la persona, la reserva y el pago parcial …)
B. Flujo completo: compra sin registro, pago en dos partes, emisión y cancelación
B1. Tiquete … (reserva …) RESERVADO; precio final 354.99 USD
B2. Pago parcial con tarjeta 142.00 USD -> estado RESERVADO, saldo 212.99 USD
B3. Pago del saldo con billetera -> estado EMITIDO, saldo 0.00 USD
B4. Cancelación voluntaria: regla REGLA_24H (100.00 %), reembolso 354.99 USD, retenido 0.00 USD
B5. Situación financiera: codigo_estado=CANCELADO, … cobrado_usd=354.99, reembolsado_usd=354.99 …
Demostración revertida (ROLLBACK): los datos del informe no cambian.
```

Qué señalar:

- A3-A4: el error lo lanza la base (regla RN-37) y, como los procedimientos usan `SET XACT_ABORT ON`, **se deshace toda la transacción**: también la persona y el pago parcial creados antes.
- B2-B3: el tiquete solo pasa a `EMITIDO` cuando lo cobrado iguala el precio.
- B4: como la compra se hizo hoy y el vuelo sale en más de siete días, aplica la regla de 24 horas (reembolso total). Si el vuelo saliera antes, aplicaría la política por cabina.

## Paso 3 · Consulta parametrizada (40 s)

```powershell
python -m aerolinea consultas --id Q16 --param dias=7 origen=JFK --salida reports\demo
```

Qué señalar: los valores `7` y `JFK` viajan como parámetros enlazados (`?`), no se concatenan en el SQL; el resultado queda en `reports\demo\Q16_disponibilidad_proximos_vuelos.csv` (abrirlo si sobra tiempo). Usar una carpeta de salida distinta de `reports\resultados` para no reemplazar los CSV del informe.

## Plan B (si algo falla)

1. No depurar en vivo.
2. Decir: «Mostramos la ejecución registrada» y abrir `evidence/…/demo_procedimientos.txt`.
3. Continuar con la diapositiva 11 dentro del tiempo.

## Errores frecuentes y respuesta rápida

| Síntoma | Causa | Qué hacer en la sesión |
|---|---|---|
| `Login failed` o error 4060 | Base no creada en esa laptop | Plan B |
| `SSL Provider … certificate chain` | Falta `DB_TRUST_SERVER_CERTIFICATE=yes` en el `.env` local | Plan B; corregir después |
| La demo crea el vuelo 9950 | No hay vuelos futuros en los datos (la fecha real superó el horizonte de datos) | Es el comportamiento previsto; continuar |
