# External-00: Prerequisites (External ID / CIAM Tenant)

<!-- Banner: generate via doc/assets/image-prompts.md, save as banner.png in this folder, then uncomment:
![External-00 banner](banner.png)
-->

This is the External ID (CIAM) counterpart of [Stage 0](../stage-00/README.md). Stage 0 bootstraps a
Service Principal in your **home** Workforce tenant; this stage bootstraps a second, separate
Service Principal in your **External ID (CIAM) tenant** ("Tenant B" elsewhere in this repo) - the one
[`external_tenant/provider.tf`](../../external_tenant/provider.tf) authenticates as. Everything under
[`external_tenant/`](../../external_tenant/) (Stage 18's target-tenant provisioning, and
[External-01 Native Authentication](../external-01/README.MD)) runs against this Service Principal.

## Goals
- Create a Service Principal and client secret in your External ID tenant, dedicated to the
  `external_tenant/` Terraform root.
- Grant it **every** Microsoft Graph permission that any `external_tenant/` module needs, up front -
  unlike Stage 0's single `Application.ReadWrite.All`, this tenant's modules also manage user flows,
  conditional access, groups, and local users, so incremental consent would otherwise break mid-workshop.
- Retrieve and record the Application (client) ID, Client Secret, and Tenant ID for
  `external_tenant/provider.tf`.

## ⏱️ Estimated Time: 15-20 minutes

## Prerequisites Checklist
Before starting, please ensure you have the following:
- [ ] Access to an Entra **External ID (CIAM)** tenant with the **Global Administrator** role (or
      **Application Administrator** / **Cloud Application Administrator** if Global Admin isn't
      available). If you don't have an External ID tenant yet, create one first - see
      [Create an external tenant](https://learn.microsoft.com/entra/external-id/customers/how-to-create-external-tenant-portal).
- [ ] You've already completed [Stage 0](../stage-00/README.md) (VS Code, Terraform, Git). This stage
      only adds a second, external-tenant-scoped Service Principal - the tooling is shared.

## Steps to Create a Service Principal in the External ID Tenant

1. **Switch to the External ID tenant**
   - In the [Azure Portal](https://portal.azure.com) / [Entra admin center](https://entra.microsoft.com),
     use the directory switcher (top menu → **Settings** icon) to switch into your External ID tenant.
   - Navigate to Microsoft Entra ID → App registrations.

2. **Register a New Application**
   - Click "New registration".
   - Name: `Workshop-Terraform-SP-External`.
   - Supported account types: "Accounts in this organizational directory only".
   - Click "Register".

3. **Generate a Client Secret**
   - Navigate to "Certificates & secrets" → "New client secret".
   - Description: `workshop-secret-external`.
   - Expiry: 90 days (sufficient for the workshop).
   - Copy the secret value immediately and save it securely. You will not be able to view it later.

4. **Assign API Permissions**
   - Navigate to "API permissions" → "Add a permission" → "Microsoft Graph".
   - Add each permission below with the indicated **type** (Application vs. Delegated).
   - Click **"Grant admin consent for [Your External ID Tenant]"** once all are added.

## Required Microsoft Graph Permissions

Grant all of the following up front - each is used by a specific `external_tenant/` module, so the
whole workshop path (Stage 18 target-tenant provisioning + External-01 native auth) works without
returning to this screen:

| Permission | Type | Description | Admin consent | Used by |
|---|---|---|---|---|
| `Application.ReadWrite.All` | Application | Read and write all applications | Yes | Creating/updating app registrations (`modules/sso_app_native`, `modules/federation`, `modules/service_principal_rich`) |
| `AppRoleAssignment.ReadWrite.All` | Application | Manage app permission grants and app role assignments | Yes | Granting admin consent / app role assignments for target-tenant Service Principals (Stage 18) |
| `CustomAuthenticationExtension.ReadWrite.All` | Application | Read and write all custom authentication extensions | Yes | Managing the sign-up event flow and its attribute-collection hooks (`modules/user_flow`) |
| `Group.ReadWrite.All` | Application | Read and write all groups | Yes | Group-scoped policies/assignments in the external tenant |
| `Policy.Read.All` | Application | Read your organization's policies | Yes | Reading existing policies before updates (pairs with the `ReadWrite` policy permissions below) |
| `Policy.ReadWrite.ApplicationConfiguration` | Application | Read and write your organization's application configuration policies | Yes | Enabling `nativeAuthenticationApisEnabled` on the native-auth app (`modules/sso_app_native`) |
| `Policy.ReadWrite.ConditionalAccess` | Application | Read and write your organization's conditional access policies | Yes | Conditional Access policies in the external tenant |
| `Policy.ReadWrite.ExternalIdentities` | Application | Read and write your organization's external identities policy | Yes | Creating the sign-up user flow and linking apps to it (`modules/user_flow`, `this_user_flow_assignment` in `modules/sso_app_native`) |
| `User.Read` | Delegated | Sign in and read user profile | No | Default delegated permission added to every app registration |
| `User.ReadWrite.All` | Application | Read and write all users' full profiles | Yes | Creating the native-auth sign-in test user (`modules/user`, the `native_auth_test_user` module) |

5. **Document the Following Identifiers**
   - Application (client) ID: Retrieved from the application Overview blade.
   - Directory (tenant) ID: Retrieved from the application Overview blade (this is your External ID
     tenant's ID, different from the home tenant's).
   - Client Secret: Copied previously in step 3.

## Code Configuration

Update [`external_tenant/provider.tf`](../../external_tenant/provider.tf) - **both** provider blocks
use the same Service Principal:
```hcl
provider "azuread" {
  client_id     = "YOUR_CLIENT_ID_HERE"
  client_secret = "YOUR_CLIENT_SECRET_HERE"
  tenant_id     = "YOUR_TENANT_ID_HERE"
}

provider "msgraph" {
  client_id     = "YOUR_CLIENT_ID_HERE"
  client_secret = "YOUR_CLIENT_SECRET_HERE"
  tenant_id     = "YOUR_TENANT_ID_HERE"
}
```

Update [`external_tenant/terraform.tfvars`](../../external_tenant/terraform.tfvars) with your External
ID tenant's initial domain:
```hcl
tenant_default_domain = "yourtenant.onmicrosoft.com"
```

> Don't commit real secrets to source control - prefer `TF_VAR_`/environment-variable overrides or a
> local, gitignored `terraform.tfvars` for anything beyond a disposable workshop tenant.

## Verification
- [ ] `client_id`, `client_secret`, and `tenant_id` are populated in **both** provider blocks in
      `external_tenant/provider.tf`.
- [ ] All 10 permissions above show "Granted for `<your External ID tenant>`" under API permissions.
- [ ] `tenant_default_domain` is set in `external_tenant/terraform.tfvars`.
- [ ] `cd external_tenant && terraform init` succeeds.

## Troubleshooting
| Issue | Solution |
|-------|----------|
| "Insufficient privileges" error on `terraform apply` | One of the permissions above is missing or admin consent wasn't granted. Re-check the API permissions list. |
| "Invalid client secret" | The client secret may have expired or was pasted with trailing spaces. Regenerate it. |
| Cannot find App registrations / wrong tenant | You're still on the home tenant. Use the directory switcher to move into the External ID tenant before registering the app. |
| `AADSTS500011: The resource principal ... was not found in the tenant` | You're running Terraform against the home tenant's credentials by mistake - double-check `provider.tf`'s `tenant_id`. |

---

## Stage Completion Checklist
- [ ] I have verified access to my External ID (CIAM) tenant.
- [ ] I have successfully created the Service Principal within that tenant.
- [ ] I have securely documented its `client_id`, `client_secret`, and `tenant_id`.
- [ ] I have assigned and granted admin consent for all 10 API permissions listed above.
- [ ] I have correctly populated both provider blocks in `external_tenant/provider.tf`.
- [ ] I have set `tenant_default_domain` in `external_tenant/terraform.tfvars`.
- [ ] I have successfully run `terraform init` inside `external_tenant/` and observed positive output.
- [ ] I am ready to proceed to [External-01: Native Authentication](../external-01/README.MD).

> **Tip:** Make sure to check all of the boxes above before closing this issue and proceeding!

> **Report Issues:** Did you encounter a bug or need clarification? [Report the issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Stage 0: Prerequisites (home tenant)](../stage-00/README.md) | [Next → External-01: Native Authentication](../external-01/README.MD)
