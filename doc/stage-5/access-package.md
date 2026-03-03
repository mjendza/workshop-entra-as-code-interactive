# Stage 5: Access Package

> **Note:** Execution of this module necessitates an Entra ID Premium P2 or Entra ID Governance license suite.

## Goals
- Provision an Entra ID Access Package structured to formalize 'onboarding' mechanics routing into a centralized 'Workshop Developer' ecosystem.
- Facilitate the automated binding assigning any self-service validated users actively mapped against a specific core Entra ID Group backend.

## ⏱️ Estimated Time: 10 minutes

## Operational Prerequisites
- Your programmatic Service Principal must natively map to:
  - `EntitlementManagement.ReadWrite.All`
  - `Group.ReadWrite.All`
  - `Directory.ReadWrite.All`
- **Entra ID P2 license minimum** (Alternatively an active Governance SKU supporting automated lifecycle controls over Access Packages).

> ⚠️ **Note:** If operating inside an Entra standard or P1 tiered environment absent Governance metrics, entirely circumvent the interactions in Steps 5 & 6 gracefully.

## Documentation Reference
- [AzureAD Provider - Defining Access Packages natively](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/access_package)

## Implementation Layout
![Access Package Process Diagram](diagram.png)

Execute configuration deploying mapping directly traversing custom entitlements linking back into Entra structure mechanics.

```hcl
module "EntraDeveloper_Package" {
  source        = "./modules/access_package"
  business_name = "${var.deployment_unique_name}-EntraDeveloper"
}
```

## Verification Context
- Query and evaluate any instantiated Access Packages validating configuration actively reflecting within the user accessibility portal natively supported by Microsoft: [Evaluating Deployment Workspaces](https://myaccess.microsoft.com/@{{your-tenant-domain}}#/overview)

## Homework/Advanced Configuration
- Manually upgrade the deployed module incorporating an access workflow maintaining at least an arbitrary one-step approval layer mapped cleanly referencing an organizational admin/evaluator natively.
![Diagram Representing Multi-Stage Routing](diagram-what-next.png)

---

## Stage Completion Checklist
- [ ] I carefully comprehend the structural scope binding Entitlement controls within Entra interactions.
- [ ] I actively validated functional licensing mechanisms extending P2 controls locally (or manually circumvented sections gracefully).
- [ ] I applied relevant Access Package references binding variables against my `main.tf` logic successfully.
- [ ] I generated a clean structural `terraform plan` output effectively.
- [ ] I resolved infrastructure mappings fully relying on standard `terraform apply` operations confidently.
- [ ] I utilized the portal logic actively observing packages listed structurally resolving to users correctly.
- [ ] I effectively executed staging logic reliably tracking next phase maneuvers properly.

> **Tip:** Assure manual review checklist progression functions accordingly bridging Stage closure mechanics!

> **Report Issues:** Did you break Entitlement capabilities resolving Access workflows? [Establish formalized context here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 4](../stage-4/conditional-access.md) | [Next → Stage 6: PIM](../stage-6/pim.md)