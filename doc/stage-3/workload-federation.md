# Stage 3: Workload Federation

## Goals
- Provision a Service Principal in Entra ID using Terraform with Workload Identity Federation actively enabled.
- Demonstrate authentication without requiring explicit secret generation or management.
- Utilize the token issuer configuration targeting `https://vc.factorlabs.pl` for cross-system token exchange.

## ⏱️ Estimated Time: 15 minutes

## Documentation & References
- [Overview of Workload Identities in Entra ID](https://learn.microsoft.com/en-us/entra/workload-id/workload-identities-overview)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Exchanging a Federated Credential for an Access Token](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#third-case-access-token-request-with-a-federated-credential)

![Diagram illustrating Workload Federation](diagram.png)

## Implementation & Code
To instantiate the Service Principal, we will utilize the localized module located within `./modules/service_principal_workload_identity`.

> **Note:** Assign a distinct business prefix for each Service Principal to circumvent naming collisions inside the sandbox environment.

Refer to the official Graph API Permissions page to locate the `Application.Read.All` GUID identifier: [Graph API Permissions Reference](https://learn.microsoft.com/en-us/graph/permissions-reference).

Utilize the HCL module block below:

```hcl
module "Demo_WorkloadIdentity_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "${var.deployment_unique_name}-WorkloadIdentity"
  enable_workload_identity = true
  subject_identifier       = "system:serviceaccount:default:play-with-workload-identity"
  issuer_url               = "https://vc.factorlabs.pl"
  graph_permissions = [
    # Application.Read.All
    "PASTE_YOUR_GRAPH_PERMISSION_GUID_HERE"
  ]
}
```

The returned partner token should structure similarly to the payload below:
![Federated Partner Token](federated-token.png)

You can effectively analyze any generated Token Claims using [jwt.ms](https://jwt.ms).

## Verification Steps
- Inspect the corresponding App Registration and Enterprise Application blades in Entra ID. Validate naming conventions alongside the configured Application permissions.
- Provide Global Administrator consent across the assigned Graph scopes via the portal.
- Perform a manual baseline validation: Request an external token corresponding to the federated 'partner' system payload format, then submit an 'exchange' grant resolving via Entra ID against federated credentials.

## Troubleshooting
- Validate whether the implemented graph permission conforms strictly to a recognized GUID. Confirm the application scope operates via Application/AppRoles logic instead of Delegated scopes.
- Has Tenant Admin Consent fully finalized? Make sure `Grant admin consent` was formally reviewed if you are seeing arbitrary authentication denials.

---

## Stage Completion Checklist
- [ ] I have analyzed and understood this module's scope.
- [ ] I have functionally added the Workload Identity Federation configuration to `main.tf`.
- [ ] I have accurately localized and supplied both the Issuer URL and matching Subject Identifier.
- [ ] I have run `terraform plan` without surfacing warnings.
- [ ] I have securely run `terraform apply`.
- [ ] I have manually validated Workload Identity Federation inside of Entra ID.
- [ ] I successfully verified token exchange mapping leveraging my third-party federated credential payload.
- [ ] I am ready to jump to the next stage.

> **Tip:** Complete the checkbox steps prior to declaring the issue closed.

> **Report Issues:** Missing documentation or struggling alongside a bug? [Please articulate an issue format here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 2](../stage-2/service-principal.md) | [Next → Stage 4: Conditional Access](../stage-4/conditional-access.md)