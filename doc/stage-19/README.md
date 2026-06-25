# Stage 17: Temporary Access Pass (TAP) Policy

## Rationale

A Temporary Access Pass (TAP) is a time-limited passcode that lets a user sign in and bootstrap their stronger, passwordless credentials — such as the Microsoft Authenticator app, a FIDO2 security key, or Windows Hello for Business. It solves the classic chicken-and-egg onboarding problem: how does a brand-new employee register their first passwordless method when they have no existing credential to authenticate with? With a TAP, an administrator hands them a short, expiring code instead of a permanent password.

TAP is governed tenant-wide by the 'Authentication methods policy' in Microsoft Entra. Before any user can be issued a usable pass, the TAP method must be **enabled** in this policy and the user must fall within its `includeTargets`. In this stage we manage that policy declaratively with Terraform, reusing the `msgraph_resource_action` PATCH pattern proven by the Stage 7 tenant-security module. We will set the method `state`, the `defaultLifetimeInMinutes`, whether passes are one-time use (`isUsableOnce`), and which group of users the policy applies to (`includeTargets`).

> Good news: Temporary Access Pass does not require an Entra ID P1 or P2 premium license!

## ⏱️ Estimated Time: 15 minutes

## Goals
- Automate configuration of the tenant-wide Temporary Access Pass authentication method policy using Terraform and the `microsoft/msgraph` provider.
- Understand how the Authentication methods policy controls who can be issued a usable TAP via `includeTargets`.
- Verify in the Microsoft Entra admin center that TAP is enabled with the lifetime and one-time-use settings you applied.

## Documentation & References
- [Configure Temporary Access Pass to register passwordless authentication methods](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-temporary-access-pass)
- [temporaryAccessPassAuthenticationMethodConfiguration resource type (Microsoft Graph)](https://learn.microsoft.com/graph/api/resources/temporaryaccesspassauthenticationmethodconfiguration)
- [Update temporaryAccessPassAuthenticationMethodConfiguration (Microsoft Graph)](https://learn.microsoft.com/graph/api/temporaryaccesspassauthenticationmethodconfiguration-update)

## Prerequisites
- Your Service Principal should get: `Policy.ReadWrite.AuthenticationMethod` permission.
- Required provider `microsoft/msgraph` - was used also with previews steps.

## Implementation & Code

We will use the local module `./modules/auth_methods_tap`. It issues a single Microsoft Graph `PATCH` against `policies/authenticationMethodsPolicy/authenticationMethodConfigurations/temporaryAccessPass` using `msgraph_resource_action` — the exact same approach the Stage 7 `tenant_security` module uses for the authorization policy.

> Note: This is a tenant-wide singleton policy. There is only one TAP configuration per tenant, so unlike the Service Principal stages there is no unique business name to pick. Applying this module changes a setting that affects every targeted user in your tenant. Run it in a development tenant, or be deliberate about the `include_target_group_id` you choose.

By default the module enables TAP for all users (`include_target_group_id = "all_users"`). To scope the policy to a single group instead, replace the placeholder below with that group's object ID. The `default_lifetime_in_minutes` must fall between 10 and 43200 (30 days).

Add the following block to your `main.tf`:

```hcl
#########################################################################
# Stage 17: Temporary Access Pass (TAP) Policy
#########################################################################
module "Tenant_TapPolicy" {
  source                      = "./modules/auth_methods_tap"
  state                       = "enabled"
  default_lifetime_in_minutes = 60
  is_usable_once              = true

  # Use "all_users" to target every user, or paste a specific group object ID:
  include_target_group_id = "REPLACE_WITH_GROUP_OBJECT_ID_OR_all_users"
}
```

Then apply:

```bash
terraform plan
terraform apply
```

The `terraform plan` should show a single `msgraph_resource_action.temporary_access_pass` resource to be created (the PATCH action). No new App Registration or Service Principal is provisioned in this stage.

## Verification Steps

- In the Microsoft Entra admin center → Entra ID → Authentication methods → Policies → Temporary Access Pass: the method shows Enabled, and the Target matches the group (or All users) you configured.
- Under the Configure tab of the TAP policy, confirm One-time use reflects your `is_usable_once` value and the Default lifetime matches `default_lifetime_in_minutes` (60 minutes in the example).
- Optionally confirm via Microsoft Graph by running `GET https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/temporaryAccessPass` and checking that `state`, `defaultLifetimeInMinutes`, `isUsableOnce`, and `includeTargets` reflect your Terraform values.
- (Optional) Issue a real TAP to a targeted test user from Entra ID → Users → `select a user` → Authentication methods → Add authentication method → Temporary Access Pass, and confirm the pass is generated within the configured lifetime.

### Verify with automated tests (optional)

You can prove end-to-end TAP issuance with the Pester test in `tests/peaster` — it reuses the **Stage 16 certificate Service Principal** to generate a real TAP for a target user, exercising this enabled policy:

```powershell
$env:ARM_TENANT_ID   = '<tenant-guid>'
$env:TAP_TARGET_USER = 'user@contoso.com'   # UPN or object id to issue a TAP for
Invoke-Pester ./tests/peaster/Stage-19.TAP.Tests.ps1
```

This requires:
- **Stage 16 applied** — the test resolves the cert SP from `terraform output -raw sp_with_certificate_client_id`.
- **Admin consent** for `UserAuthenticationMethod.ReadWrite.All` on that SP.
- **This TAP policy enabled** (the module above) with the target user inside `includeTargets`.

A `403 Authorization_RequestDenied` makes the test **fail red** with guidance to grant consent — it is never skipped. See `tests/peaster/README.md` for the full input contract.

## Troubleshooting

`Authorization_RequestDenied` / insufficient privileges during `terraform apply`
The identity running Terraform lacks the `Policy.ReadWrite.AuthenticationMethod` Graph application permission, or admin consent has not been granted for it. Add the permission to your workshop Service Principal, grant admin consent, and re-apply. 

`defaultLifetimeInMinutes` value rejected
The default lifetime must sit between `minimumLifetimeInMinutes` and `maximumLifetimeInMinutes` (both within the 10 – 43200 range). Pick a value inside that window, e.g. `60`.

`A targeted user still cannot sign in with their TAP`
Only users inside the policy's `includeTargets` (and not in `excludeTargets`) can use a pass. Confirm the user is a member of the group you set in `include_target_group_id`, or use `all_users`.

---

## Stage Completion Checklist
- [ ] I have read and comprehended this stage.
- [ ] I have added the `Tenant_TapPolicy` module block to my `main.tf` file.
- [ ] I have set `include_target_group_id` to `all_users` or a specific group object ID.
- [ ] I have successfully run `terraform plan` without errors.
- [ ] I have successfully run `terraform apply`.
- [ ] I have verified in the Entra admin center that Temporary Access Pass is **Enabled** with the expected lifetime and one-time-use settings.
- [ ] (Optional) I have run `Invoke-Pester ./tests/peaster/Stage-19.TAP.Tests.ps1` (with `TAP_TARGET_USER` set) and the test passes.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 17:](../stage-18/README.md) | [Next → Stage Cleanup](../stage-cleanup/README.md)
