<#
.SYNOPSIS
    Stage 16 - Authenticate to Microsoft Graph as the Service Principal using the certificate (no client secret).

.DESCRIPTION
    Reads the thumbprint written by init.ps1, ensures the certificate is present in CurrentUser\My
    (re-imports cert.pfx if needed), then calls Connect-MgGraph with -CertificateThumbprint.
    Proves app-only auth by printing Get-MgContext and counting all users via the User.Read.All scope.

    Prerequisites:
      1. ./scripts/stage-16/init.ps1 has been run.
      2. terraform apply has uploaded the cert to the SP.
      3. Admin consent has been granted for the SP's Graph application permissions.

.PARAMETER ClientId
    Application (client) ID of the workload SP.  Output of:  terraform output cert_sp_client_id

.PARAMETER TenantId
    Entra tenant ID (GUID) or domain.

.PARAMETER PfxPassword
    Password used by init.ps1 when exporting cert.pfx. Defaults to 'Workshop123!'.

.EXAMPLE
    pwsh ./scripts/stage-16/auth.ps1 -ClientId 00000000-0000-0000-0000-000000000000 -TenantId contoso.onmicrosoft.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [string] $TenantId,
    [string] $PfxPassword = 'Workshop123!'
)

$ErrorActionPreference = 'Stop'

$repoRoot       = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$certDir        = Join-Path $repoRoot 'cert'
$pfxPath        = Join-Path $certDir  'cert.pfx'
$thumbprintPath = Join-Path $certDir  'cert.thumbprint.txt'

if (-not (Test-Path $thumbprintPath)) {
    throw "cert/cert.thumbprint.txt not found. Run scripts/stage-16/init.ps1 first."
}
$thumb = (Get-Content -Path $thumbprintPath -Raw).Trim()

$found = Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object { $_.Thumbprint -eq $thumb }
if (-not $found) {
    if (-not (Test-Path $pfxPath)) {
        throw "cert/cert.pfx not found and certificate $thumb is not in CurrentUser\My. Run init.ps1 first."
    }
    Write-Host "Certificate not in store, re-importing from cert/cert.pfx ..."
    $secure = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
    Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation 'Cert:\CurrentUser\My' -Password $secure | Out-Null
}

Write-Host "Connecting to Microsoft Graph as ClientId=$ClientId via certificate $thumb ..."
Connect-MgGraph `
    -ClientId              $ClientId `
    -CertificateThumbprint $thumb `
    -TenantId              $TenantId `
    -NoWelcome

$ctx = Get-MgContext
Write-Host ''
Write-Host 'Connected.'
Write-Host "  AuthType : $($ctx.AuthType)"
Write-Host "  AppName  : $($ctx.AppName)"
Write-Host "  TenantId : $($ctx.TenantId)"
Write-Host "  Scopes   : $($ctx.Scopes -join ', ')"

Write-Host ''
Write-Host 'Counting users via Microsoft Graph (User.Read.All) ...'
$users = Get-MgUser -All -Property 'id'
Write-Host "  Total users in tenant: $($users.Count)"

Disconnect-MgGraph | Out-Null
