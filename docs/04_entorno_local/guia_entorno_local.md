# Guía del entorno local (laptop Windows)

> **Estado:** pendiente de ejecutar en la laptop del equipo. El desarrollo y las pruebas registradas en `evidence/contenedor_linux/` se hicieron en un contenedor Linux con SQL Server 2022 Developer, que **no** es la laptop ni Azure. Esta guía indica exactamente qué ejecutar en la laptop para obtener la evidencia propia.

Datos confirmados por el equipo: Windows, SQL Server instalado, instancia predeterminada `MSSQLSERVER`, servicio en ejecución con inicio automático, servidor `localhost`, autenticación de Windows como primera opción.

Datos que **aún deben comprobarse** (no se suponen): versión y edición de SQL Server, SSMS, permisos del usuario, Python y controlador ODBC.

## Paso 1 · Verificación automática de solo lectura

En PowerShell, desde la carpeta del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\verificar_entorno.ps1
```

El script no modifica nada. Informa del sistema operativo, el estado de los servicios (`MSSQLSERVER`, `SQLSERVERAGENT`, `SQLBrowser`), los controladores ODBC, Python y sus paquetes, SSMS y `sqlcmd`, y guarda el informe en `evidence\laptop_windows\`.

`-ExecutionPolicy Bypass` afecta solo a esa ejecución; no cambia la política del equipo.

## Paso 2 · Conexión con SSMS

1. Abra SSMS → *Conectar* → *Motor de base de datos*.
2. Nombre del servidor: `localhost`. Autenticación: *Autenticación de Windows*.
3. Cifrado: las versiones recientes de SSMS proponen cifrado **obligatorio**. Mantenga el cifrado.
4. Si aparece el error «la cadena de certificados fue emitida por una entidad que no es de confianza», la instancia usa el **certificado autofirmado** que SQL Server genera al iniciar. Para esta conexión **local** marque *Confiar en el certificado del servidor*. Explicación:
   - El tráfico sigue cifrado; lo que se omite es la verificación de identidad del servidor.
   - Es aceptable para `localhost`, donde el cliente y el servidor son el mismo equipo.
   - La alternativa más estricta es instalar en la instancia un certificado emitido por una entidad de confianza (Administrador de configuración de SQL Server → Protocolos → Propiedades → Certificado) y reiniciar el servicio. No es necesario para el proyecto.
   - **En Azure nunca** se marca esta opción (ver `docs/05_azure`).
5. Abra `sql\00_verificacion_entorno.sql` y ejecútelo (F5). Guarde el resultado (*Resultados en texto*, Ctrl+T) en `evidence\laptop_windows\00_verificacion.txt`.

La primera consulta del script es la solicitada:

```sql
SELECT @@SERVERNAME, SERVERPROPERTY('Edition'), SERVERPROPERTY('ProductVersion'), SUSER_SNAME();
```

Interpretación rápida:

| Resultado | Qué significa | Qué hacer |
|---|---|---|
| `compatibilidad_proyecto` = *NO compatible* | SQL Server anterior a 2016 SP1 | Actualizar a una versión con soporte (por ejemplo, 2022 Developer o Express) |
| `puede_crear_bd` = 0 | El usuario de Windows no puede crear bases | Pedir a quien administra el equipo el rol `dbcreator`, o que cree `AerolineaDB` y otorgue `db_owner` |
| `edicion` = Express | Funciona; límite de 10 GB por base, suficiente para el proyecto (la base cargada ocupa del orden de cientos de MB) | Ninguna |
| `protocolo` = Shared memory | Conexión local por memoria compartida | Ninguna (ver Paso 6) |

## Paso 3 · Python y entorno virtual

```powershell
py --version                      # se recomienda Python 3.11 o superior
py -m venv .venv
.\.venv\Scripts\Activate.ps1      # si PowerShell lo bloquea: Set-ExecutionPolicy -Scope Process Bypass
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Si `py` no existe, instale Python desde python.org (marque *Add python.exe to PATH*) o desde Microsoft Store.

## Paso 4 · Controlador ODBC

```powershell
Get-OdbcDriver | Where-Object Name -like "*SQL Server*" | Select-Object Name, Platform
```

Debe aparecer **ODBC Driver 18 for SQL Server** (o 17) en plataforma de 64 bits. El controlador antiguo «SQL Server» que trae Windows no sirve. Si falta, descargue *Microsoft ODBC Driver 18 for SQL Server* desde la página oficial de Microsoft y vuelva a comprobar.

## Paso 5 · Configuración y primera conexión desde Python

```powershell
Copy-Item .env.example .env
notepad .env
```

Valores para la laptop:

```ini
DB_SERVER=localhost
DB_DATABASE=AerolineaDB
DB_AUTH=windows
DB_ENCRYPT=yes
DB_TRUST_SERVER_CERTIFICATE=yes   # solo local: certificado autofirmado (ver Paso 2)
```

`.env` no se sube al repositorio (`.gitignore`). Con autenticación de Windows no hay contraseña que guardar.

```powershell
python -m aerolinea --evidencia evidence\laptop_windows verificar-conexion
```

Si la base todavía no existe, la verificación falla al abrirla; cree la base primero (Paso 7) o ejecute temporalmente con `DB_DATABASE=master`.

## Paso 6 · Protocolos y servicios: qué NO hay que cambiar

- **Memoria compartida** (habilitada por defecto) basta para conectarse desde la misma máquina con `localhost`. No hace falta habilitar TCP/IP.
- Si una herramienta exigiera TCP/IP: se habilita en *Administrador de configuración de SQL Server → Configuración de red de SQL Server → Protocolos de MSSQLSERVER → TCP/IP*, y **requiere reiniciar el servicio**. Para uso local no hay que abrir el puerto 1433 en el firewall. Hágalo solo con una razón concreta y anótela.
- **SQL Server Browser** solo resuelve instancias con nombre sin puerto fijo; la instancia predeterminada usa el 1433. No se activa.
- **SQL Server Agent** ejecuta trabajos programados; el proyecto no tiene ninguno (el vencimiento de reservas se invoca a demanda con `ven.usp_vencer_reservas`). No se activa.
- **No** habilite acceso público ni remoto al servidor para resolver una conexión local.

## Paso 7 · Construcción completa y evidencias

```powershell
python -m aerolinea --evidencia evidence\laptop_windows reproducir --confirmar-destruccion
```

Ejecuta, en orden: verificación de la conexión → eliminación y creación de la base **local** → despliegue de scripts → generación y carga de datos sintéticos → pruebas T-SQL y de concurrencia → consultas Q01–Q20 (CSV) → gráficos → diccionario de datos. Tiempo de referencia en el contenedor: unos 6–8 minutos (depende del equipo).

`--confirmar-destruccion` es obligatorio porque elimina `AerolineaDB` local si existe. El script destructivo rechaza ejecutarse contra Azure.

Para hacerlo por partes:

```powershell
python -m aerolinea desplegar --crear-bd
python -m aerolinea cargar-datos
python -m aerolinea --evidencia evidence\laptop_windows pruebas
python -m aerolinea consultas
python -m aerolinea graficos
python -m aerolinea documentar
```

## Problemas frecuentes

| Mensaje | Causa probable | Solución |
|---|---|---|
| `Data source name not found and no default driver specified` | Falta el controlador ODBC 18/17 o se instaló el de 32 bits | Paso 4 |
| `SSL Provider: The certificate chain was issued by an authority that is not trusted` | Certificado autofirmado de la instancia local | `DB_TRUST_SERVER_CERTIFICATE=yes` solo en local (Paso 2) |
| `Login failed for user 'EQUIPO\usuario'` | El usuario de Windows no tiene inicio de sesión en la instancia | Que quien instaló SQL Server lo agregue (SSMS → Seguridad → Inicios de sesión) |
| `Named Pipes Provider: Could not open a connection` / error 26 o 40 | Servicio detenido o nombre de servidor incorrecto | Verificar el servicio (Paso 1) y usar `localhost` |
| `CREATE DATABASE permission denied` | Falta permiso | Ver Paso 2, fila `puede_crear_bd` |
| Error 1934 al crear índices o vistas | `QUOTED_IDENTIFIER` desactivado en `sqlcmd` | Usar `sqlcmd -I` o ejecutar desde SSMS/Python |
