# Stage 0: Prerequisites

## Goals
- Create a Service Principal and client secret in the Azure Portal to be used in subsequent stages.
- Begin with minimal permissions and incrementally assign more throughout the workshop.
- Retrieve and verify your corresponding Entra ID administrative credentials (username and password).

## ⏱️ Estimated Time: 15-20 minutes

## Prerequisites Checklist
Before starting, please ensure you have the following:
- [ ] Access to an Entra ID tenant with the **Global Administrator** role.
- [ ] An **Entra ID P1 license** (required for Stage 4) or an **Entra ID P2 license** (required for Stages 5 and 6).
- [ ] Visual Studio Code (VS Code) installed.
- [ ] HashiCorp Terraform installed.
- [ ] Git installed (for cloning the repository).

## Tools

### Visual Studio Code
```powershell
winget install Microsoft.VisualStudioCode
```

### Necessary VS Code Extensions
- [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

### Terraform
```powershell
winget install HashiCorp.Terraform
```

### Git (if not yet installed)
```powershell
winget install Git.Git
```

### Verify Installations
```powershell
terraform --version
code --version
git --version
```

## Steps to Create a Service Principal in the Azure Portal

1. **Navigate to the Entra ID Portal**
   - Access the [Azure Portal](https://portal.azure.com) → Microsoft Entra ID → App registrations.

2. **Register a New Application**
   - Click "New registration".
   - Name: `Workshop-Terraform-SP`.
   - Supported account types: "Accounts in this organizational directory only".
   - Click "Register".

3. **Generate a Client Secret**
   - Navigate to "Certificates & secrets" → "New client secret".
   - Description: `workshop-secret`.
   - Expiry: 90 days (sufficient for the workshop).
   - Copy the secret value immediately and save it securely. You will not be able to view it later.

4. **Assign API Permissions**
   - Navigate to "API permissions" → "Add a permission".
   - Select "Microsoft Graph" → "Application permissions".
   - Add the following permission: `Application.ReadWrite.All`.
   - Click **"Grant admin consent for [Your Tenant]"**.

5. **Document the Following Identifiers**
   - Application (client) ID: Retrieved from the application Overview blade.
   - Directory (tenant) ID: Retrieved from the application Overview blade.
   - Client Secret: Copied previously in step 3.

6. **Disable Security Defaults (Required for Stage 4 Only)**
   - Navigate to Entra ID → Properties → Manage Security defaults.
   - Toggle to "Disabled".
   - Note: This must be disabled to create and manage Conditional Access policies.

## Code Configuration

Update the **Basic** section of the `main.tf` file. Define a unique prefix (such as your initials) as the value for `deployment_unique_name`.
```hcl
# Set deployment unique name
variable "deployment_unique_name" {
  default = "MJ"
}
```

Update the `provider.tf` file using the Service Principal credentials documented earlier:
```hcl
provider "azuread" {
  client_id     = "YOUR_CLIENT_ID_HERE"
  client_secret = "YOUR_CLIENT_SECRET_HERE"
  tenant_id     = "YOUR_TENANT_ID_HERE"
}
```

## Verification
- [ ] Ensure that `client_id` and `client_secret` are properly stored inside the `provider.tf` file.
- [ ] Confirm the `Application.ReadWrite.All` permission has been granted, including admin consent. For more details, review the [Provider Service Principal Configuration Guide](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/service_principal_configuration).
- [ ] Confirm each module has a distinct `deployment_unique_name` to avoid potential collisions (optional).
- [ ] Execute `terraform init` to ensure the provider dependencies download and initialize successfully.

## Troubleshooting
| Issue | Solution |
|-------|----------|
| "Insufficient privileges" error | Ensure admin consent has been properly granted for the assigned permissions. |
| "Invalid client secret" | The client secret may have expired or was pasted with trailing spaces. Please regenerate. |
| Cannot find App registrations | Confirm you are logged into the correct target Entra ID tenant. |

---

## Stage Completion Checklist
- [ ] I have verified access to an Entra ID tenant using the Global Administrator role.
- [ ] I have successfully installed VS Code, Terraform, and Git locally.
- [ ] I have successfully created the Service Principal within the Azure Portal.
- [ ] I have securely documented the `client_id`, `client_secret`, and `tenant_id`.
- [ ] I have assigned and granted admin consent for API permissions (`Application.ReadWrite.All`).
- [ ] I have correctly populated `provider.tf` with the appropriate credentials.
- [ ] I have successfully run `terraform init` and observed positive output.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Make sure to check all of the boxes above before closing this issue and proceeding!

> **Report Issues:** Did you encounter a bug or need clarification? [Report the issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [Next Stage → Stage 1: SSO Application](../stage-1/SSO-application.md)
