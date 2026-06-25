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
    Read a single raw Terraform output, separating a real value from terraform's noise.

.DESCRIPTION
    `terraform output -raw <name>` prints a warning box (e.g. "No outputs found") to the success
    stream when the output is absent, so a naive capture pollutes the value. This returns a
    hashtable @{ Value; Error }: Value is the clean output (or $null), Error carries the
    terraform diagnostic for a clear test failure message.
#>
function Get-PeasterTerraformOutputRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot,
        [Parameter(Mandatory)][string] $Name
    )

    if ($null -eq (Get-Command terraform -ErrorAction SilentlyContinue)) {
        return @{ Value = $null; Error = 'terraform executable not found on PATH' }
    }

    try {
        Push-Location $RepoRoot
        $raw  = (& terraform output -no-color -raw $Name 2>&1)
        $exit = $LASTEXITCODE
        $text = ((@($raw) | ForEach-Object { "$_" }) -join "`n") -replace "`e\[[0-9;]*m", ''
        $flat = ($text -replace '\s+', ' ').Trim()
        if ($exit -ne 0) {
            return @{ Value = $null; Error = "terraform output -raw $Name failed (exit $exit): $flat" }
        }
        $val = $text.Trim()
        if ([string]::IsNullOrWhiteSpace($val) -or $val -match 'No outputs found' -or $val -match '^\s*(Warning|Error):') {
            return @{ Value = $null; Error = "terraform output -raw $Name returned no value: $flat" }
        }
        return @{ Value = $val; Error = $null }
    } catch {
        return @{ Value = $null; Error = "terraform output -raw $Name threw: $($_.Exception.Message)" }
    } finally {
        Pop-Location
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

    # A client id is only accepted when terraform returns a single clean GUID; anything else
    # (warning box, empty, error) leaves ClientId $null and the live context skips.
    $tf             = Get-PeasterTerraformOutputRaw -RepoRoot $RepoRoot -Name $OutputName
    $terraformError = $tf.Error
    $guid           = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    if ($tf.Value -and $tf.Value -match $guid) {
        $clientId = $tf.Value
    } else {
        $clientId = $null
        if (-not $terraformError -and $tf.Value) {
            $terraformError = "terraform output -raw $OutputName did not return a client id: $($tf.Value)"
        }
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

<#
.SYNOPSIS
    Emit a Write-Warning explaining why a live Pester context is being skipped.

.DESCRIPTION
    Pester's -Skip gives no reason in the output, so when live tests show as [!] you cannot tell
    which input was missing. Call this from BeforeDiscovery when the skip flag is true; it lists
    each unmet requirement (and the terraform diagnostic) so the cause is visible in the run log.

    $Extra is an optional ordered list of additional "label = value" requirements (e.g. the TAP
    target user) whose value being null/empty also forces a skip.
#>
function Write-PeasterSkipReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable] $Live,
        [Parameter(Mandatory)][string]    $ContextName,
        [hashtable] $Extra
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if (-not $Live.HasGraph) { $reasons.Add('Microsoft.Graph.Authentication module is not installed') }
    if (-not $Live.ClientId) {
        $why = if ($Live.TerraformError) { $Live.TerraformError } else { 'terraform output -raw sp_with_certificate_client_id returned nothing' }
        $reasons.Add("ClientId is missing -> $why")
    }
    if (-not $Live.TenantId) { $reasons.Add('TenantId is missing (set $env:ARM_TENANT_ID / AZURE_TENANT_ID, or connect Graph first)') }
    if ($Extra) {
        foreach ($key in $Extra.Keys) {
            if ([string]::IsNullOrWhiteSpace([string]$Extra[$key])) { $reasons.Add("$key is missing") }
        }
    }

    if ($reasons.Count -gt 0) {
        Write-Warning ("[peaster] Skipping live context '$ContextName' because:`n  - " + ($reasons -join "`n  - "))
    }
}
