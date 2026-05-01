<#
.SYNOPSIS
    Stage 16 - Generate the self-signed certificate that Terraform uploads to the Service Principal.

.DESCRIPTION
    Creates a self-signed X.509 certificate (RSA-2048, SHA256) in CurrentUser\My, then writes
    three files into <repo-root>/cert/ :
        cert.pem            - public key, PEM-encoded.  Read by Terraform (azuread_application_certificate)
        cert.pfx            - public + private key, password-protected.  Read by auth.ps1
        cert.thumbprint.txt - thumbprint string.        Read by auth.ps1

    Workshop credential only.  In production: use Key Vault or a CA-issued certificate.

.PARAMETER PfxPassword
    Password protecting cert.pfx.  Defaults to 'Workshop123!' so the workshop runs unattended.

.PARAMETER Subject
    Certificate subject. Defaults to 'CN=tf-workshop-cert-sp'.

.EXAMPLE
    pwsh ./scripts/stage-16/init.ps1
#>
[CmdletBinding()]
param(
    [string] $PfxPassword = 'Workshop123!',
    [string] $Subject     = 'CN=tf-workshop-cert-sp'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$certDir  = Join-Path $repoRoot 'cert'
if (-not (Test-Path $certDir)) {
    New-Item -ItemType Directory -Path $certDir | Out-Null
}

Write-Host "Generating self-signed cert (Subject=$Subject) ..."
$cert = New-SelfSignedCertificate `
    -Subject           $Subject `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyExportPolicy   Exportable `
    -KeySpec           Signature `
    -KeyLength         2048 `
    -KeyAlgorithm      RSA `
    -HashAlgorithm     SHA256 `
    -NotAfter          (Get-Date).AddMonths(24)

$cerPath        = Join-Path $certDir 'cert.cer'
$pemPath        = Join-Path $certDir 'cert.pem'
$pfxPath        = Join-Path $certDir 'cert.pfx'
$thumbprintPath = Join-Path $certDir 'cert.thumbprint.txt'

Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

$bytes = [IO.File]::ReadAllBytes($cerPath)
$b64   = [Convert]::ToBase64String($bytes, 'InsertLineBreaks')
@"
-----BEGIN CERTIFICATE-----
$b64
-----END CERTIFICATE-----
"@ | Set-Content -Path $pemPath -Encoding ASCII

$secure = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secure | Out-Null

Set-Content -Path $thumbprintPath -Value $cert.Thumbprint -Encoding ASCII

Write-Host ''
Write-Host 'Certificate generated.'
Write-Host "  cert/cert.pem            (uploaded by Terraform)"
Write-Host "  cert/cert.pfx            (used by auth.ps1)"
Write-Host "  cert/cert.thumbprint.txt $($cert.Thumbprint)"
Write-Host ''
Write-Host 'Next: terraform apply'
