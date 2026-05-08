# Stage 17: CI/CD Pipelines — Automated Security Assessment & Testing

## Rationale

Throughout this workshop you have provisioned Service Principals (**Stage 2**), configured Workload Identity Federation (**Stage 3**), run Maester tests (**Stage 9**), and executed Zero Trust Assessments (**Stage 11**) — all manually from your workstation. In a real-world scenario these activities should run **automatically** on a schedule to test your Entra ID (Workforce or External), with results stored securely and never exposed publicly .

This stage brings everything together: you will use **this repository as a template**, set up your own copy, configure GitHub Actions environments and secrets, and run two automated pipelines:

- **Maester Pipeline** — runs Pester-based Maester tests against your Entra ID tenant.
- **ZTA Pipeline** — runs the Microsoft Zero Trust Assessment and generates HTML reports.

Both pipelines authenticate via **OIDC / Workload Identity Federation** (no stored client secrets) and upload their results to **private external storage** instead of GitHub Artifacts — because this repository (my repository) is public and artifacts on public repositories are accessible to anyone.

> **Note:** For this demo we use **Azure Blob Storage** with a shared access key as the simplest option. You are free to replace this with any storage backend that fits your environment — AWS S3, a private GitHub repository artefacts, or private repository as committed results, or any other private location. The important principle is: **never expose security assessment results via public storage**.

> **Note 2:** Blob storage is not part of the workshop, and is not provisioned by Terraform. You can use an existing storage account, or create a new one manually. The pipelines only require the storage account name, container name, and an access key to upload results.
---

## ⏱️ Estimated Time: 20 minutes

---

## Goals

- Use this repository as a **GitHub template** and create your own copy.
- Run `terraform apply` to provision the required Service Principals (from **Stage 9** and **Stage 11**).
- Configure a GitHub **environment** with the secrets required by the pipelines.
- Run both pipelines and verify the results are uploaded to private storage.

---

## Documentation & References

- [GitHub Template Repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository)
- [GitHub Actions Environments & Secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Azure Login with OIDC — GitHub Action](https://github.com/azure/login#login-with-openid-connect-oidc-recommended)
- [Maester — Official Documentation](https://maester.dev/)
- [Zero Trust Assessment — GitHub Repository](https://github.com/microsoft/zerotrustassessment)

---

## Step 1: Create Your Repository from the Template

1. Navigate to this repository on GitHub: https://github.com/mjendza/workshop-entra-as-code-interactive and via green button "COPY WORKSHOP" initiate your repository based on this template. Make sure to select your own GitHub account or organization, and provide a unique repository name (e.g., `my-entra-as-code`).

---

## Step 2: Provision Infrastructure with Terraform

Your `main.tf` should already include the Service Principal modules from previous stages. Here we need to combine with workload identity federation for OIDC-based authentication in the pipelines:

use terraform code and update with your details like OWNER, NAME_OF_YOUR_ENVIRONMENT, repository name (for example: my-entra-as-code)

```hcl
module "GitHubMaester_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "GitHubActionsMaester"
  enable_workload_identity = true
  subject_identifier       = "repo:OWNER/my-entra-as-code:environment:NAME_OF_YOUR_ENVIRONMENT"
  issuer_url               = "https://token.actions.githubusercontent.com"
  graph_permissions = [
    "dc377aa6-52d8-4e23-b271-2a7ae04cedf3",
    "2f51be20-0bb4-4fed-bf7b-db946066c75e",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "ae73097b-cb2a-4447-b064-5d80f6093921",
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e",
    "bb70e231-92dc-4729-aff5-697b3f04be95",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "37730810-e9ba-4e46-b07e-8ca78d182097",
    "4cdc2547-9148-4295-8d11-be0db1391d6b",
    "01e37dc9-c035-40bd-b438-b2879c4870a6",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "ee353f83-55ef-4b78-82da-555bfa2b4b95",
    "ff278e11-4a33-4d0c-83d2-d01dc58929a5",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "f8dcd971-5d83-4e1e-aa95-ef44611ad351",
    "5f0ffea2-f474-4cf2-9834-61cda2bcea5c",
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888",
    "dd98c7f5-2d42-42d3-a0e4-633161547251",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f",
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
  ]
}

module "GitHubMicrosoftEntraExporter_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "GitHubEntraExporter"
  enable_workload_identity = true
  subject_identifier       = "repo:mjendza/workshop-entra-as-code-interactive:environment:workshop-artefacts"
  issuer_url               = "https://token.actions.githubusercontent.com"
  graph_permissions = [
    "d07a8cc0-3d51-4b77-b3b0-32704d1f69fa",
    "2f3e6f8c-093b-4c57-a58b-ba5ce494a169",
    "b86848a7-d5b1-41eb-a9b4-54a4e6306e97",
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "e321f0bb-e7f7-481e-bb28-e3b0b32d4bd0",
    "1b0c317f-dd31-4305-9932-259a8b6e8099",
    "bb70e231-92dc-4729-aff5-697b3f04be95",
    "498476ce-e0fe-48b0-b801-37ba7e2685c6",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "edb419d6-7edc-42a3-9345-509bfdf5d87c",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "ff278e11-4a33-4d0c-83d2-d01dc58929a5",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888",
    "75bcfbce-a647-4fba-ad51-b63d73b210f4",
    "ab5b445e-8f10-45f4-9c79-dd3f8062cc4e",
    "df021288-bdef-4463-88db-98f22de89214",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f"
  ]
}

module "GitHubMicrosoftZTA_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "GitHubMicrosoftZTA"
  enable_workload_identity = true
  subject_identifier       = "repo:mjendza/workshop-entra-as-code-interactive:environment:workshop-artefacts"
  issuer_url               = "https://token.actions.githubusercontent.com"
  graph_permissions = [
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "cac88765-0581-4025-9725-5ebc13f729ee",
    "7a6ee1e7-141e-4cec-ae74-d9db155731ff",
    "dc377aa6-52d8-4e23-b271-2a7ae04cedf3",
    "2f51be20-0bb4-4fed-bf7b-db946066c75e",
    "58ca0d9a-1575-47e1-a3cb-007ef2e4583b",
    "06a5fe6d-c49d-46a7-b082-56b1b14103c7",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "ae73097b-cb2a-4447-b064-5d80f6093921",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e",
    "dc5007c0-2d7d-4c42-879c-2dab87571379",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "37730810-e9ba-4e46-b07e-8ca78d182097",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "4cdc2547-9148-4295-8d11-be0db1391d6b",
    "01e37dc9-c035-40bd-b438-b2879c4870a6",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f"
  ]
}
```

Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

After Terraform completes, note the **Client ID** and **Tenant ID** of the Service Principals — you will need them for the GitHub environment configuration.

> **Reminder:** Grant **Admin Consent** for the API permissions on each Service Principal in the Azure Portal (Entra ID → App Registrations → API Permissions → Grant admin consent).

---

## Step 3: Prepare External Storage

For this demo we use an **Azure Storage Account** with a private blob container. You can replace this with any private storage.

1. Create a Storage Account (or use an existing one).
2. Create a blob container (e.g., `workshop-reports`). Ensure the container access level is **Private**.
3. Copy the **Storage Account name**, **Container name**, and one of the **Access Keys** from the Azure Portal (Settings → Access keys).

> **Alternative storage options:** You are not required to use Azure Blob Storage. Any private storage that supports CLI-based upload will work — for example an S3 bucket, a private Git repository, or an SFTP server. Adjust the upload step in the pipeline accordingly.

---

## Step 4: Configure the GitHub Environment and Secrets

Both pipelines reference the `workshop-artefacts` GitHub environment. Create it in your repository:

1. Go to **Settings** → **Environments** → **New environment**.
2. Name it exactly: `workshop-artefacts`.
3. Add the following **secrets**:

| Secret Name | Value | Source |
|---|---|---|
| `AZURE_CLIENT_ID` | The Application (client) ID of the Service Principal | Entra ID → App Registration |
| `AZURE_TENANT_ID` | Your Entra ID Tenant ID | Entra ID → Overview |
| `AZURE_STORAGE_ACCOUNT_NAME` | Name of your Azure Storage Account | Azure Portal |
| `AZURE_STORAGE_CONTAINER_NAME` | Name of the blob container | Azure Portal |
| `AZURE_STORAGE_ACCOUNT_KEY` | Storage Account access key | Azure Portal → Access Keys |

> **Why secrets and not variables?** The storage account name and container name are stored as secrets (not environment variables) to ensure they are **masked in workflow logs**. Since this repository may be public, any value printed in logs would be visible to anyone.

---

## Step 5: Run the Pipelines

### Maester Pipeline

1. Go to **Actions** → **Run Maester Sandbox🔥** → **Run workflow**.
2. The pipeline will:
   - Authenticate to Azure via OIDC.
   - Install the Maester and Pester modules.
   - Run the smoke test (`tests/maester/Custom/Sandbox/Test-Smoke.Tests.ps1`).
   - Upload the HTML/JSON/XML results to your private blob container under `maester-reports/{run_number}-{date}/`.
3. Check the **workflow summary** for the test results table.

### ZTA Pipeline

1. Go to **Actions** → **Run Microsoft Zero Trust Assessment 🛡️** → **Run workflow**.
2. The pipeline will:
   - Authenticate to Azure via OIDC.
   - Install the ZeroTrustAssessment and Az PowerShell modules.
   - Run `Invoke-ZtAssessment` against your tenant.
   - Upload the HTML reports to your private blob container under `zta-reports/{run_number}-{date}/`.
3. Check the **workflow summary** for the export summary.

### Viewing Results

To view the uploaded reports, use the Azure Portal (Storage Browser) or the Azure CLI:

```bash
# List uploaded reports
az storage blob list \
  --container-name <YOUR_CONTAINER> \
  --account-name <YOUR_STORAGE_ACCOUNT> \
  --account-key <YOUR_KEY> \
  --prefix "zta-reports/" \
  --output table

# Download a specific report
az storage blob download-batch \
  --destination ./local-reports \
  --source <YOUR_CONTAINER> \
  --account-name <YOUR_STORAGE_ACCOUNT> \
  --account-key <YOUR_KEY> \
  --pattern "zta-reports/42-2026-05-07/*"
```

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (workflow_dispatch / schedule)           │
│                                                         │
│  ┌──────────────┐       ┌──────────────────────┐        │
│  │ Azure Login   │──────▶│ Maester / ZTA        │        │
│  │ (OIDC)       │       │ Assessment           │        │
│  └──────────────┘       └──────────┬───────────┘        │
│                                    │                    │
│                          ┌─────────▼──────────┐         │
│                          │ Upload to Private   │         │
│                          │ Storage (Blob/S3/…) │         │
│                          └────────────────────┘         │
│                                                         │
│  ❌ NOT using actions/upload-artifact                    │
│     (public repos expose artifacts to everyone)          │
└─────────────────────────────────────────────────────────┘
```

---

## Stage Completion Checklist

- [ ] I have read and comprehended this stage.
- [ ] I have created a repository from this template.
- [ ] I have run `terraform apply` to provision the Maester and ZTA Service Principals.
- [ ] I have granted admin consent for the Service Principals' API permissions.
- [ ] I have created a private storage location for pipeline results (e.g., Azure Blob container).
- [ ] I have created the `workshop-artefacts` GitHub environment with all required secrets.
- [ ] I have successfully run the **Maester pipeline** and verified results were uploaded.
- [ ] I have successfully run the **ZTA pipeline** and verified results were uploaded.
- [ ] I understand why `actions/upload-artifact` is not suitable for security reports on public repositories and this is here only for DEMO purposes.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or do you have a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code/issues).

---

**Navigation:** [← Previous: Stage 16: Certificate Auth](../stage-16/certificate-auth.md) | [Next → Stage Cleanup](../stage-cleanup/end.md)
