# Stage 1: SSO Application

## Rationale
Enabling Single Sign-On (SSO) is one of the core foundational features associated with using Entra ID as an Identity Provider (IdP). For the sake of simplification and ease during this workshop, we will be utilizing the OIDC Debugger:
- It removes the requirement to locally run, compile, or host an application to act as a Relying Party.
- It serves as a perfect testing plane for your Terraform configurations.
- It is a free, openly accessible tool (OIDC Debugger).
- It supports advanced validation scenarios such as Proof Key for Code Exchange (PKCE).

## ⏱️ Estimated Time: 10-15 minutes

## Goals
- Automate the deployment of an App Registration configured for SSO with the OIDC Debugger using Terraform.
- Manually generate a client secret for the application to observe authentication flows.

## Documentation & References
- [OIDC Debugger Application](https://oidcdebugger.com/)
- [Microsoft Entra ID: Get a token](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#get-a-token)

## Implementation & Code
To create the Service Principal for the OIDC Debugger, we will leverage the local module located at `./modules/sso_app`. It will automatically configure a standard Confidential Client.

> **Note:** Please designate a unique business name prefix for each application. This prevents naming conflicts when operating in a shared sandbox workshop tenant.

Open [https://oidcdebugger.com/](https://oidcdebugger.com/) and identify the "Redirect URI" presented on the portal. Update the `web_uri` within your implementation below.

```hcl
module "OidcDebugger_SSO" {
  source        = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-OidcDebuggerSSO"
  web_uri       = ["PUT_YOUR_WEB_URI_HERE"]
}
```

Run `terraform init` to download your provider requirements and initialize modules.
```bash
terraform init
```
The output should resemble:

![](init.png)

Run `terraform plan` to view an execution plan and observe exactly what changes will take place.
```bash
terraform plan
```
The result should appear similar to:

![](plan.png)

Run `terraform apply` to instruct Terraform to deploy the configured resources.
```bash
terraform apply
```
The applying phase output should resemble:

![Terraform Apply](apply.png)

## Verification Steps
![Verification Diagram](diagram.png)

- Two Entra ID resources should now be provisioned in your tenant: an **App Registration** and an **Enterprise Application** (Service Principal).
- Your directory should now reflect a populated `terraform.tfstate` tracking file (feel free to inspect the JSON file).
- The `.terraform` directory is dynamically created containing modules and providers.
- Use the overarching diagram as a reference to run a test on OIDC Debugger. Use the provided VS Code REST client block located in `test/sso.http`.

## Troubleshooting
Getting initialization errors or a provider block discrepancy (like the image below)?

Make sure to always run `terraform init` to prepare the workspace when working from a new folder or upon first launch.

![terraform init](run-init.png)

---

## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have inserted the OidcDebugger module config into my `main.tf` file.
- [ ] I have successfully run `terraform init`.
- [ ] I have successfully run `terraform plan`.
- [ ] I have successfully run `terraform apply`.
- [ ] I have verified the deployment of the respective App Registration within Entra ID.
- [ ] I have verified the respective Enterprise Application generated within Entra ID.
- [ ] I have tested authentication successfully against the OIDC Debugger.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 0](../stage-0/prerequisits.md) | [Next → Stage 2: Service Principal](../stage-2/service-principal.md)