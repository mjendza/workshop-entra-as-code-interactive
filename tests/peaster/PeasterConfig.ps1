<#
.SYNOPSIS
    Central environment-variable contract for all peaster (Pester) tests.

.DESCRIPTION
    Declares every environment variable the peaster tests rely on, in one discoverable place.
    Tests dot-source this file and call Initialize-PeasterEnvironment. Defaults are applied
    only when a variable is unset/empty, so real environment values and CI overrides always
    take precedence.

    Add new env vars by adding one line to $PeasterEnvDefaults.

.EXAMPLE
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment
#>

$PeasterEnvDefaults = @{
    ARM_TENANT_ID       = 'c5863934-4575-4e54-bc4a-92ad95817e9d'             # live tenant id (GUID); empty = skip live tests
    AZURE_TENANT_ID     = ''             # alternative tenant id source
    CERT_PFX_PASSWORD   = 'Workshop123!' # init.ps1 default pfx password
    TAP_TARGET_USER     = '4439a43d-296e-41fe-8709-1f59a8c17bb6'             # UPN or object id to issue a TAP for; empty = skip TAP test
    TAP_LIFETIME_MINUTES = '60'          # requested TAP lifetime (10-43200)
}

function Initialize-PeasterEnvironment {
    [CmdletBinding()]
    param()
    foreach ($name in $PeasterEnvDefaults.Keys) {
        if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name))) {
            Set-Item -Path "env:$name" -Value $PeasterEnvDefaults[$name]
        }
    }
}

<#
.SYNOPSIS
    Resolve the live ClientId / TenantId / Graph availability for the certificate-SP tests.

.DESCRIPTION
    Single source of truth so the live inputs can be resolved IN BOTH Pester phases:
      - BeforeDiscovery uses it to compute the -Skip decision.
      - BeforeAll uses it to get the actual values at run time.

    This matters because variables assigned inside a BeforeDiscovery block live only in the
    discovery phase; they are $null inside BeforeAll (run phase). Resolving via this function in
    BeforeAll is what makes ClientId/TenantId non-null when Connect-MgGraph is called.

    Returns a hashtable: @{ ClientId; TenantId; HasGraph; HasTerraform; TerraformError }
    Any unresolved value is $null.
#>
function Resolve-PeasterLiveSp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [string] $OutputName = 'sp_with_certificate_client_id'
    )

    $tenantId = $env:ARM_TENANT_ID
    if ([string]::IsNullOrWhiteSpace($tenantId)) { $tenantId = $env:AZURE_TENANT_ID }

    $hasGraph     = $null -ne (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)
    $hasTerraform = $null -ne (Get-Command terraform -ErrorAction SilentlyContinue)

    $clientId       = $null
    $terraformError = $null
    if ($hasTerraform) {
        try {
            Push-Location $RepoRoot
            # Merge stderr into the capture, then validate: terraform may print a warning box
            # (e.g. "No outputs found") to the success stream when an output is absent, so a
            # client id is only accepted when it is a single, clean GUID. Anything else is
            # preserved as a diagnostic and ClientId stays $null (-> the live context skips).
            $raw  = (& terraform output -no-color -raw $OutputName 2>&1)
            $exit = $LASTEXITCODE
            # Flatten to text and strip any residual ANSI escape sequences for a clean diagnostic.
            $text = ((@($raw) | ForEach-Object { "$_" }) -join "`n") -replace "`e\[[0-9;]*m", ''
            $guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
            if ($exit -eq 0 -and $text.Trim() -match $guid) {
                $clientId = $text.Trim()
            } else {
                $clientId = $null
                $terraformError = "terraform output -raw $OutputName did not return a client id (exit $exit): " + (($text -replace '\s+', ' ').Trim())
            }
        } catch {
            $terraformError = "terraform output -raw $OutputName threw: $($_.Exception.Message)"
            $clientId = $null
        } finally {
            Pop-Location
        }
    } else {
        $terraformError = 'terraform executable not found on PATH'
    }
    if ([string]::IsNullOrWhiteSpace($clientId)) { $clientId = $null }

    # Fall back to an already-connected Graph context for the tenant id, if available.
    if ([string]::IsNullOrWhiteSpace($tenantId) -and $hasGraph) {
        try { $tenantId = (Get-MgContext -ErrorAction SilentlyContinue).TenantId } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($tenantId)) { $tenantId = $null }

    return @{
        ClientId       = $clientId
        TenantId       = $tenantId
        HasGraph       = $hasGraph
        HasTerraform   = $hasTerraform
        TerraformError = $terraformError
    }
}
