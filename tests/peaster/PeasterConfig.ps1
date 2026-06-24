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
    ARM_TENANT_ID       = ''             # live tenant id (GUID); empty = skip live tests
    AZURE_TENANT_ID     = ''             # alternative tenant id source
    CERT_PFX_PASSWORD   = 'Workshop123!' # init.ps1 default pfx password
    TAP_TARGET_USER     = ''             # UPN or object id to issue a TAP for; empty = skip TAP test
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
