<#
.SYNOPSIS
    Stage 16 - Pester tests proving the certificate-based Service Principal and its
    certificate are valid.

.DESCRIPTION
    Two layers of proof, mirroring doc/stage-16/README.md:

      Offline (-Tag Offline)  Always runs. Validates the local cert artifacts produced by
                              scripts/stage-16/init.ps1 (cert/cert.pem, cert/cert.pfx,
                              cert/cert.thumbprint.txt): valid X.509, thumbprint files agree,
                              RSA-2048 / SHA256, not expired, pfx opens with the password.

      Live (-Tag Live)        Auto-skips unless live inputs and the Microsoft.Graph module
                              are present. Authenticates app-only to Microsoft Graph as the
                              SP using the certificate (no secret), and verifies via Terraform
                              state that the uploaded certificate is recorded and unexpired
                              (no Application.Read.All required).

    CI usage:    Invoke-Pester ./tests/peaster -ExcludeTagFilter Live
    Full usage:  $env:ARM_TENANT_ID = '<tenant-guid>'; Invoke-Pester ./tests/peaster

    Live inputs:
      ClientId  - terraform output -raw sp_with_certificate_client_id  (run from repo root)
      TenantId  - $env:ARM_TENANT_ID / $env:AZURE_TENANT_ID, else current Get-MgContext
      Password  - $env:CERT_PFX_PASSWORD, else 'Workshop123!' (init.ps1 default)
#>

BeforeDiscovery {
    . "$PSScriptRoot/PeasterConfig.ps1"
    Initialize-PeasterEnvironment

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $certDir  = Join-Path $repoRoot 'cert'

    # Resolve the ClientId/TenantId needed by the live context. Any failure leaves them $null,
    # and the live It blocks are skipped rather than failed. NOTE: these locals exist only in the
    # discovery phase; BeforeAll re-resolves them via Resolve-PeasterLiveSp for the run phase.
    $live = Resolve-PeasterLiveSp -RepoRoot $repoRoot
    $skipLive = -not ($live.HasGraph -and $live.ClientId -and $live.TenantId)
    if ($skipLive) {
        Write-PeasterSkipReason -Live $live -ContextName 'Service Principal certificate authentication (live)'
    }
}

Describe "Stage 16: Certificate-Based SP Authentication" {

    Context "Certificate artifacts (offline)" -Tag 'Offline' {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
            $certDir  = Join-Path $repoRoot 'cert'

            $script:pemPath        = Join-Path $certDir 'cert.pem'
            $script:pfxPath        = Join-Path $certDir 'cert.pfx'
            $script:thumbprintPath = Join-Path $certDir 'cert.thumbprint.txt'

            $script:pfxPassword = $env:CERT_PFX_PASSWORD

            # Parse the public certificate once for the whole context.
            $script:pemCert = $null
            if (Test-Path $script:pemPath) {
                try {
                    $script:pemCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPemFile($script:pemPath)
                } catch {
                    # Older PowerShell: fall back to loading the DER bytes embedded in the PEM.
                    $pemText = Get-Content -Path $script:pemPath -Raw
                    $b64 = ($pemText -replace '-----BEGIN CERTIFICATE-----', '' -replace '-----END CERTIFICATE-----', '').Trim()
                    $der = [Convert]::FromBase64String($b64)
                    $script:pemCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($der)
                }
            }
        }

        It "cert/cert.pem exists and parses as a valid X.509 certificate" {
            $script:pemPath | Should -Exist -Because "init.ps1 writes the public certificate Terraform uploads"
            $script:pemCert | Should -Not -BeNullOrEmpty -Because "cert.pem must be a parseable X.509 certificate"
        }

        It "cert/cert.thumbprint.txt matches the thumbprint of cert.pem" {
            $script:thumbprintPath | Should -Exist
            $fileThumb = (Get-Content -Path $script:thumbprintPath -Raw).Trim()
            $fileThumb | Should -Not -BeNullOrEmpty
            $script:pemCert.Thumbprint | Should -Be $fileThumb -Because "auth.ps1 and Terraform must refer to the same certificate"
        }

        It "public key is RSA with a 2048-bit key length" {
            $script:pemCert.PublicKey.Oid.FriendlyName | Should -Match 'RSA' -Because "init.ps1 generates an RSA key"
            $rsa = $script:pemCert.PublicKey.GetRSAPublicKey()
            $rsa | Should -Not -BeNullOrEmpty
            $rsa.KeySize | Should -Be 2048 -Because "init.ps1 uses -KeyLength 2048"
        }

        It "is signed with SHA256" {
            $script:pemCert.SignatureAlgorithm.FriendlyName | Should -Match 'sha256' -Because "init.ps1 uses -HashAlgorithm SHA256"
        }

        It "is currently valid in time (not expired, already active)" {
            $now = [DateTime]::Now
            $script:pemCert.NotBefore | Should -BeLessOrEqual $now -Because "the certificate must already be active"
            $script:pemCert.NotAfter  | Should -BeGreaterThan $now -Because "the certificate must not be expired"
        }

        It "cert/cert.pfx opens with the workshop password and carries the private key" {
            $script:pfxPath | Should -Exist -Because "auth.ps1 re-imports cert.pfx when the cert is missing from the store"
            $secure = ConvertTo-SecureString -String $script:pfxPassword -Force -AsPlainText
            $pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                $script:pfxPath,
                $secure,
                [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            $pfx.HasPrivateKey | Should -BeTrue -Because "the pfx must contain the signing private key"
            $pfx.Thumbprint    | Should -Be $script:pemCert.Thumbprint -Because "the pfx and pem must be the same certificate"
        }
    }

    Context "Service Principal certificate authentication (live)" -Tag 'Live' -Skip:$skipLive {

        BeforeAll {
            . "$PSScriptRoot/PeasterConfig.ps1"
            Initialize-PeasterEnvironment

            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
            $certDir  = Join-Path $repoRoot 'cert'

            # Re-resolve at run time: discovery-phase locals are not visible inside BeforeAll.
            $live = Resolve-PeasterLiveSp -RepoRoot $repoRoot
            $script:clientId = $live.ClientId
            $script:tenantId = $live.TenantId

            $pfxPath        = Join-Path $certDir 'cert.pfx'
            $thumbprintPath = Join-Path $certDir 'cert.thumbprint.txt'
            $script:thumb   = (Get-Content -Path $thumbprintPath -Raw).Trim()

            $pfxPassword = $env:CERT_PFX_PASSWORD

            # Fail loudly with the resolved state instead of a cryptic Connect-MgGraph binding error.
            if ([string]::IsNullOrWhiteSpace($script:clientId) -or [string]::IsNullOrWhiteSpace($script:tenantId)) {
                throw (@(
                    "Live context cannot authenticate - required inputs are missing:",
                    "  ClientId  : '$($script:clientId)'  (terraform output -raw sp_with_certificate_client_id)",
                    "  TenantId  : '$($script:tenantId)'  (`$env:ARM_TENANT_ID / AZURE_TENANT_ID / Get-MgContext)",
                    "  Thumbprint: '$($script:thumb)'",
                    "  HasGraph  : $($live.HasGraph)   HasTerraform: $($live.HasTerraform)",
                    "  Terraform : $($live.TerraformError)"
                ) -join [Environment]::NewLine)
            }

            # Ensure the certificate is present in CurrentUser\My (same logic as auth.ps1).
            $found = Get-ChildItem -Path 'Cert:\CurrentUser\My' | Where-Object { $_.Thumbprint -eq $script:thumb }
            if (-not $found) {
                $secure = ConvertTo-SecureString -String $pfxPassword -Force -AsPlainText
                Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation 'Cert:\CurrentUser\My' -Password $secure | Out-Null
            }

            Connect-MgGraph `
                -ClientId              $script:clientId `
                -CertificateThumbprint $script:thumb `
                -TenantId              $script:tenantId `
                -NoWelcome
        }

        AfterAll {
            try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch { }
        }

        It "authenticates app-only as the Service Principal using the certificate" {
            $ctx = Get-MgContext
            $ctx                 | Should -Not -BeNullOrEmpty -Because "Connect-MgGraph must establish a context"
            $ctx.AuthType        | Should -Be 'AppOnly' -Because "certificate auth is app-only, no user, no secret"
            $ctx.ClientId        | Should -Be $script:clientId
        }

        It "has the certificate uploaded to the app registration and unexpired (per Terraform state)" {
            # Verified via Terraform state, not Get-MgApplication: reading /applications app-only
            # would require Application.Read.All, which this SP intentionally does not request.
            # The module uploads file(cert/cert.pem) as azuread_application_certificate, so the
            # uploaded certificate is the same local cert proven by the offline tests; here we
            # assert Terraform recorded that upload and that its expiry is in the future.
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
            $endOut   = Get-PeasterTerraformOutputRaw -RepoRoot $repoRoot -Name 'sp_with_certificate_cert_end_date'
            $endOut.Value | Should -Not -BeNullOrEmpty -Because "Terraform must record the uploaded certificate's end date. $($endOut.Error)"

            $endDate = [DateTimeOffset]::Parse($endOut.Value, [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
            $endDate | Should -BeGreaterThan ([DateTime]::UtcNow) -Because "the certificate Terraform uploaded to the app registration must not be expired"
        }
    }
}
