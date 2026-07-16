<#
.SYNOPSIS
    External-02 - Prove the OpenID Connect authorize endpoint on the external CIAM tenant
    is reachable and returns a valid login page (federation with Entra Workforce ID).

.DESCRIPTION
    Constructs the OpenID Connect /authorize URL for the external CIAM tenant using:
        https://{subdomain}.ciamlogin.com/{tenant_id}/oauth2/v2.0/authorize

    with PKCE (S256 code_challenge) and validates that the endpoint responds with a redirect
    or HTML login page (HTTP 200/302).

    Test 1 - Simple OIDC authorize request (no domain_hint):
        Builds the authorize URL with scope=openid, response_type=code, prompt=login and PKCE,
        then issues an HTTP GET to confirm the endpoint is alive.

    Test 2 - OIDC authorize request with domain_hint:
        Same as Test 1 but adds domain_hint={WORKFORCE_FEDERATION_DOMAIN_NAME} to trigger
        automatic federation to the workforce tenant without the user picking a home realm.

    Inputs from PeasterConfig.ps1 / environment (see Resolve-PeasterFederationInputs):
        NATIVE_AUTH_TENANT_SUBDOMAIN          - external CIAM subdomain (e.g. 'b2ctenantmj')
        EXTERNAL_TENANT_ID                    - tenant id GUID of the external CIAM tenant;
                                                else terraform output external_tenant_id
        FEDERATION_WORKFORCE_CLIENT_ID        - client_id for the authorize request;
                                                else terraform output external_native_federation_client_id
        WORKFORCE_FEDERATION_DOMAIN_NAME      - verified domain of the workforce tenant used as
                                                domain_hint (e.g. 'contoso.onmicrosoft.com')

    Run:  Invoke-Pester ./tests/peaster/External-02.FederationWithEntra.Simple.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $fed      = Resolve-PeasterFederationInputs -RepoRoot $repoRoot

    $subdomain  = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
    $tenantId   = $fed.TenantId
    $clientId   = $fed.ClientId
    $domainHint = $env:WORKFORCE_FEDERATION_DOMAIN_NAME

    $skipSimple = -not (
        -not [string]::IsNullOrWhiteSpace($subdomain) -and
        -not [string]::IsNullOrWhiteSpace($tenantId) -and
        -not [string]::IsNullOrWhiteSpace($clientId)
    )

    $skipDomainHint = $skipSimple -or [string]::IsNullOrWhiteSpace($domainHint)

    if ($skipSimple) {
        $reasons = [System.Collections.Generic.List[string]]::new()
        if ([string]::IsNullOrWhiteSpace($subdomain)) {
            $reasons.Add('NATIVE_AUTH_TENANT_SUBDOMAIN is missing')
        }
        if ([string]::IsNullOrWhiteSpace($tenantId)) {
            $why = if ($fed.TenantError) { $fed.TenantError } else { 'set $env:EXTERNAL_TENANT_ID (e.g. in tests/peaster/.env)' }
            $reasons.Add("EXTERNAL_TENANT_ID is missing -> $why")
        }
        if ([string]::IsNullOrWhiteSpace($clientId)) {
            $why = if ($fed.ClientError) { $fed.ClientError } else { 'set $env:FEDERATION_WORKFORCE_CLIENT_ID (e.g. in tests/peaster/.env)' }
            $reasons.Add("FEDERATION_WORKFORCE_CLIENT_ID is missing -> $why")
        }
        Write-Warning ("[peaster] Skipping 'OpenID Connect authorize (simple)' because:`n  - " + ($reasons -join "`n  - "))
    }
    if ($skipDomainHint -and -not $skipSimple) {
        Write-Warning "[peaster] Skipping 'OpenID Connect authorize (domain_hint)' because: WORKFORCE_FEDERATION_DOMAIN_NAME is missing"
    }
}

Describe "External-02: Federation with Entra - OpenID Connect authorize endpoint" {

    Context "OpenID Connect authorize (simple)" -Tag 'Live' -Skip:$skipSimple {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
            $fed      = Resolve-PeasterFederationInputs -RepoRoot $repoRoot

            $script:subdomain = $env:NATIVE_AUTH_TENANT_SUBDOMAIN.Trim() -replace '(?i)\.onmicrosoft\.com$', ''
            $script:tenantId  = $fed.TenantId
            $script:clientId  = $fed.ClientId

            # Generate PKCE code_verifier and code_challenge (S256)
            $verifierBytes = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($verifierBytes)
            $script:codeVerifier = [Convert]::ToBase64String($verifierBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''

            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $challengeBytes = $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($script:codeVerifier))
            $script:codeChallenge = [Convert]::ToBase64String($challengeBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''

            $script:nonce = [guid]::NewGuid().ToString('N').Substring(0, 10)

            # Build the authorize URL
            $baseUrl = "https://$($script:subdomain).ciamlogin.com/$($script:tenantId)/oauth2/v2.0/authorize"
            $query = [System.Web.HttpUtility]::ParseQueryString('')
            $query['client_id']             = $script:clientId
            $query['nonce']                 = $script:nonce
            $query['redirect_uri']          = 'https://oidcdebugger.com/debug'
            $query['scope']                 = 'openid'
            $query['response_type']         = 'code'
            $query['prompt']                = 'login'
            $query['code_challenge_method'] = 'S256'
            $query['code_challenge']        = $script:codeChallenge

            $script:authorizeUrl = "$baseUrl`?$($query.ToString())"

            # Print the URL so it shows up in the test output as a clickable link for manual testing.
            Write-Host ''
            Write-Host '[peaster] External-02 authorize URL (simple) - open in a browser to test manually:' -ForegroundColor Cyan
            Write-Host $script:authorizeUrl -ForegroundColor Cyan
            Write-Host "[peaster] PKCE code_verifier (needed to redeem the returned code): $($script:codeVerifier)" -ForegroundColor DarkGray
        }

        It "constructs a valid OpenID Connect authorize URL" {
            $script:authorizeUrl | Should -Not -BeNullOrEmpty
            $script:authorizeUrl | Should -Match "^https://$([regex]::Escape($script:subdomain))\.ciamlogin\.com/"
            $script:authorizeUrl | Should -Match "client_id=$([regex]::Escape($script:clientId))"
            $script:authorizeUrl | Should -Match 'scope=openid'
            $script:authorizeUrl | Should -Match 'response_type=code'
            $script:authorizeUrl | Should -Match 'code_challenge_method=S256'
            $script:authorizeUrl | Should -Match 'code_challenge='
        }

        It "receives an HTTP 200 from the authorize endpoint (login page)" {
            # Follow redirects up to the login page; expect 200 (rendered login form)
            $response = Invoke-WebRequest -Uri $script:authorizeUrl -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop
            $response.StatusCode | Should -BeIn @(200, 302) -Because "the authorize endpoint must serve a login page or redirect to one"
        }
    }

    Context "OpenID Connect authorize (domain_hint)" -Tag 'Live' -Skip:$skipDomainHint {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
            $fed      = Resolve-PeasterFederationInputs -RepoRoot $repoRoot

            $script:subdomain  = $env:NATIVE_AUTH_TENANT_SUBDOMAIN.Trim() -replace '(?i)\.onmicrosoft\.com$', ''
            $script:tenantId   = $fed.TenantId
            $script:clientId   = $fed.ClientId
            $script:domainHint = $env:WORKFORCE_FEDERATION_DOMAIN_NAME

            # Generate PKCE code_verifier and code_challenge (S256)
            $verifierBytes = [byte[]]::new(32)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($verifierBytes)
            $script:codeVerifier = [Convert]::ToBase64String($verifierBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''

            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $challengeBytes = $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($script:codeVerifier))
            $script:codeChallenge = [Convert]::ToBase64String($challengeBytes) -replace '\+', '-' -replace '/', '_' -replace '=', ''

            $script:nonce = [guid]::NewGuid().ToString('N').Substring(0, 10)

            # Build the authorize URL with domain_hint
            $baseUrl = "https://$($script:subdomain).ciamlogin.com/$($script:tenantId)/oauth2/v2.0/authorize"
            $query = [System.Web.HttpUtility]::ParseQueryString('')
            $query['client_id']             = $script:clientId
            $query['nonce']                 = $script:nonce
            $query['redirect_uri']          = 'https://oidcdebugger.com/debug'
            $query['scope']                 = 'openid'
            $query['response_type']         = 'code'
            $query['prompt']                = 'login'
            $query['code_challenge_method'] = 'S256'
            $query['code_challenge']        = $script:codeChallenge
            $query['domain_hint']           = $script:domainHint

            $script:authorizeUrl = "$baseUrl`?$($query.ToString())"

            # Print the URL so it shows up in the test output as a clickable link for manual testing.
            Write-Host ''
            Write-Host '[peaster] External-02 authorize URL (domain_hint) - open in a browser to test manually:' -ForegroundColor Cyan
            Write-Host $script:authorizeUrl -ForegroundColor Cyan
            Write-Host "[peaster] PKCE code_verifier (needed to redeem the returned code): $($script:codeVerifier)" -ForegroundColor DarkGray
        }

        It "constructs a valid OpenID Connect authorize URL with domain_hint" {
            $script:authorizeUrl | Should -Not -BeNullOrEmpty
            $script:authorizeUrl | Should -Match "^https://$([regex]::Escape($script:subdomain))\.ciamlogin\.com/"
            $script:authorizeUrl | Should -Match "client_id=$([regex]::Escape($script:clientId))"
            $script:authorizeUrl | Should -Match 'scope=openid'
            $script:authorizeUrl | Should -Match 'response_type=code'
            $script:authorizeUrl | Should -Match 'code_challenge_method=S256'
            $script:authorizeUrl | Should -Match "domain_hint=$([regex]::Escape($script:domainHint))"
        }

        It "receives an HTTP 200 from the authorize endpoint with domain_hint (federation redirect)" {
            # With domain_hint the endpoint may redirect to the workforce IdP; expect 200 or 302
            $response = Invoke-WebRequest -Uri $script:authorizeUrl -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
            $response.StatusCode | Should -BeIn @(200, 302) -Because "the authorize endpoint with domain_hint must serve a login page or redirect to the federated IdP"
        }
    }
}
