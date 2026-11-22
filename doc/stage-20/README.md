# Stage 20: High Assurance - Require Verified ID with Conditional Access (Preview)

## Rationale

MFA proves that someone holds a credential registered on an account. It doesn't prove **who that person is**. [Microsoft Entra high assurance](https://learn.microsoft.com/en-us/entra/verified-id/high-assurance) connects identity verification to the user lifecycle (onboarding, resource access, risk remediation and account recovery). This stage covers the **Verification for resource access** journey: after the normal sign-in, Conditional Access asks the user to present a **Verified ID** (a W3C Verifiable Credential in Microsoft Authenticator) before it grants a token for a sensitive application.

The setup has three parts:

| Part                                   | What it does                                                                                                 | How it's managed in this stage |
|----------------------------------------|--------------------------------------------------------------------------------------------------------------|--------------------------------|
| **SSO application + Service Principal** | The protected resource: an OidcDebugger app registration, the same pattern as Stage 1.                      | Terraform (`azuread`)          |
| **Identity verification profile**      | Defines which credential is accepted (issuer, type, claim bindings), the purpose (**Verification**) and the user scope. | **Manual**, in the Entra admin center. The `verifiedIdProfile` Graph API supports delegated permissions only, so a Service Principal can't create it. |
| **Conditional Access policy**          | Targets the SSO app for the pilot group and requires **Require identity verification**.                    | Terraform (`msgraph`, beta)    |

> Conditional Access doesn't let you pick a profile in the policy. At sign-in it selects the user's profile from **group membership and profile priority**. That's why Terraform creates one **pilot group**, which you use as the scope of both the profile and the policy.

> ⚠️ **Preview:** The identity verification grant control is in preview and is available only in the Microsoft public cloud. It isn't in the `azuread` provider yet, and the official Graph `builtInControls` enum docs don't list it yet. This stage sends the raw Graph beta request (`builtInControls = ["verifiedID"]`). The value comes from community examples, so step 5 shows you how to confirm it in your own tenant.

## ⏱️ Estimated Time: 30 minutes

## Goals
- Provision an SSO application (and its Service Principal) for OidcDebugger to act as the high-assurance resource.
- Create an identity verification profile with purpose **Verification** that accepts your tenant's Verified ID.
- Automate a Conditional Access policy that requires identity verification (Verified ID presentation) for that application, using the `microsoft/msgraph` provider.
- Test the step-up end-to-end with a pilot user.

## Documentation & References
- [Microsoft Entra high assurance overview](https://learn.microsoft.com/en-us/entra/verified-id/high-assurance)
- [Require identity verification with Conditional Access](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-require-identity-verification)
- [Verified ID identity verification profiles](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-authentication-verified-id)
- [verifiedIdProfile resource type (Graph beta)](https://learn.microsoft.com/en-us/graph/api/resources/verifiedidprofile?view=graph-rest-beta)
- [Identity verification licensing](https://learn.microsoft.com/en-us/entra/fundamentals/licensing#identity-verification)
- [Issue Verified Employee credentials (MyAccount)](https://learn.microsoft.com/en-us/entra/verified-id/verifiable-credentials-configure-tenant-quick)

## Prerequisites
- **Entra ID P1 license or higher.** Identity verification profiles need it. Check [identity verification licensing](https://learn.microsoft.com/en-us/entra/fundamentals/licensing#identity-verification) for your scenario.
- **Verified ID onboarded to the tenant** with Quick Setup. Follow [VC-00: Prerequisites - Onboard Your Tenant to Verified ID](../vc-00/README.md) if you haven't done it yet. Quick Setup also enables the **Verified Employee** credential this stage uses.
- Your workshop Service Principal already has `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` (Stage 4) and `Group.ReadWrite.All` (Stage 5).
- **New for this stage:** add the `User.Read.All` (Application) permission to your workshop Service Principal **manually in the Entra admin center** (App registrations → your SP → API permissions → Add a permission → **Grant admin consent**), the same way as in Stage 0. Admin consent is never granted by Terraform in this workshop. The `azuread` provider needs this permission to add users as group `members` for the pilot group. Without it you get a `403` on the group before the policy is created.
- An admin account with at least **Authentication Policy Administrator** (for the profile) and **Conditional Access Administrator**.
- A **pilot test user** (not your admin account) with **First name** and **Last name** set in Entra ID, and Microsoft Authenticator on a phone.
- An **emergency access (break-glass) account** to exclude from the policy.
- Security Defaults disabled (as in Stage 4).

> **Face Check** (live selfie matched to the credential photo) requires a separate Face Check license (Entra Suite or standalone). This stage leaves Face Check **off** so it doesn't become a hidden blocker. Turn it on later if you have the license.

## Implementation & Code

### 1. Add the SSO application and the Conditional Access policy to `main.tf`

We reuse `./modules/sso_app` (Stage 1) for the protected application. The new module `./modules/conditional_access_verified_id`:
- creates the pilot security group `TF.Workshop.<name>.Pilot`, with your test user as a member,
- creates the Conditional Access policy through `msgraph_resource` on `identity/conditionalAccess/policies` (beta):
  - **Target resources:** the SSO app's client ID,
  - **Users:** the pilot group, excluding your break-glass account,
  - **Client apps:** only `browser` and `mobileAppsAndDesktopClients`. Legacy client types aren't supported for the identity verification step-up and make the flow fail,
  - **Grant:** `builtInControls = ["verifiedID"]` (Require identity verification).

```hcl
#########################################################################
# Stage 20: High Assurance - Verified ID step-up with Conditional Access
#########################################################################
module "HighAssurance_SSO" {
  source        = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-HighAssurance-OidcDebuggerSSO"
  web_uri       = ["https://oidcdebugger.com/debug"]
  spa_uri       = ["https://tenant.factorlabs.pl/oidcdebugger/debug"]
}

module "HighAssurance_Policy" {
  source                  = "./modules/conditional_access_verified_id"
  business_name           = "${var.deployment_unique_name}-RequireVerifiedId"
  included_applications   = [module.HighAssurance_SSO.client_id]
  pilot_member_object_ids = ["PUT_PILOT_USER_OBJECT_ID_HERE"]
  excluded_user_ids       = ["PUT_BREAK_GLASS_USER_OBJECT_ID_HERE"]
  state                   = "enabled"
}

output "high_assurance_client_id" {
  value = module.HighAssurance_SSO.client_id
}

output "high_assurance_policy_id" {
  value = module.HighAssurance_Policy.policy_id
}

output "high_assurance_pilot_group_id" {
  value = module.HighAssurance_Policy.pilot_group_id
}

output "high_assurance_oidc_debugger_link" {
  value = module.HighAssurance_SSO.oidc_debugger_link
}
```

> `spa_uri` registers the workshop OIDC debugger as a **SPA** redirect (it uses PKCE in the browser). `high_assurance_oidc_debugger_link` is a ready-to-open link `https://tenant.factorlabs.pl/oidcdebugger?data=<base64 JSON>` with the authorization endpoint, client ID and scope already filled in.

> **Why `state = "enabled"`?** Report-only mode evaluates the policy but **never triggers** identity verification, so you'd see nothing during the test. The policy is scoped to the pilot group only, so other users aren't affected.

> **Why `lifecycle { ignore_changes = [body] }` in the module?** Graph returns preview enum members as `unknownFutureValue` unless the request sends the `Prefer: include-unknown-enum-members` header. Without `ignore_changes`, every `terraform plan` would show a permanent diff on `builtInControls`. To change the policy later, recreate it with:
> `terraform apply -replace='module.HighAssurance_Policy.msgraph_resource.policy'`

Then run:

```bash
terraform init
terraform plan
terraform apply
```

The plan should show the app registration and its Service Principal, the pilot `azuread_group`, and one `msgraph_resource.policy`.

### 2. Create the identity verification profile (manual - delegated-only API)

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least an Authentication Policy Administrator.
2. Go to **Verified ID** → **ID verification profiles** → **Getting started**, then select **Create your first identity verification profile** (or **Profiles** → **Create profile**).
3. Fill in:
   - **Name:** `Workshop High Assurance`
   - **Profile purpose:** **Verification**. This is the purpose that supports tenant-issued credentials for resource access. **All** accepts third-party providers only, and **Onboarding**/**Recovery** are for bootstrap journeys.
   - **Profile mode:** **Production**. In **Evaluation** mode the verification runs, but it doesn't hand off to resource access, so the user never gets the token.
   - **Users → Include → Select groups:** the pilot group `TF.Workshop.<name>-RequireVerifiedId.Pilot` (`terraform output high_assurance_pilot_group_id`).
     > Don't use **Exclude** to scope a single profile. Exclusions apply globally across **all** profiles.
   - **Verification method:** **Verified Employee** (issued by your tenant authority from VC-00). If you completed VC-01, you can choose your **custom-issued credential** instead.
   - **Account validation:** bind **First name** and **Last name** from the directory to the credential's given name and surname claims.
   - **Face Check:** off (unless you're licensed).
4. Save the profile. **Changes can take 5-10 minutes to apply.**

> Creating a profile automatically turns on tenant-wide **Collect identity verification history** (Authentication methods → Verified ID → Configure → Data collection).

### 3. Give the pilot user a Verified ID

Inline issuance from the Conditional Access challenge is **deferred** for Verified Employee. The pilot user must already hold the card before the test:

1. Sign in as the pilot user at [https://myaccount.microsoft.com](https://myaccount.microsoft.com) → **Get your Verified ID** (or open the issuance link from your Verified Employee setup).
2. Scan the QR code with Microsoft Authenticator and add the **Verified Employee** card to the wallet.

## Verification Steps

### 4. Test the step-up
1. Open a private browser window with the prefilled workshop OIDC debugger link:
   ```powershell
   terraform output -raw high_assurance_oidc_debugger_link
   ```
   Or go to [https://oidcdebugger.com](https://oidcdebugger.com) and set:
   - **Authorize URI:** `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/authorize`
   - **Client ID:** `terraform output -raw high_assurance_client_id`
   - **Scope:** `openid profile`, **Response type:** `code`
2. Sign in as the pilot user and complete the normal authentication (password + MFA).
3. Entra ID asks you to **verify your identity**. Scan the QR code with Authenticator and share the Verified Employee card.
4. You're redirected back to OidcDebugger with an authorization code.
5. Repeat with a user **outside** the pilot group. You get no Verified ID prompt.
6. Check **Entra ID → Monitoring → Sign-in logs** → the pilot sign-in → **Conditional Access**. The `TF.Workshop.<name>-RequireVerifiedId.Policy` policy shows **Success**.
7. Optionally check **Audit logs** (service *Verified ID*) for the `Verified ID verification completed` event, and the user's **Authentication methods → Identity verification history**.

### 5. Confirm the Graph control value (and inspect the profile)

The `verifiedID` enum value isn't in the official docs yet, so confirm it with the helper script. It signs you in **interactively** (delegated), because the profile API has no application permission:

```powershell
pwsh ./scripts/stage-20/verify.ps1 -PolicyId (terraform output -raw high_assurance_policy_id)
```

`BuiltInControls` should read `verifiedID`, and your profile should be listed with `Purpose = verification`. If Microsoft has renamed the control, create the same policy once in the portal, GET it with the `Prefer: include-unknown-enum-members` header, and set the `grant_control` module variable to the value you see.

## Troubleshooting

`Sign-in fails with AADSTS10020005: No valid VidProfile data found for the tenant.`
No valid profile applies to this user and scenario. Check that the profile exists with purpose **Verification**, is in **Production** mode and includes the pilot group, and that the user isn't in a global Verified ID exclusion. Then wait 5-10 minutes after any profile change.

`The Verified ID prompt is never shown.`
The policy may be in report-only mode (`enabledForReportingButNotEnforced`), the user may not be in the pilot group, or the sign-in may use a different client ID. Check the sign-in log's Conditional Access tab.

`The step-up fails right after the first sign-in.`
Make sure the policy's **Client apps** condition contains only *Browser* and *Mobile apps and desktop clients*. The module sets this, so don't add `all`.

`terraform apply returns 400 BadRequest on builtInControls.`
The preview control isn't available in your tenant yet, or its value has changed. See step 5.

`terraform plan always wants to update the policy.`
Make sure you're on the module version that contains `lifecycle { ignore_changes = [body] }`.

`Verification completes, but access is still denied.`
Another Conditional Access policy applies (for example the Stage 4 location policy targets a different app, but an **All resources** policy may still apply). Review every policy in the sign-in log.

---

## Stage Completion Checklist
- [ ] I have read and understood the high assurance and identity verification concepts.
- [ ] My tenant is onboarded to Verified ID (VC-00) and I have a P1 license.
- [ ] I have added the `HighAssurance_SSO` and `HighAssurance_Policy` modules (with pilot user and break-glass IDs) to my `main.tf`.
- [ ] I have successfully run `terraform plan` and `terraform apply`.
- [ ] I have created an identity verification profile (purpose **Verification**, **Production** mode) scoped to the pilot group.
- [ ] My pilot user holds a Verified Employee (or custom) credential in Microsoft Authenticator.
- [ ] I signed in to OidcDebugger as the pilot user and was asked to present my Verified ID.
- [ ] I confirmed that a non-pilot user isn't challenged.
- [ ] (Optional) I ran `scripts/stage-20/verify.ps1` and confirmed `BuiltInControls = verifiedID`.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or hold a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code-interactive/issues).

---
**Navigation:** [← Previous: Stage 19](../stage-19/README.md) | [Next → Stage 21: App Role PIM](../stage-21/README.md)
