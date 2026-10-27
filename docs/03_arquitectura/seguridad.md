# Seguridad y privacidad

## 1. Principios

1. **Privilegio mínimo**: cada perfil recibe solo los permisos que necesita, sobre esquemas o procedimientos, nunca sobre tablas sueltas sin motivo.
2. **La aplicación no escribe tablas directamente**: opera mediante procedimientos que aplican las reglas (`DENY INSERT, UPDATE, DELETE` sobre `ven` y `ops` para `rol_aplicacion`).
3. **Datos personales protegidos por defecto** en las consultas de usuarios sin privilegio (enmascaramiento dinámico).
4. **Sin secretos en el repositorio**: la configuración se lee de `.env` (excluido por `.gitignore`) o de variables de entorno; `.env.example` solo contiene marcadores.
5. **Conexiones cifradas siempre**; en Azure, además, con validación del certificado del servidor.

## 2. Roles de base de datos (`sql/08_seguridad.sql`)

| Rol | Permisos | Uso previsto |
|---|---|---|
| `rol_analista` | `SELECT` y `EXECUTE` sobre el esquema `rpt` | Analistas y docentes que consultan resultados; no ven tablas base, salarios ni datos de pago |
| `rol_ventas` | `EXECUTE` sobre los procedimientos de venta, pago y cancelación; `SELECT` sobre tres vistas | Agentes de venta |
| `rol_operaciones` | `EXECUTE` y `SELECT` sobre `ops`, `SELECT` sobre `rpt`, abordaje y vencimiento de reservas | Planificación y control de operaciones |
| `rol_aplicacion` | `EXECUTE` sobre `ven`, `ops`, `rpt`; `SELECT` sobre `rpt` y `ref`; `DENY` de escritura directa en `ven` y `ops` | Cuenta técnica de una aplicación en producción |

**Cadena de propiedad.** Todos los esquemas pertenecen a `dbo`. Cuando un usuario con `EXECUTE` sobre `ven.usp_emitir_tiquete` lo ejecuta, el motor no vuelve a comprobar permisos sobre las tablas que el procedimiento modifica porque tienen el mismo propietario. Así el usuario puede vender, pero no puede insertar un tiquete a mano. Una consecuencia comprobada en las pruebas: el SQL dinámico rompe la cadena (por eso la prueba PR-19 usa `sp_executesql` para verificar el permiso real del usuario).

**Usuarios de demostración.** `usr_demo_analista` y `usr_demo_aplicacion` se crean `WITHOUT LOGIN`: no pueden conectarse; solo sirven para que las pruebas suplanten su identidad con `EXECUTE AS USER` y comprueben los permisos.

## 3. Enmascaramiento dinámico de datos

| Columna | Función | Ejemplo mostrado a un usuario sin `UNMASK` |
|---|---|---|
| `ven.persona.email_contacto` | `email()` | `aXXX@XXXX.com` |
| `ven.persona.telefono` | `partial(0,"XXX-XXX-",4)` | `XXX-XXX-4821` |
| `ven.persona.numero_documento` | `partial(0,"XXXXXX",3)` | `XXXXXX123` |
| `ven.persona.fecha_nacimiento` | `default()` | `1900-01-01` |
| `ven.cliente.email_acceso` | `email()` | `jXXX@XXXX.com` |
| `rh.empleado.salario_anual_usd` | `default()` | `0.00` |

Limitaciones que deben declararse en la defensa:

- El enmascaramiento **no es cifrado**: los datos se guardan en claro y un usuario con consultas ad hoc puede inferir valores (por ejemplo, filtrando `WHERE salario_anual_usd > 100000`). Es una capa de presentación para reducir la exposición accidental.
- Para proteger realmente datos sensibles se usaría *Always Encrypted* (cifrado en el cliente) o se evitaría almacenarlos. Queda como trabajo futuro.
- Los datos de tarjeta se limitan a los **últimos 4 dígitos** y la marca (`ck_pago_tarjeta`); el número completo nunca se guarda, en línea con el principio de minimización de PCI DSS (sin pretender cumplimiento formal).

## 4. Conexión y credenciales

| Entorno | Autenticación | Cifrado | Certificado |
|---|---|---|---|
| Laptop (SQL Server local) | Windows integrada (primera opción) | `Encrypt=yes` (predeterminado en ODBC Driver 18) | La instancia local suele usar un certificado autofirmado. En desarrollo se acepta con `TrustServerCertificate=yes` **solo** para `localhost`; la alternativa más estricta es instalar un certificado de confianza en la instancia |
| Azure SQL Database | Microsoft Entra ID (interactiva o token) o, si el docente lo exige, SQL con usuario contenido | `Encrypt=yes` obligatorio | **Validado**: `TrustServerCertificate=no`; `config.py` rechaza la configuración contraria |

Reglas operativas:

- No habilitar acceso público amplio ni reglas de firewall `0.0.0.0–255.255.255.255`; en Azure se autoriza solo la IP del equipo que se conecta (ver `docs/05_azure`).
- No activar SQL Server Browser ni SQL Server Agent: la instancia predeterminada escucha en el puerto 1433 y el proyecto no tiene tareas programadas.
- Las contraseñas no se escriben en scripts ni en la línea de comandos; se leen de `.env` o de variables de entorno.

## 5. Auditoría

- `aud.cambio_estado` registra cada cambio de estado de vuelos, tiquetes y pagos (entidad, identificador, estado anterior y nuevo, usuario, aplicación y momento UTC). Lo escriben los triggers, de modo que no depende de que la aplicación lo recuerde.
- Pagos, reembolsos y tiquetes no se eliminan (`INSTEAD OF DELETE`); los errores se corrigen con nuevas filas (anulación, reembolso), manteniendo el histórico.
- `adm.registro_despliegue` deja constancia de qué script se ejecutó, cuándo, con qué usuario y versión del motor.
