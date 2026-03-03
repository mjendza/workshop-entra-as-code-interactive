# Stage 6: Privileged Identity Management (PIM)

> **Note:** Execution of this module necessitates an Entra ID Premium P2 or Entra ID Governance license suite, alongside the active completion of Stage 5.

## Goals

### Storyline Context
1. Previously utilizing an Access Package, we assigned end users securely to the formal 'Workshop Developer' foundational group.
2. In this stage, utilizing Privileged Identity Management (PIM), we will actively enforce **Eligible Assignments** rather than static access. Authorized users will physically elevate themselves directly into a higher-privileged tier ('Workshop Administrators' group).
3. **Advanced Scenario (Homework):** Expand upon this deployment module to assign heavily sensitive control mechanisms, such as activating directly into Global Reader natively.
4. **Advanced Scenario (Homework):** Expand upon the module automating the requirement for at least one physical Approval check before an activation request processes fully.

## ⏱️ Estimated Time: 15 minutes

## Operational Prerequisites
- Your pipeline Service Principal must be mapped explicitly to the `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup` permission.
- **Entra ID P2 license minimum** (or an active Governance license supporting broader PIM controls).
- Successful deployment and active state maintained from Stage 5 (The target Access Package group must physically exist).

## Documentation Reference
- [AzureAD Provider - Defining PIM Group Eligibilities Natively](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/privileged_access_group_eligibility_schedule)

![Blueprint Diagram Illustrating PIM Bindings](diagram.png)

## Implementation & Code

Execute configuration scaling PIM bindings alongside your Entra structures:

```hcl
module "EntraDeveloper_PIM" {
  source               = "./modules/pim"
  business_name        = "${var.deployment_unique_name}-EntraDeveloper"
  group_id_eligibility = module.EntraDeveloper_Package.group_id
}
```

## Verification Steps
- Re-query your user’s designated Access portal evaluating the PIM assignments mapping dynamically: [MyAccess Portal Validation](https://myaccess.microsoft.com/@{{your-tenant-domain}}#/overview).
- Navigate physically inside the Azure Portal inspecting native PIM eligibility logic binding group assignments respectively: [Azure Portal PIM Identity Menu](https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/CommonMenuBlade/~/quickStart).
- Forcefully trigger an Activation evaluation evaluating whether the specified identity correctly scales to the appropriate Entra Group context.

An activation should render structurally resembling the prompt below:
![Screen Recording Sample of an Activation Process](activate.png)

---

## Stage Completion Checklist
- [ ] I comprehend the structural significance applying PIM controls above static assignments.
- [ ] I maintain an active P2 configuration scope (Or appropriately skipped execution).
- [ ] I successfully verified Stage 5 elements persist cleanly.
- [ ] I applied relevant PIM config logic integrating against `main.tf` seamlessly.
- [ ] I formulated an exact infrastructure calculation via `terraform plan`.
- [ ] I pushed these constraints resolving formally utilizing `terraform apply`.
- [ ] I queried Azure Portal views actively verifying Eligibility requirements resolving successfully.
- [ ] I dynamically performed an Activation request assessing functionality manually.
- [ ] I am fully prepared transitioning to the following deployment section.

> **Tip:** Complete the checkbox steps prior to declaring the issue closed.

> **Report Issues:** Missing documentation or struggling alongside a bug? [Please articulate an issue format here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 5](../stage-5/access-package.md) | [Next → Stage 7: Tenant Security](../stage-7/tenant-security.md)