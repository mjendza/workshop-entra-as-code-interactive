<#
.SYNOPSIS
    Stage 20 helper - inspect the identity verification profiles and the
    Verified ID step-up Conditional Access policy created by Terraform.

.DESCRIPTION
    The verifiedIdProfile Graph API supports DELEGATED permissions only, so this
    script signs you in interactively (Authentication Policy Administrator or
    higher) instead of using the workshop Service Principal.

    It also reads the Conditional Access policy with the
    'Prefer: include-unknown-enum-members' header so the preview grant control
    is returned by name (e.g. "verifiedID") instead of "unknownFutureValue".

.EXAMPLE
    pwsh ./scripts/stage-20/verify.ps1 -PolicyId (terraform output -raw high_assurance_policy_id)
#>
param(
    [Parameter(Mandatory = $false)]
    [string] $PolicyId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    throw "Install the Graph SDK first: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
}

Connect-MgGraph -NoWelcome -Scopes @(
    'VerifiedId-Profile.Read.All',
    'Policy.Read.All'
)

$headers = @{ Prefer = 'include-unknown-enum-members' }

Write-Host "`n=== Identity verification profiles ===" -ForegroundColor Cyan
$profiles = Invoke-MgGraphRequest -Method GET -Headers $headers `
    -Uri 'https://graph.microsoft.com/beta/identity/verifiedId/profiles'
if (-not $profiles.value) {
    Write-Warning "No identity verification profile found. Create one (purpose: Verification) - see doc/stage-20/README.md."
}
foreach ($p in $profiles.value) {
    [pscustomobject]@{
        Name       = $p.name
        State      = $p.state
        Priority   = $p.priority
        Method     = $p.verifiedIdProfileConfiguration.methodType
        Issuer     = $p.verifiedIdProfileConfiguration.acceptedIssuer
        Purpose    = ($p.verifiedIdUsageConfigurations | ForEach-Object { $_.purpose }) -join ','
        TestOnly   = ($p.verifiedIdUsageConfigurations | ForEach-Object { $_.isEnabledForTestOnly }) -join ','
        FaceCheck  = $p.faceCheckConfiguration.isEnabled
    } | Format-List
}

if ($profiles.value) {
    $ids = ($profiles.value | ForEach-Object { "`"$($_.id)`"" }) -join ', '
    Write-Host "Paste into module `"HighAssurance_Policy`" in main.tf (all profiles):" -ForegroundColor Green
    Write-Host "  verified_id_profile_ids = [$ids]`n"
}

Write-Host "=== Authentication method: Verified ID ===" -ForegroundColor Cyan
$method = Invoke-MgGraphRequest -Method GET -Headers $headers `
    -Uri 'https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/verifiableCredentials'
[pscustomobject]@{
    State    = $method.state
    Targets  = ($method.includeTargets | ForEach-Object { $_.id }) -join ','
    Profiles = ($method.includeTargets | ForEach-Object { $_.verifiedIdProfiles }) -join ','
} | Format-List

if ($PolicyId) {
    Write-Host "=== Conditional Access policy $PolicyId ===" -ForegroundColor Cyan
    $policy = Invoke-MgGraphRequest -Method GET -Headers $headers `
        -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/$PolicyId"
    [pscustomobject]@{
        DisplayName     = $policy.displayName
        State           = $policy.state
        ClientAppTypes  = $policy.conditions.clientAppTypes -join ','
        Applications    = $policy.conditions.applications.includeApplications -join ','
        IncludeGroups   = $policy.conditions.users.includeGroups -join ','
        BuiltInControls = $policy.grantControls.builtInControls -join ','
    } | Format-List
}
