<#
.SYNOPSIS
    Central environment-variable contract for all peaster (Pester) tests.

.DESCRIPTION
    Declares every environment variable the peaster tests rely on, in one discoverable place.
    Tests dot-source this file and call Initialize-PeasterEnvironment.

    Values are resolved in precedence order:
      1. Real environment variables (CI overrides always win).
      2. tests/peaster/.env - gitignored, holds all tenant-specific values and secrets.
         Copy tests/peaster/.env.example to .env and fill it in.
      3. $PeasterEnvDefaults - neutral fallbacks only (timeouts, lifetimes); never secrets.

    Add new env vars by adding a line to .env.example (and $PeasterEnvDefaults if a safe
    neutral default exists).

.EXAMPLE
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment
#>

$PeasterConfigRoot = $PSScriptRoot

# Neutral fallbacks only. Tenant-specific values and secrets belong in .env (gitignored);
# see .env.example for the full variable contract with documentation.
$PeasterEnvDefaults = @{
    ARM_TENANT_ID       = ''             # live tenant id (GUID); empty = skip live tests
    AZURE_TENANT_ID     = ''             # alternative tenant id source
    CERT_PFX_PASSWORD   = ''             # pfx password (init.ps1 default is set in .env)
    TAP_TARGET_USER     = ''             # UPN or object id to issue a TAP for; empty = skip TAP test
    TAP_LIFETIME_MINUTES = '60'          # requested TAP lifetime (10-43200)

    # External-01 - Native Authentication email-OTP sign-up (External-01.NativeAuth-SignUp.E2E.Tests.ps1)
    NATIVE_AUTH_TENANT_SUBDOMAIN = ''    # external CIAM subdomain; empty = skip the live signup/federation tests
    NATIVE_AUTH_EMAIL_DOMAIN     = ''    # OTP mailbox domain; empty = skip
    NATIVE_AUTH_RSS_BASE         = ''    # fakemail RSS base URL; feed = <base>/<email>; empty = skip
    NATIVE_AUTH_CLIENT_ID        = ''    # optional override; else terraform output external_native_federation_client_id
    NATIVE_AUTH_SIGNIN_USERNAME  = ''    # sign-IN username; optional override, else terraform output external_native_signin_user_email
    NATIVE_AUTH_SIGNIN_PASSWORD  = ''    # sign-IN password; MUST match the native_auth_test_user module password
    NATIVE_AUTH_OTP_TIMEOUT_SEC  = '90'  # seconds to poll the RSS feed for the OTP mail (sign-up email verification)
    EXTERNAL_GRAPH_TENANT_ID     = ''    # external tenant id for post-test user cleanup (empty = leave user)
    EXTERNAL_GRAPH_CLIENT_ID     = ''    # app-only client id for cleanup (needs User.ReadWrite.All)
    EXTERNAL_GRAPH_CLIENT_SECRET = ''    # app-only client secret for cleanup

    # External-02 - Federation with Entra Workforce ID (External-02.FederationWithEntra.Simple.Tests.ps1)
    EXTERNAL_TENANT_ID               = '' # external CIAM tenant id (GUID); optional override, else terraform output external_tenant_id
    FEDERATION_WORKFORCE_CLIENT_ID   = '' # client_id for the authorize request; optional override, else terraform output external_native_federation_client_id
    WORKFORCE_FEDERATION_DOMAIN_NAME = '' # workforce tenant verified domain for domain_hint (e.g. 'contoso.onmicrosoft.com'); empty = skip domain_hint test
}

<#
.SYNOPSIS
    Load KEY=VALUE pairs from tests/peaster/.env into the process environment.

.DESCRIPTION
    Parses a dotenv-style file: one KEY=VALUE per line, blank lines and #-comments ignored,
    optional single/double quotes around the value are stripped. A variable already set in the
    real environment is never overwritten, so CI/session overrides keep precedence over .env.
    Missing file is fine - everything then comes from the environment and $PeasterEnvDefaults.
#>
function Import-PeasterDotEnv {
    [CmdletBinding()]
    param(
        [string] $Path = (Join-Path $PeasterConfigRoot '.env')
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrEmpty($trimmed) -or $trimmed.StartsWith('#')) { continue }

        $eq = $trimmed.IndexOf('=')
        if ($eq -lt 1) { continue }

        $name  = $trimmed.Substring(0, $eq).Trim()
        $value = $trimmed.Substring($eq + 1).Trim()
        if ($value.Length -ge 2 -and
            (($value.StartsWith('"') -and $value.EndsWith('"')) -or
             ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if ([string]::IsNullOrEmpty($value)) { continue }
        if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name))) {
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

function Initialize-PeasterEnvironment {
    [CmdletBinding()]
    param()

    Import-PeasterDotEnv

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

<#
.SYNOPSIS
    Build the Native Auth authority base URL from a CIAM tenant subdomain.

.DESCRIPTION
    $env:NATIVE_AUTH_TENANT_SUBDOMAIN is documented as the bare subdomain (e.g. "contoso"), but it's
    easy to instead paste the tenant's initial domain ("contoso.onmicrosoft.com"). Appending
    ".ciamlogin.com" / ".onmicrosoft.com" to that unstripped value produces a broken authority such
    as "contoso.onmicrosoft.com.ciamlogin.com/contoso.onmicrosoft.com.onmicrosoft.com". Stripping a
    trailing ".onmicrosoft.com" first makes both input forms resolve to the same, correct authority:
    https://{subdomain}.ciamlogin.com/{subdomain}.onmicrosoft.com
#>
function Get-PeasterNativeAuthAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Subdomain
    )

    $bare = $Subdomain.Trim() -replace '(?i)\.onmicrosoft\.com$', ''
    return "https://$bare.ciamlogin.com/$bare.onmicrosoft.com"
}

<#
.SYNOPSIS
    Resolve the Native.Federation (External-01) application (client) id.

.DESCRIPTION
    Single source of truth for the External-01 native-auth client id so it can be resolved in BOTH
    Pester phases (BeforeDiscovery for the -Skip decision, BeforeAll for the run).

    Resolution order:
      1. $env:NATIVE_AUTH_CLIENT_ID (explicit override)
      2. terraform output -raw external_native_federation_client_id, run in the external_tenant dir
         (that output is defined in external_tenant/main.tf).

    Only a single clean GUID is accepted; anything else (warning box, empty, error) leaves ClientId
    $null so the live context skips. Returns @{ ClientId; Error } - Error carries the terraform
    diagnostic for a clear skip/failure message.
#>
function Resolve-PeasterNativeClientId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot
    )

    $guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'

    $override = $env:NATIVE_AUTH_CLIENT_ID
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        if ($override -match $guid) {
            return @{ ClientId = $override; Error = $null }
        }
        return @{ ClientId = $null; Error = "`$env:NATIVE_AUTH_CLIENT_ID is set but is not a GUID: '$override'" }
    }

    $externalDir = Join-Path $RepoRoot 'external_tenant'
    $tf = Get-PeasterTerraformOutputRaw -RepoRoot $externalDir -Name 'external_native_federation_client_id'
    if ($tf.Value -and $tf.Value -match $guid) {
        return @{ ClientId = $tf.Value; Error = $null }
    }

    $err = $tf.Error
    if (-not $err -and $tf.Value) {
        $err = "terraform output -raw external_native_federation_client_id did not return a client id: $($tf.Value)"
    }
    return @{ ClientId = $null; Error = $err }
}

<#
.SYNOPSIS
    Resolve the External-01 native-auth SIGN-IN username (an e-mail address).

.DESCRIPTION
    Single source of truth so the sign-in username can be resolved in both Pester phases.

    Resolution order:
      1. $env:NATIVE_AUTH_SIGNIN_USERNAME (explicit override)
      2. terraform output -raw external_native_signin_user_email, run in the external_tenant dir
         (produced by the native_auth_test_user module when var.native_signin_user_email is set).

    Returns @{ Username; Error } - Username is $null (with Error set) when the module was not applied.
#>
function Resolve-PeasterNativeSignInUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot
    )

    $override = $env:NATIVE_AUTH_SIGNIN_USERNAME
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        return @{ Username = $override.Trim(); Error = $null }
    }

    $externalDir = Join-Path $RepoRoot 'external_tenant'
    $tf = Get-PeasterTerraformOutputRaw -RepoRoot $externalDir -Name 'external_native_signin_user_email'
    if ($tf.Value -and $tf.Value -match '@') {
        return @{ Username = $tf.Value.Trim(); Error = $null }
    }

    $err = $tf.Error
    if (-not $err) {
        $err = 'set $env:NATIVE_AUTH_SIGNIN_USERNAME or apply external_tenant with -var native_signin_user_email=<email> (output external_native_signin_user_email)'
    }
    return @{ Username = $null; Error = $err }
}

<#
.SYNOPSIS
    Resolve the External-02 federation test inputs (external tenant id + client id).

.DESCRIPTION
    Single source of truth so the External-02 inputs can be resolved in BOTH Pester phases
    (BeforeDiscovery for the -Skip decision, BeforeAll for the run).

    Resolution order (env values come from the session, CI, or tests/peaster/.env):
      TenantId : 1. $env:EXTERNAL_TENANT_ID
                 2. terraform output -raw external_tenant_id, run in the external_tenant dir
      ClientId : 1. $env:FEDERATION_WORKFORCE_CLIENT_ID
                 2. terraform output -raw external_native_federation_client_id, run in the
                    external_tenant dir (the app registered in the external tenant with the
                    oidcdebugger.com redirect URI - the client the authorize request must use)

    Only a single clean GUID is accepted; anything else leaves the value $null so the live
    context skips. Returns @{ TenantId; ClientId; TenantError; ClientError }.
#>
function Resolve-PeasterFederationInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RepoRoot
    )

    $guid        = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    $externalDir = Join-Path $RepoRoot 'external_tenant'

    $tenantId    = $env:EXTERNAL_TENANT_ID
    $tenantError = $null
    if (-not [string]::IsNullOrWhiteSpace($tenantId)) {
        if ($tenantId -notmatch $guid) {
            $tenantError = "`$env:EXTERNAL_TENANT_ID is set but is not a GUID: '$tenantId'"
            $tenantId    = $null
        }
    } else {
        $tf = Get-PeasterTerraformOutputRaw -RepoRoot $externalDir -Name 'external_tenant_id'
        if ($tf.Value -and $tf.Value -match $guid) {
            $tenantId = $tf.Value
        } else {
            $tenantId    = $null
            $tenantError = $tf.Error
            if (-not $tenantError) {
                $tenantError = "terraform output -raw external_tenant_id did not return a tenant id: $($tf.Value)"
            }
        }
    }

    $clientId    = $env:FEDERATION_WORKFORCE_CLIENT_ID
    $clientError = $null
    if (-not [string]::IsNullOrWhiteSpace($clientId)) {
        if ($clientId -notmatch $guid) {
            $clientError = "`$env:FEDERATION_WORKFORCE_CLIENT_ID is set but is not a GUID: '$clientId'"
            $clientId    = $null
        }
    } else {
        $tf = Get-PeasterTerraformOutputRaw -RepoRoot $externalDir -Name 'external_native_federation_client_id'
        if ($tf.Value -and $tf.Value -match $guid) {
            $clientId = $tf.Value
        } else {
            $clientId    = $null
            $clientError = $tf.Error
            if (-not $clientError) {
                $clientError = "terraform output -raw external_native_federation_client_id did not return a client id: $($tf.Value)"
            }
        }
    }

    return @{
        TenantId    = $tenantId
        ClientId    = $clientId
        TenantError = $tenantError
        ClientError = $clientError
    }
}
