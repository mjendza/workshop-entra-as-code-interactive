# Peaster (Pester) Tests

Standalone [Pester 5](https://pester.dev) tests that prove the **Stage 16**
certificate-based Service Principal and its certificate are valid. Unlike `tests/maester`,
these tests have **no Maester dependency** — plain Pester.

See [`doc/stage-16/README.md`](../../doc/stage-16/README.md) for the stage these tests cover.

## What is verified

**`Stage-16.SP-Cert.Tests.ps1`** — two layers:

| Tag       | Network? | Proves                                                                                 |
|-----------|----------|----------------------------------------------------------------------------------------|
| `Offline` | No       | The local artifacts from `scripts/stage-16/init.ps1` are valid: `cert/cert.pem` parses, `cert/cert.thumbprint.txt` matches it, RSA-2048 / SHA256, not expired, and `cert/cert.pfx` opens with the password and carries the private key. |
| `Live`    | Yes      | App-only `Connect-MgGraph` as the SP **using the certificate** (`AuthType = AppOnly`, no secret), and the certificate uploaded to the app registration matches the local thumbprint and is unexpired. |

**`Stage-19.TAP.Tests.ps1`** — uses the **same certificate SP** to issue a Temporary Access
Pass:

| Tag    | Network? | Proves                                                                                    |
|--------|----------|-------------------------------------------------------------------------------------------|
| `Live` | Yes      | The cert SP generates a TAP for `TAP_TARGET_USER` via `POST .../temporaryAccessPassMethods`, returning a usable pass with the requested lifetime. Requires `UserAuthenticationMethod.ReadWrite.All` on the SP. |

The `Live` contexts **auto-skip** unless the inputs below and the `Microsoft.Graph.Authentication`
module are available (the TAP test also needs `TAP_TARGET_USER`), so the offline checks always
run cleanly in CI.

## Prerequisites

- **Offline:** run `pwsh ./scripts/stage-16/init.ps1` from the repo root so the `cert/` files exist.
- **Live (additionally):**
  - `terraform apply` has created `module.Workload_CertSp` and uploaded the cert.
  - Admin consent granted for the SP's Graph permissions (see stage-16 README, step 4) — including
    `UserAuthenticationMethod.ReadWrite.All`, required by the TAP test.
  - `Microsoft.Graph.Authentication` PowerShell module installed.
  - For the TAP test: `TAP_TARGET_USER` set to an existing user, and TAP enabled tenant-wide
    with that user in scope (Stage 19 policy).

## Configuration

`PeasterConfig.ps1` is the single root file that declares every environment variable the tests
use. Each test dot-sources it and calls `Initialize-PeasterEnvironment`, which fills a default
**only when the variable is unset/empty** — so exporting a real value (e.g.
`$env:ARM_TENANT_ID = '<guid>'`) always overrides the default. Add new env vars by adding one
line to `$PeasterEnvDefaults`.

| Variable               | Default        | Purpose                                          |
|------------------------|----------------|--------------------------------------------------|
| `ARM_TENANT_ID`        | `''` (empty)   | Live tenant id (GUID); empty = skip live         |
| `AZURE_TENANT_ID`      | `''` (empty)   | Alternative tenant id source                     |
| `CERT_PFX_PASSWORD`    | `Workshop123!` | Pfx password (the `init.ps1` default)            |
| `TAP_TARGET_USER`      | `''` (empty)   | UPN/object id to issue a TAP for; empty = skip   |
| `TAP_LIFETIME_MINUTES` | `60`           | Requested TAP lifetime in minutes (10–43200)     |

## Live inputs

| Value      | Source                                                                                   |
|------------|------------------------------------------------------------------------------------------|
| `ClientId` | `terraform output -raw sp_with_certificate_client_id` (run automatically from repo root) |
| `TenantId` | `$env:ARM_TENANT_ID`, then `$env:AZURE_TENANT_ID`, else the current `Get-MgContext`      |
| Password   | `$env:CERT_PFX_PASSWORD` (defaulted by `PeasterConfig.ps1`)                              |

## Running

```powershell
# Offline only (CI-friendly, no network)
Invoke-Pester ./tests/peaster -ExcludeTagFilter Live -Output Detailed

# Full run (offline + live, including the TAP test)
$env:ARM_TENANT_ID   = '<your-tenant-guid>'
$env:TAP_TARGET_USER = 'user@contoso.com'
Invoke-Pester ./tests/peaster -Output Detailed
```
