# Stage 101: Verified ID — Issue a Verifiable Credential Contract

## Rationale

Microsoft Entra Verified ID lets a tenant act as an **issuer** of W3C Verifiable Credentials: portable, cryptographically signed claims that users own in their own wallet (Microsoft Authenticator) rather than re-authenticating through your IdP every time. The tenant is represented by an **authority** — a DID (Decentralized Identifier) backed by signing keys in Azure Key Vault — and each kind of credential it issues is described by a **contract**: a JSON definition of the rules (where the input claims come from) and the displays (card colors, title, claim labels).

This stage extends the certificate-bound Service Principal pattern from Stage 16 to a different audience — the Verified ID Admin API (`6a8b4b39-c021-437c-b060-5a14a3fd65f3`) — and uses the `mjendza/verifiedid` Terraform provider to create a credential contract under your tenant's authority. 



## ⏱️ Estimated Time: 20 minutes

## Goals
- Provision a certificate-bound Service Principal scoped to the Verified ID Admin API.
- Discover your tenant's Verified ID authority via Terraform (or PowerShell as a fallback).
- Issue a new Verifiable Credential contract through the `mjendza/verifiedid` provider.

## Documentation & References
- Entra Verified ID enabled in your tenant based on the instruction: https://learn.microsoft.com/en-us/entra/verified-id/verifiable-credentials-configure-tenant-quick
- [Microsoft Entra Verified ID — Introduction](https://learn.microsoft.com/en-us/entra/verified-id/decentralized-identifier-overview)
- [Verifiable credentials Admin API](https://learn.microsoft.com/en-us/entra/verified-id/admin-api)
- [Onboard your tenant to Verified ID](https://learn.microsoft.com/en-us/entra/verified-id/verifiable-credentials-configure-tenant)
- [Credential design (rules / display)](https://learn.microsoft.com/en-us/entra/verified-id/credential-design)
- [`mjendza/terraform-provider-verifiedid` (GitHub)](https://github.com/mjendza/terraform-provider-verifiedid)

## Implementation & Code

We will reuse `./modules/service_principal_rich` (Stage 16) to provision a cert-bound SP, then wire `./modules/verified_id` to create the contract. The provider is `mjendza/verifiedid` — a thin wrapper over the Verified ID Admin API.

> **Note:** The cert files live at the repo root (`<repo-root>/cert/`) so both Stage 16 and Stage 101 can share them. Pick a unique `deployment_unique_name` in `main.tf` to keep contract names tenant-unique.

### 1. Generate the certificate

```powershell
pwsh ./scripts/stage-16/init.ps1
```

This writes:
- `cert/cert.pem` — public key (Terraform uploads this to the SP)
- `cert/cert.pfx` — public + private key, password `Workshop123!` (used by `auth.ps1` and the `verifiedid` provider)
- `cert/cert.thumbprint.txt` — thumbprint, read by `auth.ps1`

If you already ran `scripts/stage-16/init.ps1`, the same cert is reused — skip this step.

### 2. Add the Verified ID Service Principal to `main.tf` in root folder (will be used with dedicated stack in folder `verified_id`)
use https://permissions.factorlabs.pl and 'MS Other Apps Permissions' filter to find all expected permissions for the Verified ID Admin API:
- `VerifiableCredential.Authority.ReadWrite`
- `VerifiableCredential.Contract.ReadWrite`
- `VerifiableCredential.Credential.Search`
- `VerifiableCredential.Credential.Revoke`



```hcl
#########################################################################
# Stage 101: Verified ID Service Principal (cert-based)
#########################################################################
module "VerifiedId_SpVc" {
  source                      = "./modules/service_principal_rich"
  business_name               = "${var.deployment_unique_name}-SpVerifiedId"
  graph_permissions           = ["df021288-bdef-4463-88db-98f22de89214"] 
  permissions = [
    { resource_app_id = "6a8b4b39-c021-437c-b060-5a14a3fd65f3" # Verified ID Admin API
      permissions = [ PUT_HERE_ALL_REQUIRED_PERMISSIONS_LISTED_ABOVE ]
    }
  ]
}

output "cert_sp_vc_client_id" {
  value = module.VerifiedId_SpVc.client_id
}
```

### 3. First apply + grant admin consent and generate secret

```bash
terraform plan
terraform apply
```

This creates the App Registration, Service Principal, and uploads the certificate. App-only permissions cannot be consented interactively, so:

Portal → **Entra ID → App registrations → `TF.Workshop.<prefix>-SpVerifiedId.ServicePrincipal` → API permissions** → **Grant admin consent fortenant**.

### 4. Onboard the tenant to Verified ID (one-time per tenant - manual step in the portal)

If your tenant has never issued a Verified ID credential, you need to bootstrap an authority. Portal → **Microsoft Entra → Verified ID → Setup**, then follow the wizard (it provisions the Key Vault, creates the DID, and sets up the first authority).

> Without this step, the `data` block in step 6 returns an empty `value` array and `terraform apply` fails on `value[0].id`.

### 5. Verify with `auth.ps1`

```powershell
$clientId = terraform output -raw cert_sp_vc_client_id
pwsh ./scripts/stage-101-vc/auth.ps1 -ClientId $clientId -TenantId YOUR_TENANT_ID
```

Expected output: at least one authority with `id`, `name`, `did`, `didModel`, and `keyVaultMetadata` printed. This proves cert auth + Admin API access work.

Copy the authority `id` GUID from the output if you plan to use **Option B** below.

### 6. Reference the authority and create the credential contract via Terraform and dedicated stack in `verified_id` folder

The `mjendza/verifiedid` provider exposes a generic `data "verifiedid_resource"` that performs a GET against any Admin API path. We use it to list authorities and pick the first one — pure IaC, no copy/paste.

Add to the top of `main.tf` if not already present:

```hcl
terraform {
  required_providers {
    verifiedid = {
      source  = "mjendza/verifiedid"
      version = ">=  0.1.14-beta"
    }
  }
}
```

Append the Stage 101 block:

```hcl
data "verifiedid_resource" "authorities" {
  url = "verifiableCredentials/authorities"
  response_export_values = {
    value = "value"
  }
}

module "Demo_Credential_Contract" {
  source       = "./modules/verified_id"
  authority_id = data.verifiedid_resource.authorities.output.value[0].id

  credential_name = "${var.deployment_unique_name}WorkshopCredential"
  credential_type = "${var.deployment_unique_name}WorkshopCredential"
  card_title      = "${var.deployment_unique_name} Workshop Credential"
}

output "vc_authority_id" {
  value = data.verifiedid_resource.authorities.output.value[0].id
}
```

```powershell
terraform apply
```

Rename the module from "Demo_Credential_Contract" to "Demo_Credential_Contract_V2" run terraform init and terraform plan again. You should see that the old contract will be deleted and a new one with the same properties will be created. In the VerifiedID Terraform Provided I added the logic to prevent deletion of existing contract - there is no HTTP delete method, contract can be only deactivated. So when you run terraform apply after renaming the module, you should see that the existing contract will be deactivated and a new one will be created. You can verify that in the portal by checking the status of the contract - it should be "Inactive" for the old one and "Active" for the new one.


## Verification Steps
- Portal → **Verified ID → Credentials**: a new contract `<prefix>-WorkshopCredential` appears under the authority.
- Re-running `auth.ps1` shows the new contract under the authority's contracts list (uncomment the contracts loop near the bottom of `auth.ps1` if you want it printed).
- The contract's `manifestUrl` returns valid JSON when fetched.
- (Optional) use my https://github.com/mjendza/workshop-verified-id workshop to test/use the new credential.


## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have inserted the `VerifiedId_SpVc` module config into my `main.tf` file.
- [ ] I have successfully run `terraform apply` and granted admin consent for the four Verified ID app roles.
- [ ] I have onboarded my tenant to Verified ID in the portal.
- [ ] I have run `./scripts/stage-101-vc/auth.ps1` and seen at least one authority + DID printed.
- [ ] I have added the Stage 101 block (data + module + output) and run `terraform apply` successfully.
- [ ] I have verified the new credential contract appears in the Verified ID portal.
- [ ] I renamed the module and re-ran `terraform apply` to verify that contract replacement logic works as expected.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 18](../stage-18/README.md) | [Next → Stage Cleanup](../stage-cleanup/README.md)
