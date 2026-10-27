<#
.SYNOPSIS
    Crea el servidor lógico y la base de Azure SQL Database del proyecto (oferta gratuita).

.DESCRIPTION
    ESTE SCRIPT CREA RECURSOS EN AZURE. Ejecútelo solo con autorización del equipo
    (y del docente si la suscripción es institucional).

    Sin -ConfirmarCreacion solo MUESTRA los comandos (simulación).

    Decisiones de seguridad:
      - Autenticación exclusiva de Microsoft Entra ID (--enable-ad-only-auth): no hay
        contraseña de administrador SQL que custodiar.
      - TLS mínimo 1.2.
      - Firewall: SOLO la IP pública del equipo que se conecta (-IpCliente). No se crea
        la regla 0.0.0.0 ("permitir servicios de Azure") ni rangos amplios.
      - Base General Purpose serverless con la oferta gratuita (--use-free-limit) y
        pausa automática al agotar el límite mensual (AutoPause): sin cargos por exceso.

    Requisitos: Azure CLI instalado y sesión iniciada (az login).
    Las opciones se verificaron contra el código fuente de Azure CLI
    (src/azure-cli/azure/cli/command_modules/sql/_params.py); confírmelas con
    «az sql db create --help» en su versión.

.PARAMETER IpCliente
    IP pública de su conexión a Internet. Puede verla en el portal (Servidor SQL >
    Redes > «Agregar la dirección IPv4 del cliente») o en el mensaje de error de SSMS
    al intentar conectarse sin regla.

.EXAMPLE
    .\crear_recursos_azure.ps1 -GrupoRecursos rg-aerolinea-pac -Servidor sql-aerolinea-pac-xyz -IpCliente 203.0.113.10
    .\crear_recursos_azure.ps1 -GrupoRecursos rg-aerolinea-pac -Servidor sql-aerolinea-pac-xyz -IpCliente 203.0.113.10 -ConfirmarCreacion
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$GrupoRecursos,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$')] [string]$Servidor,
    [Parameter(Mandatory = $true)] [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')] [string]$IpCliente,
    [string]$Base = "AerolineaDB",
    [string]$Region = "eastus2",
    [switch]$ConfirmarCreacion
)
$ErrorActionPreference = "Stop"

if ($IpCliente -eq "0.0.0.0") { throw "No se admite 0.0.0.0: indique la IP pública concreta del equipo." }

$cuenta = az account show --query "{suscripcion:name, id:id, usuario:user.name}" -o json | ConvertFrom-Json
$yo = az ad signed-in-user show --query "{id:id, upn:userPrincipalName}" -o json | ConvertFrom-Json
Write-Host "Suscripción: $($cuenta.suscripcion) ($($cuenta.id)) · usuario: $($cuenta.usuario)"
Write-Host "Administrador Entra del servidor: $($yo.upn)"

$comandos = @(
    @("group", "create", "--name", $GrupoRecursos, "--location", $Region),
    @("sql", "server", "create", "--name", $Servidor, "--resource-group", $GrupoRecursos, "--location", $Region,
      "--enable-ad-only-auth", "--external-admin-principal-type", "User",
      "--external-admin-name", $yo.upn, "--external-admin-sid", $yo.id,
      "--minimal-tls-version", "1.2"),
    @("sql", "db", "create", "--resource-group", $GrupoRecursos, "--server", $Servidor, "--name", $Base,
      "--edition", "GeneralPurpose", "--compute-model", "Serverless", "--family", "Gen5", "--capacity", "2",
      "--use-free-limit", "true", "--free-limit-exhaustion-behavior", "AutoPause",
      "--backup-storage-redundancy", "Local"),
    @("sql", "server", "firewall-rule", "create", "--resource-group", $GrupoRecursos, "--server", $Servidor,
      "--name", ("equipo-" + (Get-Date -Format "yyyyMMdd")), "--start-ip-address", $IpCliente, "--end-ip-address", $IpCliente)
)

foreach ($c in $comandos) {
    Write-Host ("az " + ($c -join " "))
    if ($ConfirmarCreacion) {
        & az @c -o table
        if ($LASTEXITCODE -ne 0) { throw "Falló: az $($c -join ' ')" }
    }
}

if (-not $ConfirmarCreacion) {
    Write-Host ""
    Write-Host "SIMULACIÓN: no se creó nada. Revise los comandos y repita con -ConfirmarCreacion cuando esté autorizado."
} else {
    Write-Host ""
    Write-Host "Servidor: $Servidor.database.windows.net  Base: $Base"
    Write-Host "Siguiente paso: docs\05_azure\guia_azure.md, sección 4 (despliegue del esquema)."
}
