<#
.SYNOPSIS
    Stage 101 (Verified ID) - Acquire a Verified ID Admin API access token via certificate auth
    and print full authority + contract details for the tenant.

.DESCRIPTION
    Reads the thumbprint written by init.ps1, ensures the certificate is present in CurrentUser\My
    (re-imports cert.pfx if needed), then uses MSAL.PS (Get-MsalToken) to acquire an app-only
    access token for scope '6a8b4b39-c021-437c-b060-5a14a3fd65f3/.default' (the Verified ID
    Admin API resource). Calls the Verified ID Admin API to list authorities, fetch each
    authority's full detail, and list each authority's contracts.

    Prerequisites:
      1. ./scripts/stage-101-vc/init.ps1 has been run.
      2. terraform apply has uploaded the cert to the Verified ID SP (module.Workload_CertSpVc).
      3. Admin consent has been granted for the SP's Verified ID application roles.
      4. The tenant has been onboarded to Verified ID at least once (otherwise the
         /authorities response is empty - the script handles this gracefully).

.PARAMETER ClientId
    Application (client) ID of the Verified ID workload SP. Output of:
        terraform output -raw cert_sp_vc_client_id

.PARAMETER TenantId
    Entra tenant ID (GUID) or domain.

.PARAMETER PfxPassword
    Password used by init.ps1 when exporting cert.pfx. Defaults to 'Workshop123!'.

.EXAMPLE
    pwsh ./scripts/stage-101-vc/auth.ps1 -ClientId 00000000-0000-0000-0000-000000000000 -TenantId 12345678-0000-0000-0000-000000000000
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
    throw "cert/cert.thumbprint.txt not found. Run scripts/stage-101-vc/init.ps1 first."
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

if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
    Write-Host "MSAL.PS module not found - installing for CurrentUser ..."
    Install-Module -Name MSAL.PS -Scope CurrentUser -Force -AcceptLicense
}
Import-Module MSAL.PS

$cert = Get-Item "Cert:\CurrentUser\My\$thumb"

$VcResourceAppId = '6a8b4b39-c021-437c-b060-5a14a3fd65f3'
$VcScope         = "$VcResourceAppId/.default"

Write-Host "Acquiring access token for Verified ID Admin API (scope $VcScope) ..."
$tokenResult = Get-MsalToken `
    -ClientId          $ClientId `
    -TenantId          $TenantId `
    -ClientCertificate $cert `
    -Scopes            @($VcScope)

$accessToken = $tokenResult.AccessToken
Write-Host "Acquired access token for Verified ID Admin API."

$VcApiBase = 'https://verifiedid.did.msidentity.com/v1.0'
$headers   = @{
    Authorization  = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

function Invoke-VcAdminApi {
    param([Parameter(Mandatory)] [string] $Path)
    Invoke-RestMethod -Method Get -Uri "$VcApiBase/$Path" -Headers $headers
}

Write-Host ''
Write-Host "Listing Verified ID authorities for tenant $TenantId ..."
$authorities = Invoke-VcAdminApi -Path 'verifiableCredentials/authorities'

if (-not $authorities.value -or $authorities.value.Count -eq 0) {
    Write-Host "No Verified ID authorities configured in tenant $TenantId."
    return
}

Write-Host "Found $($authorities.value.Count) authority/authorities."

foreach ($a in $authorities.value) {
    Write-Host ''
    Write-Host '--------------------------------------------------------------------------------'
    Write-Host "Authority: $($a.name)  ($($a.id))"
    Write-Host '--------------------------------------------------------------------------------'

    $detail = Invoke-VcAdminApi -Path "verifiableCredentials/authorities/$($a.id)"

    Write-Host "  Id                : $($detail.id)"
    Write-Host "  Name              : $($detail.name)"
    Write-Host "  Status            : $($detail.status)"
    Write-Host "  DID               : $($detail.did)"
    Write-Host "  DidDocumentStatus : $($detail.didDocumentStatus)"
    if ($detail.linkedDomainUrls) {
        Write-Host "  LinkedDomains     : $($detail.linkedDomainUrls -join ', ')"
    }

    Write-Host ''
    Write-Host '  didModel:'
    ($detail.didModel | ConvertTo-Json -Depth 10) -split "`n" | ForEach-Object { Write-Host "    $_" }

    if ($detail.keyVaultMetadata) {
        Write-Host ''
        Write-Host '  keyVaultMetadata:'
        ($detail.keyVaultMetadata | ConvertTo-Json -Depth 10) -split "`n" | ForEach-Object { Write-Host "    $_" }
    }

    Write-Host ''
    Write-Host '  Contracts:'
    $contracts = Invoke-VcAdminApi -Path "verifiableCredentials/authorities/$($a.id)/contracts"
    if (-not $contracts.value -or $contracts.value.Count -eq 0) {
        Write-Host '    (none)'
    } else {
        Write-Host "    $($contracts.value.Count) contract(s):"
        $contracts.value |
            Select-Object `
                @{ Name = 'Name';   Expression = { $_.name } }, `
                @{ Name = 'Status'; Expression = { $_.status } }, `
                @{ Name = 'Type';   Expression = { ($_.rules.vc.type) -join ',' } }, `
                @{ Name = 'Id';     Expression = { $_.id } } |
            Format-Table -AutoSize |
            Out-String -Stream |
            Where-Object { $_.Trim().Length -gt 0 } |
            ForEach-Object { Write-Host "    $_" }
    }
}
