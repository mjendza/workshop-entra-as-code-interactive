# Stage 18: Multitenant Secret Monitoring

## Rationale

App Registration secrets and certificates expire silently. In single-tenant scenarios you can wire up a Defender for Cloud or a Logic App alert; in a **multi-tenant** setup — where you run apps across customer or partner tenants — there is no built-in cross-tenant view. The first signal of an expired credential is usually a broken SaaS integration.

This stage builds an **automated, no-secret cross-tenant credential inventory**. A single multi-tenant Entra app, trusted by GitHub Actions OIDC, fans out across every tenant ID in a comma-separated secret and emits a Markdown expiry table to the workflow run summary. Adding a new tenant to the watchlist is a one-line edit to a GitHub secret plus one `terraform apply` inside `external_tenant/`.

This is the "Observe" phase of the Musketeers cycle — read-only, scheduled, and federated to GitHub so no client secret ever lives in CI.

## Goals
- Automate the deployment of a **multi-tenant App Registration** with a **GitHub Actions OIDC Federated Identity Credential** using Terraform.
- Provision the same app's **Service Principal in each target tenant** with `Application.Read.All`.
- Simple run and test via http file to check if all works.
- Run a scheduled GitHub Actions workflow with one **matrix job per tenant** that builds an expired/expiring secrets table in the run summary.

## ⏱️ Estimated Time: 30 minutes

## Documentation & References
- [List applications — Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/application-list)
- [passwordCredential resource type](https://learn.microsoft.com/en-us/graph/api/resources/passwordcredential)
- [keyCredential resource type](https://learn.microsoft.com/en-us/graph/api/resources/keycredential)
- [Configure a federated identity credential — GitHub Actions](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp)
- [About security hardening with OpenID Connect (GitHub)](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [`azure/login@v2`](https://github.com/Azure/login)
- [Terraform: `azuread_application_federated_identity_credential`](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential)

## Architecture

```
┌─── GitHub repository (OWNER/REPO) ───────────────────────────────────┐
│                                                                       │
│  .github/workflows/stage-18-secret-monitor.yml                        │
│    schedule: weekly                                                    │
│    matrix: <tenant-1, tenant-2, ..., tenant-N> (from secret TENANT_IDS)│
│    permissions: id-token: write                                        │
│                                                                       │
│         │  GitHub OIDC token (audience = api://AzureADTokenExchange)  │
│         ▼                                                             │
└───────────────────────────────────────────────────────────────────────┘
          │
          │  azure/login@v2  (per-matrix-tenant)
          ▼
┌─── Tenant A (Home / Operator) ───────────────────────────────────────┐
│                                                                       │
│  Multi-Tenant App Registration  "TF.Workshop.<prefix>-SecretMonitor"  │
│    ├─ sign_in_audience = AzureADMultipleOrgs                          │
│    ├─ required: Microsoft Graph Application.Read.All                  │
│    └─ Federated Identity Credential                                   │
│         issuer:   https://token.actions.githubusercontent.com         │
│         subject:  repo:OWNER/REPO:ref:refs/heads/main                 │
│         audience: api://AzureADTokenExchange                          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
          │
          │  client_assertion = GitHub OIDC token
          │  token endpoint:  login.microsoftonline.com/<matrix tenant>
          ▼
┌─── Tenant B / C / D … (Targets) ─────────────────────────────────────┐
│                                                                       │
│  Service Principal (provisioned from the multi-tenant app's client_id)│
│    └─ Application.Read.All granted (admin consent)                    │
│                                                                       │
│  GET /applications  →  passwordCredentials + keyCredentials           │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
          │
          ▼
   $GITHUB_STEP_SUMMARY  (Markdown table per tenant in the workflow run)
```

## Prerequisites

- A "home" Entra tenant where you can create app registrations (Application Administrator or higher).
- One or more **target tenants** where you have a bootstrap Service Principal with `Application.ReadWrite.All` / **Cloud Application Administrator** so you can provision the SP and grant admin consent.
- A GitHub repository hosting this workflow. You will set its `OWNER/REPO` value on `var.github_repo`.
- `terraform` ≥ 1.6, `pwsh` ≥ 7.4 (only needed for local dry-runs and tests).

## Implementation & Code

### 1. Configure the home-tenant Terraform

Set `var.github_repo` in `variables.tf` (or via `-var` / `TF_VAR_github_repo`):

```hcl
variable "github_repo" {
  default = "your-org/your-repo"   # OWNER/REPO that runs the workflow
}
```

The Stage 18 module call in `main.tf` (already wired) reuses the existing `./modules/multitenant_workload_identity` module, drops the certificate path, and replaces the `User.Read.All` permission with **`Application.Read.All`** (`9a5d68dd-52b0-4cc2-bbf0-d5f35e9def5b`):

```hcl
module "SecretMonitor" {
  source            = "./modules/multitenant_workload_identity"
  business_name     = "${var.deployment_unique_name}-SecretMonitor"
  graph_permissions = ["9a5d68dd-52b0-4cc2-bbf0-d5f35e9def5b"] # Application.Read.All

  federated_identity_credentials = var.github_repo == "" ? [] : [
    {
      display_name = "github-actions-main"
      description  = "GitHub Actions OIDC from ${var.github_repo} on refs/heads/main"
      issuer       = "https://token.actions.githubusercontent.com"
      subject      = "repo:${var.github_repo}:ref:refs/heads/main"
      audiences    = ["api://AzureADTokenExchange"]
    }
  ]
}

output "multitenant_client_id" {
  value = module.SecretMonitor.client_id
}
```

Apply:

```powershell
terraform plan
terraform apply
terraform output -raw multitenant_client_id
```
#### 1. Optional, or phase one is to use demo token provider - use the issuer and subject values above as placeholders for the demo provider, which emits a token with the same claims but is not bound to GitHub's OIDC. This allows you to test the workflow and scripts before setting up the real GitHub OIDC trust.
```hcl
 issuer        = "https://vc.factorlabs.pl",
 subject       = "system:serviceaccount:default:play-with-workload-identity"
```

### 2. Provision the SP into each target tenant

Use the dedicated [`external_tenant/`](../../external_tenant/) Terraform root. Run it once per target tenant (separate workspace or state directory):

```powershell
cd external_tenant

# Edit provider.tf — replace the three Tenant-B placeholders
# Edit terraform.tfvars — set multitenant_client_id to the home-tenant output

terraform init
terraform plan
terraform apply
```

The default `var.graph_permissions = ["9a5d68dd-52b0-4cc2-bbf0-d5f35e9def5b"]` (Application.Read.All) matches the home-tenant request. See [`../../external_tenant/README.md`](../../external_tenant/README.md) for the full guide.

### 3. Configure GitHub repository secrets

| Secret name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | Output of `terraform output -raw multitenant_client_id` |
| `TENANT_IDS` | Comma-separated list of target tenant GUIDs, e.g. `c5863934-...,8a1b2c3d-...,...` |

No `AZURE_CLIENT_SECRET` is needed — federation handles auth.

### 4. The GitHub Actions workflow

The workflow at `.github/workflows/stage-18-secret-monitor.yml`:

- Triggers on `workflow_dispatch` (with an optional `warning_days` input) and on a weekly cron (`0 6 * * 1`).
- Requests an OIDC token (`permissions: id-token: write`).
- Splits `secrets.TENANT_IDS` on `,` and exposes the list as a matrix.
- For each tenant: `azure/login@v2` exchanges the OIDC token against that tenant's token endpoint, then `scripts/stage-18-secret-monitor/Get-TenantSecretInventory.ps1` walks every application's `passwordCredentials` and `keyCredentials`.
- `Format-SecretSummary.ps1` renders a Markdown table per tenant which is appended to `$GITHUB_STEP_SUMMARY`.

Trigger it manually with **Actions → Stage 18 - Multitenant Secret Monitor → Run workflow** or wait for the weekly run.

## Verification Steps

- In the **home tenant** portal → **App registrations → `TF.Workshop.<prefix>-SecretMonitor.MultiTenantApp`**:
  - **Authentication**: *Accounts in any organizational directory*.
  - **Certificates & secrets → Federated credentials**: one entry with **issuer** `https://token.actions.githubusercontent.com`, **subject** `repo:OWNER/REPO:ref:refs/heads/main`, **audience** `api://AzureADTokenExchange`.
  - **API permissions**: `Microsoft Graph → Application.Read.All` (Application).
- In each **target tenant** → **Enterprise applications**: the same app appears with **Application.Read.All** under **Admin consent**.
- In the repo → **Settings → Secrets and variables → Actions**: `AZURE_CLIENT_ID` and `TENANT_IDS` are set.
- In the repo → **Actions → Stage 18 - Multitenant Secret Monitor** → manually triggered run:
  - The `fan-out` job succeeds and produces a tenant array.
  - One `monitor` job runs per tenant in the matrix.
  - Each job's **Summary** tab shows a `## Tenant <guid>` heading followed by a `| App | Credential | Expires (UTC) | Days | Status |` table.
- (Optional, local) `Invoke-Pester ./scripts/stage-18-secret-monitor/Stage18.Tests.ps1 -Output Detailed` reports zero failures.

## Troubleshooting

**`AADSTS70021: No matching federated identity record found for presented assertion`**
The OIDC subject from GitHub does not match the FIC subject. Check the workflow is running on `refs/heads/main`. To monitor from other branches or environments, add more entries to `federated_identity_credentials` in `main.tf` (e.g. `repo:OWNER/REPO:environment:production`).

**`AADSTS500011: The resource principal named ... was not found in the tenant`**
The Service Principal has not been provisioned in this target tenant. Run `terraform apply` inside `external_tenant/` for that tenant, or use the portal **Grant admin consent** button on the Enterprise application.

**`Insufficient privileges to complete the operation` when listing applications**
Admin consent for `Application.Read.All` is missing in the target tenant. Re-apply `external_tenant/` or grant consent via the portal.

**`fan-out` job fails with "TENANT_IDS secret is empty"**
The repository (or environment) does not have a `TENANT_IDS` secret. Add it under **Settings → Secrets and variables → Actions**.

**`Get-AzAccessToken: The access token has expired`**
The default GitHub OIDC token is short-lived; long-running matrix jobs may need a refresh. Keep per-tenant work inside the same step so the token issued by `azure/login` covers the Graph call.

---

## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have set `var.github_repo` to my `OWNER/REPO`.
- [ ] I have run `terraform plan` and `terraform apply` from the repo root.
- [ ] I have captured `terraform output -raw multitenant_client_id`.
- [ ] I have run `terraform apply` inside `external_tenant/` for **every** tenant I want to monitor.
- [ ] I have set the repository secrets `AZURE_CLIENT_ID` and `TENANT_IDS`.
- [ ] I have triggered `.github/workflows/stage-18-secret-monitor.yml` and confirmed one matrix job ran per tenant.
- [ ] I have verified each job's **Summary** tab contains the per-tenant Markdown expiry table.
- [ ] I have (optionally) run `Invoke-Pester ./scripts/stage-18-secret-monitor/Stage18.Tests.ps1` locally.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 17:](../stage-17/README.md) | [Next → Stage Cleanup](../stage-cleanup/README.md)
