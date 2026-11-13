<#
.SYNOPSIS
    Builds the SPA configuration JSON from Terraform outputs, encodes it as Base64 and
    prints the OIDC debugger link https://tenant.factorlabs.pl/oidcdebugger?data=<base64>
    (-Raw prints the Base64 only).

.DESCRIPTION
    Reads `terraform output -json` from external_tenant/ and builds:

      {
        "name": "Workshop SPA",
        "authorizationEndpoint": "https://<sub>.ciamlogin.com/<sub>.onmicrosoft.com/oauth2/v2.0/authorize",
        "clientId": "<SPA client id>",
        "scope": "openid profile offline_access api://<api client id>/access_as_user"
      }

    Terraform outputs used (<prefix> = -Prefix):
      <prefix>_authority      -> authorizationEndpoint
      <prefix>_spa_client_id  -> clientId (the SPA signs the user in, not the API)
      <prefix>_api_scope      -> appended to the OIDC scopes

.PARAMETER Prefix
    Terraform output prefix: external_sync (External-05, default) or external_signup (External-04).

.PARAMETER Name
    Value of the "name" field.

.PARAMETER TerraformDir
    Folder with the Terraform state. Defaults to <repo>/external_tenant.

.EXAMPLE
    ./New-SpaConfigBase64.ps1
.EXAMPLE
    ./New-SpaConfigBase64.ps1 -Prefix external_signup -Name "Extensions SPA" -ShowJson
#>
[CmdletBinding()]
param(
    [ValidateSet('external_sync', 'external_signup')]
    [string] $Prefix = 'external_sync',

    [string] $Name = 'Workshop SPA',

    [string] $TerraformDir = (Join-Path $PSScriptRoot '..\..\external_tenant'),

    # Debugger page; the Base64 is appended as ?data=<base64>.
    [string] $DebuggerUrl = 'https://tenant.factorlabs.pl/oidcdebugger',

    # Return only the Base64, not the full link.
    [switch] $Raw,

    # Also print the JSON before it is encoded.
    [switch] $ShowJson
)

$ErrorActionPreference = 'Stop'

Push-Location $TerraformDir
try {
    $tfJson = terraform output -json
    if ($LASTEXITCODE -ne 0) { throw "terraform output failed in $TerraformDir" }
}
finally {
    Pop-Location
}
$outputs = ($tfJson -join "`n") | ConvertFrom-Json

function Get-TfOutput([string] $key) {
    $o = $outputs.PSObject.Properties[$key]
    if (-not $o) { throw "Terraform output '$key' not found - run terraform apply first." }
    return [string] $o.Value.value
}

$authority = (Get-TfOutput "${Prefix}_authority").TrimEnd('/')   # https://<sub>.ciamlogin.com
$clientId  = Get-TfOutput "${Prefix}_spa_client_id"
$apiScope  = Get-TfOutput "${Prefix}_api_scope"

# https://mailfactorlabs.ciamlogin.com -> mailfactorlabs.onmicrosoft.com
$subdomain = ([Uri] $authority).Host.Split('.')[0]
$tenant    = "$subdomain.onmicrosoft.com"

# [ordered] keeps the property order of the template JSON.
$config = [ordered] @{
    name                  = $Name
    authorizationEndpoint = "$authority/$tenant/oauth2/v2.0/authorize"
    clientId              = $clientId
    scope                 = "openid profile offline_access $apiScope"
}

$json   = $config | ConvertTo-Json -Compress
$base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))

if ($ShowJson) { Write-Host $json -ForegroundColor DarkGray }

if ($Raw) { return $base64 }

# Base64 can contain + / = -> URL-encode it for the query string.
"$($DebuggerUrl.TrimEnd('/'))?data=$([Uri]::EscapeDataString($base64))"
