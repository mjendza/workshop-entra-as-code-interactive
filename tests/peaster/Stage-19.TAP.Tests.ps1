<#
.SYNOPSIS
    Stage 19 - Prove the certificate-based Service Principal can issue a Temporary Access Pass.

.DESCRIPTION
    Uses the SAME certificate SP as Stage-16.SP-Cert.Tests.ps1 (app-only Connect-MgGraph via the
    cert, no secret) to generate a Temporary Access Pass (TAP) for a predefined user. This
    exercises the UserAuthenticationMethod.ReadWrite.All permission added to the SP in Stage 16.

    The target user and lifetime come from the central PeasterConfig.ps1 contract:
        TAP_TARGET_USER      - UPN or object id to issue the TAP for. Empty = skip.
        TAP_LIFETIME_MINUTES - requested lifetime in minutes (10-43200), default 60.

    The whole context auto-skips unless the live inputs (ClientId, TenantId, target user) and
    the Microsoft.Graph.Authentication module are available, so CI runs stay green.

    Graph permission required (granted + admin-consented on the SP):
        UserAuthenticationMethod.ReadWrite.All  (50483e42-d915-4231-9639-7fdb7fd190e5)

    Run:  $env:ARM_TENANT_ID='<guid>'; $env:TAP_TARGET_USER='user@contoso.com'
          Invoke-Pester ./tests/peaster/Stage-19.TAP.Tests.ps1
#>

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    # These locals exist only in the discovery phase; BeforeAll re-resolves via Resolve-PeasterLiveSp.
    $live = Resolve-PeasterLiveSp -RepoRoot $repoRoot
    $liveTargetUser = $env:TAP_TARGET_USER

    $skipTap = -not ($live.HasGraph -and $live.ClientId -and $live.TenantId -and -not [string]::IsNullOrWhiteSpace($liveTargetUser))
    if ($skipTap) {
        Write-PeasterSkipReason -Live $live -ContextName 'TAP generation (live)' -Extra @{ 'TargetUser ($env:TAP_TARGET_USER)' = $liveTargetUser }
    }
}

Describe "Stage 19: Temporary Access Pass (TAP)" {

    Context "TAP generation (live)" -Tag 'Live' -Skip:$skipTap {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
            $certDir  = Join-Path $repoRoot 'cert'

            # Re-resolve at run time: discovery-phase locals are not visible inside BeforeAll.
            $live = Resolve-PeasterLiveSp -RepoRoot $repoRoot
            $script:clientId   = $live.ClientId
            $script:tenantId   = $live.TenantId
            $script:targetUser = $env:TAP_TARGET_USER

            $script:lifetime = 60
            [int]::TryParse($env:TAP_LIFETIME_MINUTES, [ref]$script:lifetime) | Out-Null

            $pfxPath        = Join-Path $certDir 'cert.pfx'
            $thumbprintPath = Join-Path $certDir 'cert.thumbprint.txt'
            $script:thumb   = (Get-Content -Path $thumbprintPath -Raw).Trim()

            if ([string]::IsNullOrWhiteSpace($script:clientId) -or [string]::IsNullOrWhiteSpace($script:tenantId)) {
                throw (@(
                    "Live TAP context cannot authenticate - required inputs are missing:",
                    "  ClientId  : '$($script:clientId)'  (terraform output -raw sp_with_certificate_client_id)",
                    "  TenantId  : '$($script:tenantId)'  (`$env:ARM_TENANT_ID / AZURE_TENANT_ID / Get-MgContext)",
                    "  TargetUser: '$($script:targetUser)'  (`$env:TAP_TARGET_USER)",
                    "  Thumbprint: '$($script:thumb)'",
                    "  HasGraph  : $($live.HasGraph)   HasTerraform: $($live.HasTerraform)",
                    "  Terraform : $($live.TerraformError)"
                ) -join [Environment]::NewLine)
            }

            # Ensure the certificate is present in CurrentUser\My (same logic as auth.ps1).
            $found = Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object { $_.Thumbprint -eq $script:thumb }
            if (-not $found) {
                $secure = ConvertTo-SecureString -String $env:CERT_PFX_PASSWORD -Force -AsPlainText
                Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation 'Cert:\CurrentUser\My' -Password $secure | Out-Null
            }

            Connect-MgGraph `
                -ClientId              $script:clientId `
                -CertificateThumbprint $script:thumb `
                -TenantId              $script:tenantId `
                -NoWelcome

            $script:tapBaseUri = "https://graph.microsoft.com/v1.0/users/$($script:targetUser)/authentication/temporaryAccessPassMethods"

            # A user can hold only one TAP at a time; clear any existing one so the test is idempotent.
            try {
                $existing = Invoke-MgGraphRequest -Method GET -Uri $script:tapBaseUri -ErrorAction Stop
                foreach ($m in @($existing.value)) {
                    Invoke-MgGraphRequest -Method DELETE -Uri "$($script:tapBaseUri)/$($m.id)" -ErrorAction Stop | Out-Null
                }
            } catch {
                Write-Verbose "Could not pre-clear existing TAPs: $($_.Exception.Message)"
            }

            $script:createdTapId = $null
        }

        AfterAll {
            if ($script:createdTapId) {
                try { Invoke-MgGraphRequest -Method DELETE -Uri "$($script:tapBaseUri)/$($script:createdTapId)" -ErrorAction SilentlyContinue | Out-Null } catch { }
            }
            try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
        }

        It "is connected app-only as the certificate SP (no secret)" {
            $ctx = Get-MgContext
            $ctx.AuthType | Should -Be 'AppOnly'
            $ctx.ClientId | Should -Be $script:clientId
        }

        It "generates a Temporary Access Pass for the predefined config user" {
            $body = @{
                isUsableOnce      = $true
                lifetimeInMinutes = $script:lifetime
            }

            # A missing/unconsented permission (403 Forbidden / Authorization_RequestDenied) is a
            # real defect of the deployment, not a reason to skip: surface it as a clear RED failure.
            try {
                $tap = Invoke-MgGraphRequest -Method POST -Uri $script:tapBaseUri -Body $body -ErrorAction Stop
            } catch {
                $status = $null
                try { $status = [int]$_.Exception.Response.StatusCode } catch { }
                if ($status -eq 403 -or $_.Exception.Message -match 'Authorization_RequestDenied|Forbidden') {
                    throw "TAP creation was denied (HTTP 403 Authorization_RequestDenied). The certificate SP is " +
                          "authenticated but lacks effective permission. Grant admin consent for " +
                          "'UserAuthenticationMethod.ReadWrite.All' on the SP (Entra ID -> App registrations -> " +
                          "the SpWithCertificate app -> API permissions -> Grant admin consent), then re-run. " +
                          "Underlying error: $($_.Exception.Message)"
                }
                throw "TAP creation failed (HTTP $status): $($_.Exception.Message)"
            }

            $script:createdTapId = $tap.id

            $tap                     | Should -Not -BeNullOrEmpty -Because "the SP must be able to create a TAP for the user"
            $tap.id                  | Should -Not -BeNullOrEmpty
            $tap.temporaryAccessPass | Should -Not -BeNullOrEmpty -Because "a usable pass code must be returned"
            $tap.lifetimeInMinutes   | Should -Be $script:lifetime
            $tap.isUsableOnce        | Should -BeTrue
        }
    }
}
