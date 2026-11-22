# Stage 21: Entra ID App Role PIM - Just-in-Time App Roles (Private Preview)

> 🧪 **PRIVATE PREVIEW:** Privileged Identity Management (PIM) for app roles is in private preview. Your tenant must be enrolled in the preview by Microsoft before the App Roles (Preview) blade appears in PIM. Features, UI labels, licensing and APIs can change before general availability. Don't use it in production, and use a sandbox/dev tenant for this stage.

## Rationale

In [Stage 15](../stage-15/README.md) you defined app roles and assigned a user to a role. That assignment is standing access: the `roles` claim is in every token until someone removes the assignment.

[Stage 6](../stage-06/README.md) solved the same problem for directory privileges with PIM for Groups. PIM for app roles brings the same just-in-time (JIT) model to application-defined roles:

| Assignment type | Meaning | Who manages it in this stage |
|-----------------|---------|------------------------------|
| Active (standing) | The `roles` claim is always issued. This is the classic `appRoleAssignment`. | Terraform (`azuread_app_role_assignment`), for a low-privilege `reader` role |
| Eligible | The user must activate the role in PIM (MFA, justification, ticket, approval, max duration) before the claim is issued. | Manual, in PIM → App Roles (Preview) |

The application still defines what each role allows. PIM only controls when a user holds it.

> ⚠️ **Why is part of this stage manual?** During the private preview there's no public, documented Microsoft Graph API and no `azuread`/`msgraph` Terraform resource for PIM app role eligibility schedules or app role PIM policies. Terraform owns the application, the roles, the eligible group and the standing assignment. You create the eligible assignment and the role settings in the portal. When Microsoft publishes the API, these steps are candidates for `msgraph_resource`, like Stage 7 and Stage 20.

## ⏱️ Estimated Time: 30 minutes

## Goals
- Provision an SPA application with three app roles (`reader`, `operator`, `admin`) and its Enterprise Application (Service Principal).
- Create an eligible group and a Terraform-managed standing `reader` assignment.
- Configure PIM role settings for `admin` (max activation duration, MFA, justification, optional approval).
- Create an eligible assignment of `admin` to the group in PIM.
- Activate the role as a user and verify the `roles` claim with OidcDebugger before and after activation.

## Documentation & References
- [Privileged Identity Management for app roles (preview)](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-app-roles)
- [Assign app roles in PIM (preview)](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/app-roles-assign)
- [Activate and deactivate app roles in PIM (preview)](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/app-roles-activate)
- [Configure app role settings in PIM (preview)](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/app-roles-settings)
- [Add app roles to your application and receive them in the token](https://learn.microsoft.com/en-us/entra/identity-platform/howto-add-app-roles-in-apps)
- [azuread_app_role_assignment (Terraform)](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment)

## Prerequisites
- Tenant enrolled in the PIM for app roles private preview. Check that ID Governance → Privileged Identity Management → App Roles (Preview) exists in the [Microsoft Entra admin center](https://entra.microsoft.com). If it doesn't, you can still run the Terraform part, but you can't complete the PIM steps.
- Licensing: Microsoft's preview docs list E7 licenses for PIM for app roles, and Microsoft Entra ID Governance for activation. Assigning an app role to a group also needs Entra ID P1 or higher.
- Completed [Stage 15](../stage-15/README.md) (you know how app roles and the `roles` claim work).
- New for this stage: add these Application permissions to your workshop Service Principal manually in the Entra admin center (App registrations → your SP → API permissions → Add a permission → Grant admin consent), the same way as in Stage 0:
  - `AppRoleAssignment.ReadWrite.All`, so Terraform can create the standing `reader` assignment.
  - `User.Read.All` (if you didn't add it in Stage 20), so Terraform can add users as group `members`.
  - `Group.ReadWrite.All` (from Stage 5).
- An admin account with Privileged Role Administrator, Identity Governance Administrator or Cloud Application Administrator, or ownership of the Service Principal. Any of these can manage app role assignments and settings in PIM.
- A test user (not your admin account) registered for MFA.

## Implementation & Code

### 1. Add the application, roles and eligible group to `main.tf`

The new module `./modules/pim_app_roles`:
- creates an SPA app registration (`https://oidcdebugger.com/debug`) with the app roles you pass in `app_role_values`,
- creates its Service Principal (Enterprise Application), which PIM lists under App Roles (Preview),
- creates the security group `TF.Workshop.<name>.Eligible` with your test user as a member,
- optionally creates a standing (permanent active) assignment of a low-privilege role (`standing_role_value`) to that group.

```hcl
#########################################################################
# Stage 21: Entra ID App Role PIM (Private Preview)
#########################################################################
module "AppRolePim" {
  source                     = "./modules/pim_app_roles"
  business_name              = "${var.deployment_unique_name}-AppRolePim"
  app_role_values            = ["reader", "operator", "admin"]
  spa_uri                    = ["https://oidcdebugger.com/debug", "https://tenant.factorlabs.pl/oidcdebugger/debug"]
  eligible_member_object_ids = ["PUT_TEST_USER_OBJECT_ID_HERE"]
  standing_role_value        = "reader"
}

output "app_role_pim_client_id" {
  value = module.AppRolePim.client_id
}

output "app_role_pim_service_principal_object_id" {
  value = module.AppRolePim.service_principal_object_id
}

output "app_role_pim_eligible_group_id" {
  value = module.AppRolePim.eligible_group_id
}

output "app_role_pim_app_role_ids" {
  value = module.AppRolePim.app_role_ids
}

output "app_role_pim_oidc_debugger_link" {
  value = module.AppRolePim.oidc_debugger_link
}
```

> `app_role_pim_oidc_debugger_link` is a ready-to-open link `https://tenant.factorlabs.pl/oidcdebugger?data=<base64 JSON>` with the authorization endpoint, client ID and scope (`openid profile`) already filled in.

> Don't add an `azuread_app_role_assignment` for `admin`. That creates standing access to the privileged role, and PIM can't take it away. Use `standing_role_value` only for low-privilege roles.

Then run:

```bash
terraform init
terraform plan
terraform apply
```

The plan should show the application with three `app_role` blocks, the Service Principal, the `Eligible` group, and one `azuread_app_role_assignment.standing`.

### 2. Configure PIM role settings for `admin` (manual - private preview)

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to ID Governance → Privileged Identity Management → App Roles (Preview).
3. Select `TF.Workshop.<name>-AppRolePim` (compare the object ID with `terraform output app_role_pim_service_principal_object_id`).
4. Under Manage, select Settings → `admin` → Edit.
5. On the Activation tab:
   - Activation maximum duration (hours): `1`
   - On activation, require: Azure MFA
   - Require justification on activation: ✅
   - Require approval to activate: optional. If you turn it on, pick your admin account as the approver.
6. On the Assignment tab, keep Allow permanent eligible assignment on for the workshop. In production, set an expiry.
7. Select Update and wait for Role setting update succeeded.

### 3. Create the eligible assignment (manual - private preview)

1. In the same application, under Manage, select Roles → Add assignments.
2. Select role: `admin`.
3. Select member(s): the group `TF.Workshop.<name>-AppRolePim.Eligible` (`terraform output app_role_pim_eligible_group_id`).
4. Next → Assignment type: Eligible → Permanently eligible → Assign.
5. Open Roles → `admin` → Eligible assignments and confirm the group is listed.

> With a group eligible assignment, each member activates the role for themselves. Activation doesn't give the role to the whole group.

## Verification Steps

### 4. Before activation: only the standing role

1. Open a private browser window with the prefilled workshop OIDC debugger link:
   ```powershell
   terraform output -raw app_role_pim_oidc_debugger_link
   ```
   Or go to [https://oidcdebugger.com](https://oidcdebugger.com) and set:
   - Authorize URI: `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/authorize`
   - Redirect URI: `https://oidcdebugger.com/debug`
   - Client ID: `terraform output -raw app_role_pim_client_id`
   - Scope: `openid profile`, Response type: `code`, PKCE: on
2. Sign in as the test user, then Exchange the code for tokens.
3. Decode the ID token. You should see only the standing role:

```json
{
  "roles": ["reader"]
}
```

### 5. Activate `admin` just-in-time

1. As the test user, sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) → ID Governance → Privileged Identity Management → App Roles (Preview) → select the application.
2. My roles → Eligible assignments → `admin` → Activate.
3. Complete MFA, set Duration (max 1 hour), enter a Reason and select Activate.
4. If you turned on approval, approve the request as the admin, then check My roles → Active assignments. The `admin` row shows State = Activated and an End time.

### 6. After activation: the privileged role in the token

Repeat step 4 in a new private window. The app needs a new token. The old one doesn't change.

```json
{
  "roles": ["reader", "admin"]
}
```

### 7. Deactivate and audit

1. My roles → Active assignments → `admin` → Deactivate. The activation must be at least 5 minutes old.
2. Get a new token again. Only `reader` is left.
3. As the admin, review the activation in PIM's audit history for the application ([View app role audit history](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/app-roles-audit)).

> ⚠️ Deactivation or expiry doesn't revoke tokens that were already issued. The `admin` claim stays valid until the token or the app session expires. Keep token lifetimes and app sessions short for privileged roles, and check roles on the server side.

## Troubleshooting

`App Roles (Preview) isn't shown in PIM.`
Your tenant isn't enrolled in the private preview, or you're missing a license. Contact your Microsoft account team. The Terraform part still works.

`The application isn't listed in App Roles (Preview).`
Search by the Service Principal object ID. The app must define at least one app role and must have a Service Principal in your tenant.

`terraform apply returns 403 on azuread_app_role_assignment.`
Add the `AppRoleAssignment.ReadWrite.All` Application permission to the workshop Service Principal and grant admin consent. Or set `standing_role_value = ""` to skip the standing assignment.

`terraform apply returns 403 on the group.`
Add `User.Read.All` (to set `members`) and `Group.ReadWrite.All`, then grant admin consent.

`The admin role isn't in the token after activation.`
You're reusing an old token or session. Start a new private window. Check that My roles → Active assignments shows Activated and that the request isn't still Pending approval.

`Deactivate role failed.`
The activation has to be active for at least five minutes before you can deactivate it. Wait and try again.

`terraform plan shows a diff on the app or the group after PIM activation.`
It shouldn't. PIM assignments aren't managed by this configuration. If you see a diff on `azuread_app_role_assignment`, someone changed the standing assignment in the portal.

---

## Stage Completion Checklist
- [ ] I understand the difference between active (standing) and eligible (just-in-time) app role assignments.
- [ ] I know that PIM for app roles is in private preview and my tenant is enrolled.
- [ ] I have added the `AppRolePim` module (with my test user ID) to my `main.tf` and run `terraform apply`.
- [ ] I have configured the PIM settings for `admin` (max duration, MFA, justification).
- [ ] I have created an eligible assignment of `admin` to the `Eligible` group.
- [ ] Before activation, the ID token contained only `reader`.
- [ ] After activation, a new ID token contained `reader` and `admin`.
- [ ] I have deactivated the role and reviewed the audit history.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 20](../stage-20/README.md) | [Next → Stage Cleanup](../stage-cleanup/README.md)
