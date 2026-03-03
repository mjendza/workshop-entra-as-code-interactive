# Stage 2: Service Principal

## Goals
- Automate the provisioning of a backend Service Principal using Terraform in Entra ID.
- Understand the manual component of application secret generation.

## ⏱️ Estimated Time: 10 minutes

## Documentation & References
- [OAuth 2.0 client credentials grant flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#get-a-token)

## Implementation & Code
We will utilize the local module `./modules/service_principal` to provision the base requirements.

> **Note:** Ensure you define a unique business name for each Service Principal to prevent naming collisions within a shared workshop environment.

Identify the Graph API Application Permission GUID associated with `Application.Read.All`. This can be found on Microsoft's Official API documentation site: [Graph API Permissions Reference](https://learn.microsoft.com/en-us/graph/permissions-reference).

Configure the resource via the HCL block below:

```hcl
module "Demo_ServicePrincipal" {
  source            = "./modules/service_principal"
  business_name     = "${var.deployment_unique_name}-Demo"
  graph_permissions = ["PASTE_YOUR_GRAPH_PERMISSION_GUID_HERE"]
}
```

## Verification
- Navigate to the Azure Portal Entra ID blade. Confirm that both the App Registration and its corresponding Enterprise Application have generated properly with the correct name/permissions.
- Identify whether the configured application permissions require Tenant Administrator Consent (they likely will). 
- Perform manual creation of a Client Secret spanning the new Application. Capture this context to edit variables within `test/sso.http`.
- Supply `test/sso.http` with the corresponding `clientId` and `tenantId` exposed inside the Azure Portal.
- Perform a manual baseline test: Issue an Access Token POST request, and subsequently utilize it as a Bearer Token for a Graph API HTTP call.

---

## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have added the respective Service Principal module into `main.tf`.
- [ ] I have successfully localized the exact Graph API permission GUID.
- [ ] I have run `terraform plan` without errors.
- [ ] I have run `terraform apply` confirming successful provisioning.
- [ ] I have verified the associated Service Principal exists inside Entra ID.
- [ ] I have manually requested and obtained a new client secret.
- [ ] I have tested utilizing the VS Code REST extension.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Do not forget to check off all items before resolving the issue!

> **Report Issues:** Run into a bug? Have a suggestion? [Raise an issue structurally here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 1](../stage-1/SSO-application.md) | [Next → Stage 3: Workload Federation](../stage-3/workload-federation.md)
