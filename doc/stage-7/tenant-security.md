# Stage 7: Tenant Security Hardening

> ⚠️ **Important Warning:** Changes here modify the global Authorization Policy (a tenant-wide singleton). Modifications apply to ALL users simultaneously and may suffer a global propagation latency of realistically up to 60 minutes.

## Risk
These settings will restrict guest invitations and block standard users from creating app registrations and security groups. The recommendation is not to use production tenants for this workshop, as these changes can impact all users in the tenant.

## ⏱️ Estimated Time: 5-10 minutes

## Goals
- Restrict guest invitations.
- Block standard users from creating app registrations and security groups.

### What next?
Review the API Documentation for `authorization_policy` https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy?view=graph-rest-1.0#properties and apply additional restrictions as you see fit. For example, you could block users from signing up for email-based subscriptions or restrict access to the tenant for non-admin users.

## Pre-Operational Context
- **Permissions:** `Policy.ReadWrite.Authorization` on your Service Principal.
- **Provider:** Uses the `microsoft/msgraph` provider rather than `azuread`.

## Why `microsoft/msgraph` provider not `azuread`?
The `azuread` provider does not support the `authorization_policy` resource, which is required to manage tenant-wide security settings. The `microsoft/msgraph` provider allows us to configure these critical policies that govern guest access and user permissions at the tenant level.

With `microsoft/msgraph` we can manage all resources available in Microsoft Graph.

Why not pure Graph API calls? Or PowerShell? Using Terraform provides a consistent Infrastructure as Code experience across all stages of the workshop, enabling you to manage both tenant-level policies and application resources with the same tool and workflow. This approach also allows for better (**built-in**) state management, version control, and collaboration when working with infrastructure changes.

Why PATCH? The `authorization_policy` is a singleton resource in Microsoft Graph, meaning there is only one instance per tenant. To update its properties, we need to use the PATCH method to modify the existing policy rather than creating a new one.


## 
---

## Configuration

Add the following to your `main.tf`:

```hcl
module "tenant_security" {
  source = "./modules/tenant_security"

  deployment_env_name = var.deployment_env_name

  allow_invites_from = "adminsAndGuestInviters"
  guest_user_role_id = "10dae51f-b6af-4016-8d66-8c2a99b929b3"

  allowed_to_create_apps             = false
  allowed_to_create_security_groups  = false
}
```

Initialize (with upgrade), plan, and apply:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

> ⏳ **Note:** Changes can take up to 60 minutes to propagate. 

---

## Verification

### Microsoft Graph PowerShell

```powershell
Connect-MgGraph -Scopes "Policy.Read.All"
$policy = Get-MgPolicyAuthorizationPolicy

# Validate fields:
$policy.AllowInvitesFrom
$policy.GuestUserRoleId
$policy.DefaultUserRolePermissions | Format-List
```

### Manual Verification
1. Try to invite a guest as a non-admin: ❌ Denied
2. Access `entra.microsoft.com` as a non-admin: ❌ Restricted
3. Try creating an App Registration as a non-admin: ❌ Denied

### Maester
Link: https://github.com/maester365/maester

Install and run Maester to validate the following controls:

- Property: `allowInvitesFrom` → ID Reference: `EIDSCA.AP04`
- Property: `defaultUserRolePermissions.allowedToCreateApps` → ID Reference: `EIDSCA.AP10`
- Property: `defaultUserRolePermissions.allowedToCreateSecurityGroups` → ID Reference: `MT.1069`
- Property: `defaultUserRolePermissions.allowedToReadOtherUsers` → ID Reference: `EIDSCA.AP14`
- Property: `allowEmailVerifiedUsersToJoinOrganization` → ID Reference: `EIDSCA.AP06`
- Property: `allowUserConsentForRiskyApps` → ID Reference: `EIDSCA.AP09`
- Property: `allowedToSignUpEmailBasedSubscriptions` → ID Reference: `EIDSCA.AP05`
- Property: `defaultUserRolePermissions.allowedToCreateTenants` → ID Reference: `MT.1068`
- Property: `defaultUserRolePermissions.permissionGrantPoliciesAssigned` → ID Reference: `CISA.MS.AAD.5.2`

---

## Stage Completion Checklist
- [ ] Added `tenant_security` module to `main.tf`.
- [ ] Ran `terraform init -upgrade`, `plan`, and `apply`.
- [ ] Verified policies via PowerShell and/or Azure Portal.

## What Next?
Run all maester tests and implement a part of your tenant_security module and re-run maester to see the results. 

> **Tip:** Close this issue when completed!

> **Report Issues:** [Report it here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues)

---
**Navigation:** [← Previous: Stage 6](../stage-6/pim.md) | [Next → Stage 8: Entra Agent Identity](../stage-8/entra-agent.md)
