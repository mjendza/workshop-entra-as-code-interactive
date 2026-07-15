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

    Inputs from PeasterConfig.ps1 / environment:
        NATIVE_AUTH_TENANT_SUBDOMAIN          - external CIAM subdomain (e.g. 'b2ctenantmj')
        FEDERATION_EXTERNAL_TENANT_ID         - tenant id GUID of the external CIAM tenant
        FEDERATION_WORKFORCE_CLIENT_ID        - client_id of the workforce federation SSO app
                                                (the OidcDebugger_SSO module in the root main.tf)
        WORKFORCE_FEDERATION_DOMAIN_NAME      - verified domain of the workforce tenant used as
                                                domain_hint (e.g. 'contoso.onmicrosoft.com')

    Run:  Invoke-Pester ./tests/peaster/External-02.FederationWithEntra.Simple.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $subdomain  = $env:NATIVE_AUTH_TENANT_SUBDOMAIN
    $tenantId   = $env:FEDERATION_EXTERNAL_TENANT_ID
    $clientId   = $env:FEDERATION_WORKFORCE_CLIENT_ID
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
            $reasons.Add('FEDERATION_EXTERNAL_TENANT_ID is missing')
        }
        if ([string]::IsNullOrWhiteSpace($clientId)) {
            $reasons.Add('FEDERATION_WORKFORCE_CLIENT_ID is missing')
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

            $script:subdomain = $env:NATIVE_AUTH_TENANT_SUBDOMAIN.Trim() -replace '(?i)\.onmicrosoft\.com$', ''
            $script:tenantId  = $env:FEDERATION_EXTERNAL_TENANT_ID
            $script:clientId  = $env:FEDERATION_WORKFORCE_CLIENT_ID

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
            Write-Verbose "Authorize URL (simple): $($script:authorizeUrl)"
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

            $script:subdomain  = $env:NATIVE_AUTH_TENANT_SUBDOMAIN.Trim() -replace '(?i)\.onmicrosoft\.com$', ''
            $script:tenantId   = $env:FEDERATION_EXTERNAL_TENANT_ID
            $script:clientId   = $env:FEDERATION_WORKFORCE_CLIENT_ID
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
            Write-Verbose "Authorize URL (domain_hint): $($script:authorizeUrl)"
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
