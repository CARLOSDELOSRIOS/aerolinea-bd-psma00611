<#
.SYNOPSIS
    Verificación de SOLO LECTURA del entorno local del proyecto (laptop Windows).

.DESCRIPTION
    Comprueba, sin modificar nada:
      1. Sistema operativo.
      2. Servicios de SQL Server (motor, Agent, Browser): estado y tipo de inicio.
      3. Controladores ODBC de SQL Server instalados.
      4. Python, pip y paquetes pyodbc / pandas.
      5. SSMS y sqlcmd.
      6. Si hay sqlcmd: la consulta de identificación del servidor con autenticación de Windows.
    Guarda un informe de texto en evidence\laptop_windows\entorno_windows_<fecha>.txt

    No inicia ni detiene servicios, no cambia protocolos y no instala nada.

.EXAMPLE
    PS> cd C:\ruta\aerolinea-bd-psma00611
    PS> powershell -ExecutionPolicy Bypass -File .\scripts\windows\verificar_entorno.ps1
#>
[CmdletBinding()]
param(
    [string]$Servidor = "localhost",
    [string]$Instancia = "MSSQLSERVER"
)

$ErrorActionPreference = "Continue"
$raiz = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$carpeta = Join-Path $raiz "evidence\laptop_windows"
New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
$informe = Join-Path $carpeta ("entorno_windows_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$lineas = New-Object System.Collections.Generic.List[string]

function Escribir([string]$texto) {
    Write-Host $texto
    $lineas.Add($texto) | Out-Null
}

Escribir "=== Verificación del entorno local · $(Get-Date -Format s) ==="

# 1. Sistema operativo
$so = Get-CimInstance Win32_OperatingSystem
Escribir ("[SO] {0} · versión {1} · compilación {2} · {3}" -f $so.Caption, $so.Version, $so.BuildNumber, $so.OSArchitecture)

# 2. Servicios de SQL Server (solo lectura)
$nombreMotor = if ($Instancia -eq "MSSQLSERVER") { "MSSQLSERVER" } else { "MSSQL`$$Instancia" }
$nombreAgent = if ($Instancia -eq "MSSQLSERVER") { "SQLSERVERAGENT" } else { "SQLAgent`$$Instancia" }
foreach ($nombre in @($nombreMotor, $nombreAgent, "SQLBrowser")) {
    $servicio = Get-CimInstance Win32_Service -Filter "Name='$nombre'" -ErrorAction SilentlyContinue
    if ($servicio) {
        Escribir ("[Servicio] {0}: estado={1}; inicio={2}; cuenta={3}" -f $servicio.Name, $servicio.State, $servicio.StartMode, $servicio.StartName)
    } else {
        Escribir "[Servicio] ${nombre}: no instalado"
    }
}
Escribir "  Nota: el proyecto NO necesita SQL Server Agent ni SQL Server Browser; no los inicie."

# 3. Controladores ODBC
$controladores = Get-OdbcDriver -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*SQL Server*" }
if ($controladores) {
    foreach ($c in $controladores) { Escribir ("[ODBC] {0} ({1})" -f $c.Name, $c.Platform) }
} else {
    Escribir "[ODBC] No se encontró ningún controlador de SQL Server. Instale 'ODBC Driver 18 for SQL Server' (Microsoft)."
}
if (-not ($controladores | Where-Object { $_.Name -like "ODBC Driver 1[78] for SQL Server" })) {
    Escribir "  Aviso: el proyecto requiere 'ODBC Driver 18 for SQL Server' (o 17)."
}

# 4. Python y paquetes
$python = Get-Command py -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
if ($python) {
    $versionPy = & $python.Source --version 2>&1
    Escribir "[Python] $versionPy ($($python.Source))"
    $paquetes = & $python.Source -m pip list --format=freeze 2>$null | Select-String -Pattern "^(pyodbc|pandas|matplotlib|python-dotenv)=="
    if ($paquetes) { $paquetes | ForEach-Object { Escribir "  $_" } } else { Escribir "  pyodbc/pandas no instalados en este intérprete (use el entorno virtual .venv)." }
    $venv = Join-Path $raiz ".venv\Scripts\python.exe"
    if (Test-Path $venv) {
        Escribir "[Python .venv] $(& $venv --version 2>&1)"
        & $venv -m pip list --format=freeze 2>$null | Select-String -Pattern "^(pyodbc|pandas|matplotlib|python-dotenv)==" | ForEach-Object { Escribir "  $_" }
    }
} else {
    Escribir "[Python] No encontrado en el PATH."
}

# 5. SSMS y sqlcmd
$carpetasSsms = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Directory -Filter "Microsoft SQL Server Management Studio*" -ErrorAction SilentlyContinue
$ssms = $carpetasSsms | ForEach-Object { Get-ChildItem -Path $_.FullName -Recurse -Filter "ssms.exe" -ErrorAction SilentlyContinue } | Select-Object -First 1
if ($ssms) {
    Escribir ("[SSMS] {0} · versión de archivo {1}" -f $ssms.FullName, $ssms.VersionInfo.FileVersion)
} else {
    Escribir "[SSMS] No encontrado en la ruta estándar (compruebe Ayuda > Acerca de en SSMS)."
}
$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
if ($sqlcmd) {
    Escribir "[sqlcmd] $($sqlcmd.Source)"
    # -E autenticación de Windows; -C confía en el certificado autofirmado de la instancia LOCAL (no usar con Azure).
    $consulta = "SET NOCOUNT ON; SELECT @@SERVERNAME AS servidor, SERVERPROPERTY('Edition') AS edicion, SERVERPROPERTY('ProductVersion') AS version, SUSER_SNAME() AS usuario, (SELECT net_transport FROM sys.dm_exec_connections WHERE session_id=@@SPID) AS protocolo, (SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id=@@SPID) AS cifrado, IS_SRVROLEMEMBER('sysadmin') AS es_sysadmin, HAS_PERMS_BY_NAME(NULL,NULL,'CREATE ANY DATABASE') AS puede_crear_bd;"
    $salida = & $sqlcmd.Source -S $Servidor -E -C -W -s "|" -Q $consulta 2>&1
    Escribir "[Consulta de identificación]"
    $salida | ForEach-Object { Escribir "  $_" }
} else {
    Escribir "[sqlcmd] No encontrado: ejecute sql\00_verificacion_entorno.sql desde SSMS y guarde la salida."
}

$lineas | Set-Content -Path $informe -Encoding UTF8
Write-Host ""
Write-Host "Informe guardado en $informe"
