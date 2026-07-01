<#
.SYNOPSIS
    External-01 - Prove the Native.Federation app supports Native Authentication email+password sign-up.

.DESCRIPTION
    Drives Microsoft Entra's Native Authentication sign-up flow end-to-end using the email + PASSWORD
    method (matching the External-01 password user flow) against the app enabled by the sso_app_native
    module (external_tenant/modules/sso_app_native/main.tf, which sets
    nativeAuthenticationApisEnabled = "all"):

        start(password) -> challenge -> (read the OTP e-mail) -> continue(oob) -> continue(password) -> token

    The e-mail is still verified with a one-time passcode read from the fakemail RSS feed; a password is
    also set, so the account can subsequently sign in via the password flow (see the sign-in test).

    The one-time passcode is delivered to a throwaway mailbox on a fakemail service and read back from
    its RSS feed. The e-mail local-part is randomized per run; the mailbox domain and the RSS host are
    supplied at runtime via env vars (not committed here). After a successful sign-up the created user
    is deleted (best-effort) so runs stay idempotent.

    Reference: https://learn.microsoft.com/en-us/entra/identity-platform/reference-native-authentication-api?tabs=emailOtp

    Inputs come from the central PeasterConfig.ps1 contract:
        NATIVE_AUTH_TENANT_SUBDOMAIN  - external CIAM subdomain (authority host). Empty = skip.
        NATIVE_AUTH_CLIENT_ID         - optional client-id override; else terraform output
                                        external_native_federation_client_id (external_tenant dir).
        NATIVE_AUTH_EMAIL_DOMAIN      - mailbox domain (supplied at runtime). Empty = skip.
        NATIVE_AUTH_RSS_BASE          - fakemail RSS base URL; feed = <base>/<email>. Empty = skip.
        NATIVE_AUTH_OTP_TIMEOUT_SEC   - seconds to poll the RSS feed for the OTP mail (default 90).
        EXTERNAL_GRAPH_TENANT_ID / _CLIENT_ID / _CLIENT_SECRET - app-only creds for user cleanup
                                        (needs User.ReadWrite.All). Empty = leave the user.

    The whole context auto-skips unless the client id, the CIAM subdomain, the mailbox domain and the
    RSS base are all available, so CI runs stay green when the inputs aren't provided.

    Run:  $env:NATIVE_AUTH_TENANT_SUBDOMAIN='<subdomain>'
          Invoke-Pester ./tests/peaster/External-01.NativeAuth-SignUp.E2E.Tests.ps1 -Output Detailed
#>

# Shared native-auth flow helpers (Invoke-NativeAuth, ConvertFrom-JwtPayload, Get-OtpFromMailText,
# Get-OtpFromRss) live in NativeAuthHelpers.ps1; they are dot-sourced inside BeforeAll because Pester 5
# does not carry file-scope function definitions into the run phase.

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    # Discovery-phase locals only; BeforeAll re-resolves for the run phase.
    $native      = Resolve-PeasterNativeClientId -RepoRoot $repoRoot
    $subdomain   = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
    $emailDomain = $env:NATIVE_AUTH_EMAIL_DOMAIN
    $rssBase     = $env:NATIVE_AUTH_RSS_BASE

    $skipLive = -not ($native.ClientId `
        -and -not [string]::IsNullOrWhiteSpace($subdomain) `
        -and -not [string]::IsNullOrWhiteSpace($emailDomain) `
        -and -not [string]::IsNullOrWhiteSpace($rssBase))
    if ($skipLive) {
        $reasons = [System.Collections.Generic.List[string]]::new()
        if (-not $native.ClientId) {
            $why = if ($native.Error) { $native.Error } else { 'set $env:NATIVE_AUTH_CLIENT_ID or deploy external_tenant (external_native_federation_client_id)' }
            $reasons.Add("ClientId is missing -> $why")
        }
        if ([string]::IsNullOrWhiteSpace($subdomain)) {
            $reasons.Add('TenantSubdomain is missing (set $env:NATIVE_AUTH_TENANT_SUBDOMAIN to the external CIAM subdomain)')
        }
        if ([string]::IsNullOrWhiteSpace($emailDomain)) {
            $reasons.Add('EmailDomain is missing (set $env:NATIVE_AUTH_EMAIL_DOMAIN to the mailbox domain)')
        }
        if ([string]::IsNullOrWhiteSpace($rssBase)) {
            $reasons.Add('RssBase is missing (set $env:NATIVE_AUTH_RSS_BASE to the fakemail RSS base URL)')
        }
        Write-Warning ("[peaster] Skipping live context 'Sign-up via Native Auth (live)' because:`n  - " + ($reasons -join "`n  - "))
    }
}

Describe "External-01: Native Authentication email+password sign-up" {

    Context "Sign-up via Native Auth (live)" -Tag 'Live' -Skip:$skipLive {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            . "$PSScriptRoot/NativeAuthHelpers.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

            # Re-resolve at run time: discovery-phase locals are not visible inside BeforeAll.
            $native = Resolve-PeasterNativeClientId -RepoRoot $repoRoot
            $script:clientId    = $native.ClientId
            $script:subdomain   = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
            $script:emailDomain = $env:NATIVE_AUTH_EMAIL_DOMAIN
            $script:rssBase     = ($env:NATIVE_AUTH_RSS_BASE).TrimEnd('/')

            if ([string]::IsNullOrWhiteSpace($script:clientId) -or [string]::IsNullOrWhiteSpace($script:subdomain) -or
                [string]::IsNullOrWhiteSpace($script:emailDomain) -or [string]::IsNullOrWhiteSpace($script:rssBase)) {
                throw (@(
                    "Live Native Auth context cannot run - required inputs are missing:",
                    "  ClientId   : '$($script:clientId)'  (`$env:NATIVE_AUTH_CLIENT_ID / terraform output external_native_federation_client_id)",
                    "  Subdomain  : '$($script:subdomain)'  (`$env:NATIVE_AUTH_TENANT_SUBDOMAIN)",
                    "  EmailDomain: '$($script:emailDomain)'  (`$env:NATIVE_AUTH_EMAIL_DOMAIN)",
                    "  RssBase    : '$($script:rssBase)'  (`$env:NATIVE_AUTH_RSS_BASE)",
                    "  Terraform  : $($native.Error)"
                ) -join [Environment]::NewLine)
            }

            $script:authBase = Get-PeasterNativeAuthAuthority -Subdomain $script:subdomain

            # Fresh random mailbox per run; mailbox domain and RSS host come from env vars.
            $local            = [guid]::NewGuid().ToString('N').Substring(0, 12)
            $script:username  = "$local@$($script:emailDomain)"
            $script:rssUrl    = "$($script:rssBase)/$($script:username)"

            $script:otpTimeout = 90
            [int]::TryParse($env:NATIVE_AUTH_OTP_TIMEOUT_SEC, [ref]$script:otpTimeout) | Out-Null

            # Password for the email+password sign-up flow. The user is deleted afterwards, so this only
            # needs to satisfy the tenant password policy; it does not have to match anything.
            $script:password = 'Aa1!' + [guid]::NewGuid().ToString('N').Substring(0, 16)

            # Cross-It state.
            $script:continuationToken = $null
            $script:codeLength        = 0
            $script:otp               = $null
            $script:idToken           = $null
            $script:createdUser       = $null

            Write-Verbose "Native Auth sign-up: authority=$($script:authBase) username=$($script:username)"
        }

        AfterAll {
            # Best-effort cleanup of the user created by the sign-up. Never fails the run.
            if (-not $script:createdUser) { return }

            $tid = $env:EXTERNAL_GRAPH_TENANT_ID
            $cid = $env:EXTERNAL_GRAPH_CLIENT_ID
            $sec = $env:EXTERNAL_GRAPH_CLIENT_SECRET

            if ([string]::IsNullOrWhiteSpace($tid) -or [string]::IsNullOrWhiteSpace($cid) -or [string]::IsNullOrWhiteSpace($sec)) {
                Write-Warning "[peaster] Created user '$($script:createdUser)' was left in the tenant (set EXTERNAL_GRAPH_TENANT_ID/CLIENT_ID/CLIENT_SECRET to auto-delete)."
                return
            }

            try {
                $secure = ConvertTo-SecureString -String $sec -AsPlainText -Force
                $cred   = [System.Management.Automation.PSCredential]::new($cid, $secure)
                Connect-MgGraph -TenantId $tid -ClientSecretCredential $cred -NoWelcome -ErrorAction Stop

                $u      = $script:createdUser
                $filter = "identities/any(c:c/issuerAssignedId eq '$u' and c/signInType eq 'emailAddress')"
                $lookup = "https://graph.microsoft.com/v1.0/users?`$filter=$([uri]::EscapeDataString($filter))&`$count=true"
                $found  = Invoke-MgGraphRequest -Method GET -Uri $lookup -Headers @{ ConsistencyLevel = 'eventual' } -ErrorAction Stop
                foreach ($usr in @($found.value)) {
                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/users/$($usr.id)" -ErrorAction Stop | Out-Null
                    Write-Verbose "Deleted created user $u ($($usr.id))"
                }
            } catch {
                Write-Warning "[peaster] Could not delete created user '$($script:createdUser)': $($_.Exception.Message)"
            } finally {
                try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
            }
        }

        It "starts the sign-up flow and receives a continuation token" {
            $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/start' -Form @{
                client_id      = $script:clientId
                username       = $script:username
                password       = $script:password
                challenge_type = 'oob password redirect'
            }

            if (-not $resp.Ok) {
                throw "signup/start failed (HTTP $($resp.Status)) at $($resp.Uri): error=$($resp.Data.error) suberror=$($resp.Data.suberror) desc=$($resp.Data.error_description)"
            }
            $resp.Data.continuation_token | Should -Not -BeNullOrEmpty -Because "the start step must return a continuation_token"
            $script:continuationToken = $resp.Data.continuation_token
        }

        It "requests the email-OTP challenge" {
            $script:continuationToken | Should -Not -BeNullOrEmpty -Because "the start step must have run first"

            $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/challenge' -Form @{
                client_id          = $script:clientId
                challenge_type     = 'oob password redirect'
                continuation_token = $script:continuationToken
            }

            if (-not $resp.Ok) {
                throw "signup/challenge failed (HTTP $($resp.Status)) at $($resp.Uri): error=$($resp.Data.error) suberror=$($resp.Data.suberror) desc=$($resp.Data.error_description)"
            }
            $resp.Data.challenge_type    | Should -Be 'oob'   -Because "email OTP must resolve to an out-of-band challenge"
            $resp.Data.challenge_channel | Should -Be 'email' -Because "the code must be delivered by email"

            $script:continuationToken = $resp.Data.continuation_token
            if ($resp.Data.code_length) { $script:codeLength = [int]$resp.Data.code_length }
        }

        It "receives the OTP email in the fakemail mailbox (via RSS)" {
            $script:otp = Get-OtpFromRss -RssUrl $script:rssUrl -CodeLength $script:codeLength -TimeoutSec $script:otpTimeout

            $script:otp | Should -Not -BeNullOrEmpty -Because "the verification email must arrive in $($script:rssUrl)"
            if ($script:codeLength -gt 0) {
                $script:otp.Length | Should -Be $script:codeLength -Because "the code must match the challenge code_length"
            }
        }

        It "submits the OTP and obtains an id_token whose email claim matches the sign-up address" {
            $script:otp | Should -Not -BeNullOrEmpty -Because "the OTP must have been read from the mailbox first"

            $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/continue' -Form @{
                client_id          = $script:clientId
                continuation_token = $script:continuationToken
                grant_type         = 'oob'
                oob                = $script:otp
            }

            # The user flow may still require attributes and/or a password before completing. Handle the
            # documented follow-ups so the test is robust to the tenant's sign-up configuration.
            $guard = 0
            while (-not $resp.Ok -and $guard -lt 4) {
                $guard++
                $err = $resp.Data.error
                $ct  = $resp.Data.continuation_token

                if ($err -eq 'attributes_required') {
                    $attrs = [ordered]@{ displayName = 'Peaster Test' }
                    foreach ($ra in @($resp.Data.required_attributes)) {
                        if ($ra.name -and $ra.name -ne 'displayName') { $attrs[$ra.name] = 'peaster' }
                    }
                    $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/continue' -Form @{
                        client_id          = $script:clientId
                        continuation_token = $ct
                        grant_type         = 'attributes'
                        attributes         = ($attrs | ConvertTo-Json -Compress)
                    }
                }
                elseif ($err -eq 'credential_required') {
                    $ch = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/challenge' -Form @{
                        client_id          = $script:clientId
                        challenge_type     = 'oob password redirect'
                        continuation_token = $ct
                    }
                    $pct = if ($ch.Ok -and $ch.Data.continuation_token) { $ch.Data.continuation_token } else { $ct }
                    $resp = Invoke-NativeAuth -BaseUri $script:authBase -Path 'signup/v1.0/continue' -Form @{
                        client_id          = $script:clientId
                        continuation_token = $pct
                        grant_type         = 'password'
                        password           = $script:password
                    }
                }
                else { break }
            }

            if (-not $resp.Ok) {
                throw "signup/continue failed (HTTP $($resp.Status)) at $($resp.Uri): error=$($resp.Data.error) suberror=$($resp.Data.suberror) desc=$($resp.Data.error_description)"
            }
            $resp.Data.continuation_token | Should -Not -BeNullOrEmpty -Because "a completed sign-up returns a continuation_token for the token request"

            $tok = Invoke-NativeAuth -BaseUri $script:authBase -Path 'oauth/v2.0/token' -Form @{
                client_id          = $script:clientId
                continuation_token = $resp.Data.continuation_token
                grant_type         = 'continuation_token'
                scope              = 'openid offline_access'
            }
            if (-not $tok.Ok) {
                throw "token endpoint failed (HTTP $($tok.Status)) at $($tok.Uri): error=$($tok.Data.error) suberror=$($tok.Data.suberror) desc=$($tok.Data.error_description)"
            }

            $tok.Data.id_token | Should -Not -BeNullOrEmpty -Because "an id_token must be issued for the new user"
            $script:idToken = $tok.Data.id_token
            $script:createdUser = $script:username   # mark for AfterAll cleanup

            $claims = ConvertFrom-JwtPayload -Jwt $script:idToken
            $email  = if ($claims.email) { $claims.email } else { $claims.preferred_username }
            $email | Should -Be $script:username -Because "the token must identify the user that just signed up"
        }
    }
}
