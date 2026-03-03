# Stage 4: Conditional Access

> **Note:** Execution of this stage specifically requires an active Entra ID Premium P1 or P2 license. Skip this section if operating inside an Entra Free tenant.

## Goals
- Automate the assignment of a Conditional Access policy specifically bound to the `OidcDebugger` SSO application.
- Enforce rigid network segmentation: RESTRICT application ingress strictly scoped to IP ranges reflecting the active workshop environment.
- Formally scope authorization matching a predefined geographic country configuration block provided inside the underlying module.

## ⏱️ Estimated Time: 15 minutes

## Operational Prerequisites
- The backend Service Principal maintaining pipeline access must be properly scoped across `Policy.ReadWrite.ConditionalAccess` and `Policy.Read.All` Graph API permissions.
- **Entra ID P1 license minimum** (Conditional Access capabilities are not integrated into Entra ID Free instances).
- Entra ID "Security Defaults" must be forcefully disabled across the tenant hierarchy (Entra ID → Properties → Manage Security Defaults → Disabled).
- You must already have a functional OidcDebugger SSO App Registration active inside the tenant (Completed previously in Stage 1).

> ⚠️ **Note:** Referencing previous license prerequisites above—if operating on a free tier, safely bypass this stage entirely and resume moving forward to Stage 5.

## Documentation & References
- [Entra ID: Conditional Access Foundations](https://learn.microsoft.com/en-us/entra/identity/conditional-access/)
- [Block Access via Geographic Locations or IP Logic](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-block-by-location)

## Implementation & Code
We will be mapping the Conditional Access constraints against the active Service Principal, orchestrated via `./modules/conditional_access`. 
To dynamically inject an isolated testing IP block, map it statically using CIDR conventions such as `80.80.10.222/32`.
Provide the App Registration ID logic mapping directly back linking access toward the functional OidcDebugger.

```hcl
module "OidcDebugger_Policy" {
  source                      = "./modules/conditional_access"
  business_name               = "${var.deployment_unique_name}-EnableWorkshopForDEAndIP"
  included_applications       = ["PUT_YOUR_OIDCDEBUGGER_CLIENT_ID_HERE"]
  trusted_locations_ip_ranges = ["PUT_YOUR_IP_ADDRESS_HERE_OR_ANY_OTHER_IP_ADDRESS_TO_TEST_BLOCK"]
}
```

## Verification Steps
- Validate that simulated network traffic explicitly violating the Geographic constraint drops correctly. Map out a scenario evaluating blocking rules reflecting your arbitrary Conditional Access constraint lists.
- Navigate to the `OidcDebugger` configuration manually via a web browser—attempting authorization simulating external/blocked IP address profiles.
- Analyze your actively generated policy configuration mapping located within the Azure Portal's Conditional Access Overview. Evaluate telemetry effectively utilizing the feature suite corresponding to `Analyze Conditional Access Policy Impact`: [Reporting on Policy Impact Tracking](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-report-only).

![Example of Blocked Request Activity](blocked.png)

---

## Stage Completion Checklist
- [ ] I have read and assessed the architectural mechanisms surrounding Conditional Access.
- [ ] I maintain P1 Licensing metrics locally (otherwise skipping section).
- [ ] I have manually disabled overarching Tenant Security Default configurations overriding Custom Policies.
- [ ] I successfully mapped Conditional Access policies securely terminating into my static `main.tf` logic.
- [ ] I reliably declared a functional CIDR Network Range paired safely into the SSO Application payload struct.
- [ ] I generated a `terraform plan` simulating resource bindings.
- [ ] I actively pushed these mappings effectively utilizing `terraform apply`.
- [ ] I manually validated visual routing alongside constraints rendered inside the Azure Portal.
- [ ] I simulated and confirmed network blocking capabilities natively triggering.
- [ ] I am securely moving forward onto the next phase seamlessly.

> **Tip:** Make sure to cross off checkpoints properly prior to resolving Stage interactions!

> **Report Issues:** Are pipeline resources operating unexpectedly? [Formulate issue context actively here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 3](../stage-3/workload-federation.md) | [Next → Stage 5: Access Packages](../stage-5/access-package.md)