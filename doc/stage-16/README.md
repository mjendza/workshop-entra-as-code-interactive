# Stage 16: Certificate-Based Service Principal Authentication

## Rationale

Every workshop stage so far has authenticated to Microsoft Graph using **client secrets**: long-lived strings pasted into PowerShell variables (`scripts/entra-exporter/export.ps1`) or generated on demand (`scripts/entra-agent-powershell/generate-secret.ps1`). Secrets are convenient but they are also the most common source of leaked credentials. They have to be rotated manually, end up in clipboards, terminal histories, and config files, and there is no cryptographic proof that the caller possesses the key.

Microsoft Entra recommends **certificate credentials** for confidential clients: the Service Principal stores only the public key, and every token request is signed with the private key that never leaves your machine. In this stage we generate a self-signed certificate locally, upload its public part to a Service Principal via Terraform, and then acquire an **app-only** Microsoft Graph token using the certificate — no client secret involved.

> Self-signed certificates are appropriate for a workshop. In production, use a CA-issued certificate or store the key material in Azure Key Vault.

## ⏱️ Estimated Time: 15 minutes

## Goals
- Generate a self-signed X.509 certificate locally with `init.ps1`.
- Automate uploading the public certificate to a Service Principal using the `service_principal_rich` module.
- Acquire an app-only Microsoft Graph token using the certificate via `auth.ps1` — without any client secret.

## Documentation & References
- [Microsoft Entra: Authentication flows and application scenarios — certificate credentials](https://learn.microsoft.com/en-us/entra/identity-platform/authentication-flows-app-scenarios)
- [Microsoft Entra: Get a token via the client credentials flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-credentials-grant-flow)
- [Connect-MgGraph — App-only with a certificate](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands)
- [Terraform: `azuread_application_certificate`](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_certificate)

## Implementation & Code

We will use `./modules/service_principal_rich`, which now supports certificate credentials via the same pattern proven by `sso_app_rich`. Terraform reads the public certificate from `<repo-root>/cert/cert.pem`; the matching private key stays in `cert/cert.pfx` for the auth script. Both files come from `scripts/stage-16/init.ps1`.

> **Note:** Pick a unique business name prefix for your tenant. The cert files live at the repo root because `sso_app_rich` and `service_principal_rich` both expect `${path.module}/../../cert/`.

### 1. Generate the certificate

```powershell
pwsh ./scripts/stage-16/init.ps1
```

This writes:
- `cert/cert.pem` — public key (Terraform uploads this)
- `cert/cert.pfx` — public + private key, password `Workshop123!` (used by `auth.ps1`)
- `cert/cert.thumbprint.txt` — thumbprint, read by `auth.ps1`

### 2. Add the stage-16 module to your `main.tf`

```hcl
#########################################################################
# Stage 16: Certificate-Based SP Authentication
#########################################################################
module "Workload_CertSp" {
  source                      = "./modules/service_principal_rich"
  business_name               = "${var.deployment_unique_name}-SpWithCertificate"
  graph_permissions           = ["df021288-bdef-4463-88db-98f22de89214"]
  use_certificate             = true
  certificate_file            = "cert.pem"
  certificate_validity_months = 12
}

output "sp_with_certificate_client_id" {
  value = module.Workload_CertSp.client_id
}
```

### 3. Apply

```bash
terraform plan
terraform apply
```

You should see four new resources: `azuread_application`, `azuread_service_principal`, `time_static.cert_created`, and `azuread_application_certificate`.

### 4. Grant admin consent (manual)

Navigate to **Entra ID → App registrations → `TF.Workshop.<your-prefix>-CertSp.ServicePrincipal` → API permissions** and click **Grant admin consent**. App-only permissions cannot be consented to interactively, so this step is manual — the same convention used in Stages 9–11.

### 5. Authenticate with the certificate

```powershell
$clientId = terraform output -raw sp_with_certificate_client_id
pwsh ./scripts/stage-16/auth.ps1 -ClientId $clientId -TenantId YOUR_TENANT_ID
```

Expected output:

```
Connected.
  AuthType : AppOnly
  AppName  : TF.Workshop.<prefix>-SpWithCertificate.ServicePrincipal
  TenantId : <guid>
  Scopes   : User.Read.All
```

## Verification Steps

- `cert/cert.pem`, `cert/cert.pfx`, and `cert/cert.thumbprint.txt` exist locally; `cert.pfx` and `cert.thumbprint.txt` are git-ignored.
- In Entra Portal → **App registrations → `TF.Workshop.<prefix>-SpWithCertificate.ServicePrincipal` → Certificates & secrets → Certificates**: the uploaded cert appears with the same thumbprint as `cert/cert.thumbprint.txt` and an expiry roughly 12 months from now.
- `auth.ps1` prints `AuthType: AppOnly` and `Get-MgOrganization` returns your tenant's display name.
- No client secret was created or used at any point in this stage.

## Troubleshooting

**`file: cert/cert.pem not found` during `terraform apply`**
The cert hasn't been generated yet. Run `pwsh ./scripts/stage-16/init.ps1` from the repo root, then re-apply.

**`AADSTS700027: Client assertion failed signature validation`**
The certificate uploaded to the SP doesn't match the one signing the token. This usually means `init.ps1` was run again after `terraform apply`. Run `terraform taint 'module.Workload_CertSp.time_static.cert_created[0]'` and `terraform apply` to re-anchor and re-upload, or re-run `init.ps1` followed by `terraform apply`.

**`AADSTS65001: The user or administrator has not consented`**
Admin consent for `User.Read.All` is missing. Grant it from the API permissions blade as described in step 4 above.

---

## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have run `./scripts/stage-16/init.ps1` and verified `cert/cert.pem` was created.
- [ ] I have inserted the `Workload_CertSp` module config into my `main.tf` file.
- [ ] I have successfully run `terraform apply`.
- [ ] I have verified the certificate appears in the App Registration's Certificates blade with the matching thumbprint.
- [ ] I have granted admin consent for the SP's Graph permissions.
- [ ] I have run `./scripts/stage-16/auth.ps1` and seen `AuthType: AppOnly` plus a successful `Get-MgUser` Count response (like `Total users in tenant: 20`).
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 15](../stage-15/README.md) | [Next → Stage 17: CI/CD Pipelines](../stage-17/README.md)
