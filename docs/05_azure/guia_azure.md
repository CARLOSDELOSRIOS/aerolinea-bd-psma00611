# Despliegue en Azure SQL Database (requisito de nube)

> **Estado: PENDIENTE.** No se ha creado ningún recurso en Azure ni se ha ejecutado nada en la nube. Las pruebas locales y del contenedor **no** satisfacen el requisito de nube. Esta guía, los scripts y la lista de evidencias están listos para que el equipo los ejecute cuando tenga una suscripción y la autorización correspondiente.

## 1. Decisiones previas que debe tomar el equipo

| Decisión | Opciones | Recomendación |
|---|---|---|
| Suscripción | Personal, *Azure for Students* o institucional | La que indique el docente; si es institucional, pedir permiso para crear un grupo de recursos |
| Costo | Oferta gratuita de Azure SQL Database o nivel de pago | Oferta gratuita con pausa automática al agotar el límite (sin cargos por exceso) |
| Autenticación | Microsoft Entra ID o inicio de sesión SQL | Solo Entra ID (sin contraseñas que custodiar); SQL solo si el docente necesita acceso con usuario y contraseña |
| Acceso de red | Regla de firewall por IP o punto de conexión privado | Regla de firewall **solo** para la IP pública de quien se conecta; el punto privado exige red virtual y no aporta al objetivo del curso |
| Quién administra | Un integrante como administrador Entra | [POR COMPLETAR] |

Según la documentación de Microsoft consultada (oferta gratuita de Azure SQL Database, disponible de forma general desde 2025), cada suscripción puede tener hasta 10 bases gratuitas General Purpose serverless, cada una con 100 000 segundos de vCore, 32 GB de datos y 32 GB de copias de seguridad al mes; al agotar el límite se elige entre pausar la base hasta el mes siguiente o continuar pagando. **Verifique las condiciones vigentes en el portal antes de crear nada.**

## 2. Diferencias entre la instancia local y Azure SQL Database

| Aspecto | SQL Server local | Azure SQL Database | Impacto en el proyecto |
|---|---|---|---|
| Creación de la base | `CREATE DATABASE` (script 01) | Portal o CLI | No se ejecutan 01 ni 99 en Azure |
| `USE otra_base` | Permitido | No cambia de base | Los scripts 02+ no usan `USE` |
| Autenticación de Windows | Sí | No; Microsoft Entra ID o SQL | `DB_AUTH=entra_interactivo` o `entra_token` |
| Certificado TLS | Autofirmado (local) | Emitido por entidad de confianza | En Azure `TrustServerCertificate=no` (obligatorio en `config.py`) |
| `READ_COMMITTED_SNAPSHOT` | Se activa en 01 | Activo por defecto | Mismo comportamiento de concurrencia |
| Intercalación | La del script 01 | `SQL_Latin1_General_CP1_CI_AS` por defecto | Igual en ambos |
| SQL Server Agent | Disponible | No existe | El proyecto no lo usa |
| `AT TIME ZONE`, enmascaramiento, `CREATE OR ALTER`, `sp_set_session_context` | Sí (2016 SP1+) | Sí | Sin cambios |
| Recursos | Los de la laptop | Serverless con vCores limitados | La carga sintética tarda más; ver sección 5 |

## 3. Crear los recursos

**Opción A — Portal** (recomendada la primera vez): *Crear un recurso* → *SQL Database* → aplicar la oferta gratuita → servidor nuevo con *Usar solo autenticación de Microsoft Entra* → *Redes*: acceso público con **solo** la IP del cliente, sin «Permitir que los servicios de Azure accedan» → nombre de base `AerolineaDB`.

**Opción B — Azure CLI** (reproducible): `scripts/azure/crear_recursos_azure.ps1`. Sin `-ConfirmarCreacion` solo muestra los comandos:

```powershell
az login
.\scripts\azure\crear_recursos_azure.ps1 -GrupoRecursos rg-aerolinea-pac -Servidor <nombre-unico> -IpCliente <su-IP-publica>
# revisar la salida y, con autorización:
.\scripts\azure\crear_recursos_azure.ps1 -GrupoRecursos rg-aerolinea-pac -Servidor <nombre-unico> -IpCliente <su-IP-publica> -ConfirmarCreacion
```

## 4. Conectarse y desplegar el esquema

**SSMS:** servidor `<nombre-unico>.database.windows.net`, autenticación *Microsoft Entra MFA*, base `AerolineaDB`, cifrado **obligatorio** y *Confiar en el certificado del servidor* **desmarcado**.

**Python:** copie `.env.azure.example` a `.env.azure`, complete el servidor y el usuario, e instale la dependencia opcional si usará tokens:

```powershell
pip install -r requirements-azure.txt            # solo para DB_AUTH=entra_token
python -m aerolinea --env .env.azure verificar-conexion
python -m aerolinea --env .env.azure --evidencia evidence\azure desplegar     # scripts 02-13, sin --crear-bd
```

`config.py` rechaza una configuración de Azure sin cifrado, con `TrustServerCertificate=yes` o con autenticación de Windows.

## 5. Cargar los datos

```powershell
python -m aerolinea --env .env.azure --evidencia evidence\azure cargar-datos
```

Usa la misma semilla, por lo que genera exactamente los mismos datos que en local (el manifiesto `data/sintetico/manifiesto.json` incluye los SHA-256 de cada CSV). La inserción en `stg` viaja por Internet (casi 1,2 millones de filas en lotes) y la aplicación se ejecuta en el servidor. Con 2 vCores serverless se espera que tarde bastante más que en local; el consumo debería quedar muy por debajo del límite mensual gratuito, pero **compruebe en el portal la métrica «Free amount remaining»** después de la carga.

Si la conexión es lenta, la alternativa es cargar desde un archivo BACPAC exportado de la base local (SSMS → *Tareas* → *Exportar aplicación de capa de datos*) e importarlo en el servidor de Azure. Documente cuál de los dos métodos usó.

## 6. Verificar y obtener evidencias

```powershell
python -m aerolinea --env .env.azure --evidencia evidence\azure pruebas
python -m aerolinea --env .env.azure consultas --salida reports\resultados_azure
```

En SSMS, ejecute `sql/azure/verificacion_azure.sql` y guarde la salida.

## 7. Lista de evidencias para el informe

| # | Evidencia | Archivo sugerido | Estado |
|---|---|---|---|
| 1 | Captura del portal: servidor, base, nivel de servicio y oferta gratuita aplicada | `evidence/azure/01_portal.png` | Pendiente |
| 2 | Captura de *Redes*: una única regla con la IP del equipo (puede ocultar los dos últimos octetos) | `evidence/azure/02_firewall.png` | Pendiente |
| 3 | Captura de SSMS conectado (Explorador de objetos) con cifrado obligatorio | `evidence/azure/03_ssms.png` | Pendiente |
| 4 | Salida de `verificacion_azure.sql` con `edicion_motor = 5` y controles en 0 | `evidence/azure/04_verificacion.txt` | Pendiente |
| 5 | `verificacion_conexion.json` generado por Python | `evidence/azure/` | Pendiente |
| 6 | `resultados_pruebas.json/.md` en Azure | `evidence/azure/` | Pendiente |
| 7 | CSV de consultas y `manifiesto_consultas.json` desde Azure | `reports/resultados_azure/` | Pendiente |
| 8 | Comparación de conteos y sumas de control con el entorno local | tabla en el informe | Pendiente |

## 8. Al terminar

- Si no se seguirá usando: elimine el grupo de recursos (`az group delete --name rg-aerolinea-pac`) **después** de que el docente haya evaluado, o al menos pause la base.
- Elimine la regla de firewall si cambia de red.
- No suba `.env.azure` al repositorio.
