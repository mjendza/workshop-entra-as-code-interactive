<#
.SYNOPSIS
    External-01 - Prove the Native.Federation app supports Native Authentication email+password sign-in.

.DESCRIPTION
    Drives Microsoft Entra's Native Authentication SIGN-IN flow for an EXISTING user using the
    email + PASSWORD method (matching the External-01 password user flow) against the app enabled by the
    sso_app_native module (nativeAuthenticationApisEnabled = "all"):

        initiate  ->  challenge (returns "password")  ->  token (grant_type=password)

    Password sign-in does NOT use email OTP - the user proves identity with their password directly, so
    no mailbox/RSS is involved here. The user and its password are created up front by Terraform
    (external_tenant/modules/user, the native_auth_test_user module); the test's password MUST match that module's.

    Reference: https://learn.microsoft.com/en-us/entra/identity-platform/reference-native-authentication-api?tabs=emailPassword

    Inputs come from the central PeasterConfig.ps1 contract:
        NATIVE_AUTH_TENANT_SUBDOMAIN  - external CIAM subdomain (authority host). Empty = skip.
        NATIVE_AUTH_CLIENT_ID         - optional client-id override; else terraform output
                                        external_native_federation_client_id (external_tenant dir).
        NATIVE_AUTH_SIGNIN_USERNAME   - sign-in username (e-mail); optional override, else terraform
                                        output external_native_signin_user_email. Empty (both) = skip.
        NATIVE_AUTH_SIGNIN_PASSWORD   - sign-in password; must equal the native_auth_test_user password.

    The whole context auto-skips unless the client id, the CIAM subdomain and the sign-in username are
    available, so CI runs stay green when the inputs aren't provided.

    Run:  $env:NATIVE_AUTH_TENANT_SUBDOMAIN='<subdomain>'
          Invoke-Pester ./tests/peaster/External-01.NativeAuth-SignIn.E2E.Tests.ps1 -Output Detailed
#>

# Shared native-auth flow helpers (Invoke-NativeAuth, ConvertFrom-JwtPayload) live in
# NativeAuthHelpers.ps1; they are dot-sourced inside BeforeAll because Pester 5 does not carry
# file-scope function definitions into the run phase.

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    # Discovery-phase locals only; BeforeAll re-resolves for the run phase.
    $native    = Resolve-PeasterNativeClientId -RepoRoot $repoRoot
    $signIn    = Resolve-PeasterNativeSignInUser -RepoRoot $repoRoot
    $subdomain = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
    $password  = $env:NATIVE_AUTH_SIGNIN_PASSWORD

    $skipLive = -not ($native.ClientId `
        -and $signIn.Username `
        -and -not [string]::IsNullOrWhiteSpace($subdomain) `
        -and -not [string]::IsNullOrWhiteSpace($password))
    if ($skipLive) {
        $reasons = [System.Collections.Generic.List[string]]::new()
        if (-not $native.ClientId) {
            $why = if ($native.Error) { $native.Error } else { 'set $env:NATIVE_AUTH_CLIENT_ID or deploy external_tenant (external_native_federation_client_id)' }
            $reasons.Add("ClientId is missing -> $why")
        }
        if ([string]::IsNullOrWhiteSpace($subdomain)) {
            $reasons.Add('TenantSubdomain is missing (set $env:NATIVE_AUTH_TENANT_SUBDOMAIN to the external CIAM subdomain)')
        }
        if (-not $signIn.Username) {
            $reasons.Add("SignInUsername is missing -> $($signIn.Error)")
        }
        if ([string]::IsNullOrWhiteSpace($password)) {
            $reasons.Add('SignInPassword is missing (set $env:NATIVE_AUTH_SIGNIN_PASSWORD to match the native_auth_test_user password)')
        }
        Write-Warning ("[peaster] Skipping live context 'Sign-in via Native Auth (live)' because:`n  - " + ($reasons -join "`n  - "))
    }
}

Describe "External-01: Native Authentication email+password sign-in" {

    Context "Sign-in via Native Auth (live)" -Tag 'Live' -Skip:$skipLive {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            . "$PSScriptRoot/NativeAuthHelpers.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

            # Re-resolve at run time: discovery-phase locals are not visible inside BeforeAll.
            $native = Resolve-PeasterNativeClientId -RepoRoot $repoRoot
            $signIn = Resolve-PeasterNativeSignInUser -RepoRoot $repoRoot
            $script:clientId  = $native.ClientId
            $script:subdomain = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
            $script:username  = $signIn.Username
            $script:password  = $env:NATIVE_AUTH_SIGNIN_PASSWORD

            if ([string]::IsNullOrWhiteSpace($script:clientId) -or [string]::IsNullOrWhiteSpace($script:subdomain) -or
                [string]::IsNullOrWhiteSpace($script:username) -or [string]::IsNullOrWhiteSpace($script:password)) {
                throw (@(
                    "Live Native Auth sign-in context cannot run - required inputs are missing:",
                    "  ClientId : '$($script:clientId)'  (`$env:NATIVE_AUTH_CLIENT_ID / terraform output external_native_federation_client_id)",
                    "  Subdomain: '$($script:subdomain)'  (`$env:NATIVE_AUTH_TENANT_SUBDOMAIN)",
                    "  Username : '$($script:username)'  (`$env:NATIVE_AUTH_SIGNIN_USERNAME / terraform output external_native_signin_user_email)",
                    "  Password : $([string]::IsNullOrWhiteSpace($script:password) ? '<empty>' : '<set>')  (`$env:NATIVE_AUTH_SIGNIN_PASSWORD)",
                    "  Terraform: $($native.Error) | $($signIn.Error)"
                ) -join [Environment]::NewLine)
            }

            $script:authBase = Get-PeasterNativeAuthAuthority -Subdomain $script:subdomain

            # Cross-It state.
            $script:continuationToken = $null
            $script:idToken           = $null

            Write-Verbose "Native Auth password sign-in: authority=$($script:authBase) username=$($script:username)"
        }

        It "initiates the sign-in flow and receives a continuation token" {
            $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'oauth2/v2.0/initiate' -Form @{
                client_id      = $script:clientId
                username       = $script:username
                challenge_type = 'password redirect'
            }

            if (-not $resp.Ok) {
                throw "oauth2/initiate failed (HTTP $($resp.Status)) at $($resp.Uri): error=$($resp.Data.error) suberror=$($resp.Data.suberror) desc=$($resp.Data.error_description)"
            }
            $resp.Data.continuation_token | Should -Not -BeNullOrEmpty -Because "the initiate step must return a continuation_token"
            $script:continuationToken = $resp.Data.continuation_token
        }

        It "requests the password challenge" {
            $script:continuationToken | Should -Not -BeNullOrEmpty -Because "the initiate step must have run first"

            $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'oauth2/v2.0/challenge' -Form @{
                client_id          = $script:clientId
                challenge_type     = 'password redirect'
                continuation_token = $script:continuationToken
            }

            if (-not $resp.Ok) {
                throw "oauth2/challenge failed (HTTP $($resp.Status)) at $($resp.Uri): error=$($resp.Data.error) suberror=$($resp.Data.suberror) desc=$($resp.Data.error_description)"
            }
            $resp.Data.challenge_type | Should -Be 'password' -Because "the email+password flow must resolve to a password challenge (no OTP)"
            $script:continuationToken = $resp.Data.continuation_token
        }

        It "submits the password and obtains an id_token for the signed-in user" {
            $tok = Invoke-NativeAuth -BaseUri $script:authBase -Path 'oauth2/v2.0/token' -Form @{
                client_id          = $script:clientId
                continuation_token = $script:continuationToken
                grant_type         = 'password'
                password           = $script:password
                scope              = 'openid offline_access'
            }
            if (-not $tok.Ok) {
                # A wrong password (invalid_grant / invalid_password) means the test env password and the
                # Terraform module password are out of sync - surface it as a clear red failure.
                throw "token endpoint failed (HTTP $($tok.Status)) at $($tok.Uri): error=$($tok.Data.error) suberror=$($tok.Data.suberror) desc=$($tok.Data.error_description)"
            }

            $tok.Data.id_token | Should -Not -BeNullOrEmpty -Because "an id_token must be issued on successful password sign-in"
            $script:idToken = $tok.Data.id_token

            # The app registration doesn't currently emit an email/preferred_username claim on the
            # id_token (would need the "email" optional claim configured) - identity is asserted via
            # the `sub` claim instead until that's added.
            $claims = ConvertFrom-JwtPayload -Jwt $script:idToken
            $claimsJson = $claims | ConvertTo-Json -Depth 10 -Compress
            $claims.sub | Should -Not -BeNullOrEmpty -Because "the id_token must identify the signed-in user via 'sub' - full id_token claims: $claimsJson"
        }
    }
}
