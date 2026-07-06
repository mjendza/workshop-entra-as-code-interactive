# External-01: Entra External ID Native Authentication Flow

<!-- Banner: generate via doc/assets/image-prompts.md, save as banner.png in this folder, then uncomment:
![External-01 banner](banner.png)
-->

Similar to Stage 01 we enable a new SSO application, but this time using the `Native` application
type. Native apps (mobile / desktop clients) authenticate directly against the tenant with
Microsoft's [Native Authentication API](https://learn.microsoft.com/en-us/entra/identity-platform/reference-native-authentication-api?tabs=emailOtp)
instead of a browser redirect, so the flows differ from the web apps in earlier stages.

This stage lives in the dedicated [`external_tenant/`](../../external_tenant/) Terraform root (the
same one used by Stage 18), because Native Authentication is an **External ID (CIAM) tenant**
feature and must be applied against that tenant (Tenant B), not the workshop's home tenant.

## What gets created

Three resources, wired together in [`external_tenant/main.tf`](../../external_tenant/main.tf):

```hcl
# 1. A self-service sign-up user flow with the "Email with password" identity provider
#    (external_tenant/modules/user_flow) - this is what actually turns on email+password
#    authentication for the tenant.
module "password_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-Password"
}

# 2. The native application. `sso_app_native` sets nativeAuthenticationApisEnabled = "all"
#    (a beta Graph property, via msgraph_update_resource) so the app can drive the
#    signup/oauth2 native-auth REST endpoints, and links it to the user flow above.
module "native_auth_app" {
  source                          = "./modules/sso_app_native"
  business_name                   = "${var.deployment_unique_name}-NativeAuth"
  sign_in_audience                = "AzureADMyOrg"
  web_uri                         = []
  spa_uri                         = []
  fallback_public_client_enabled  = true
  user_flow_id                    = module.password_user_flow.user_flow_id
}

# 3. (Optional) An existing user for the SIGN-IN test - only created when
#    var.native_signin_user_email is non-empty. See "Sign-in test user" below.
module "native_signin_user" {
  source       = "./modules/user"
  count        = var.native_signin_user_email != "" ? 1 : 0
  email        = var.native_signin_user_email
  display_name = "Workshop Test User"
  issuer       = var.tenant_default_domain
}
```

Outputs: `external_native_federation_client_id`, `external_native_signin_user_email`,
`external_native_signin_user_object_id`.

## Native authentication flows

Both tests exercise the **email + password** method (matching the External-01 password user flow). The
authority base URL is:

```
https://<subdomain>.ciamlogin.com/<subdomain>.onmicrosoft.com
```

`<subdomain>` is the label before `.onmicrosoft.com` in `var.tenant_default_domain` (e.g.
`b2ctenantmj.onmicrosoft.com` → subdomain `b2ctenantmj`). You can pass either form to the peaster
tests (see below) - `Get-PeasterNativeAuthAuthority` in `PeasterConfig.ps1` strips a trailing
`.onmicrosoft.com` before building the authority, so a pasted full domain doesn't double up into a
broken URL like `b2ctenantmj.onmicrosoft.com.ciamlogin.com`.

**Sign-up** (new user) — `POST signup/v1.0/{start,challenge,continue}` then `POST oauth/v2.0/token`.
E-mail is verified with an OTP *and* a password is set:

1. `start`    — `client_id`, `username`, `password`, `challenge_type=oob password redirect` → `continuation_token`.
2. `challenge`— sends the OTP by email → `challenge_type=oob`, `code_length`.
3. `continue` — `grant_type=oob`, `oob=<code>`; then, on `credential_required`, `challenge` again and
   `continue` with `grant_type=password` (and `grant_type=attributes` if `attributes_required`).
4. `token`    — `grant_type=continuation_token`, `scope=openid offline_access` → `id_token`.

**Sign-in** (existing user) — `POST oauth2/v2.0/{initiate,challenge,token}`. Password only, **no OTP**:

1. `initiate` — `client_id`, `username`, `challenge_type=password redirect` → `continuation_token`.
2. `challenge`— `challenge_type=password redirect` → `challenge_type=password` (nothing e-mailed).
3. `token`    — `grant_type=password`, `password=<pwd>`, `scope=openid offline_access` → `id_token`.

> **Known gap:** the `native_auth_app` registration doesn't currently request the `email` optional
> claim, so the `id_token` returned by `oauth2/v2.0/token` only carries the standard claims
> (`aud`, `iss`, `sub`, `tid`, …) - no `email` / `preferred_username`. The sign-in test therefore
> asserts identity via `sub`, not by matching the e-mail. Add the `email` optional claim to
> `sso_app_native` (token configuration) if you need the claim back.

## Workshop steps

### 1. Prerequisites

- Complete [External-00: Prerequisites](../external-00/README.md) first - it creates the bootstrap
  Service Principal in your External ID (CIAM) tenant (Tenant B), configured in
  [`external_tenant/provider.tf`](../../external_tenant/provider.tf), with every Graph permission the
  `external_tenant/` modules need (including the ones this stage's `password_user_flow` and
  `native_auth_app` modules require). If you already did this for Stage 18, it's the same
  file/tenant/Service Principal - nothing more to do here.
- An External ID (CIAM) tenant already exists. This repo ships a working default
  (`b2ctenantmj.onmicrosoft.com`) in `external_tenant/terraform.tfvars` - see the note in step 2.
- `terraform` ≥ 1.6, `pwsh` ≥ 7.4, the `Pester` module (for the E2E tests).

### 2. Configure `external_tenant/terraform.tfvars`

```hcl
tenant_default_domain    = "b2ctenantmj.onmicrosoft.com"        # REQUIRED - no default in variables.tf
native_signin_user_email = "workshop01@fake.factorlabs.pl"      # optional - creates the sign-in test user
```

- **`tenant_default_domain` must be provided** - `external_tenant/variables.tf` declares it with no
  default, so `terraform apply` fails without it. For the workshop you don't need your own tenant:
  **the value already committed in `terraform.tfvars` is a working default** you can use as-is.
  If you deployed your own External ID tenant, replace it with that tenant's initial
  (`*.onmicrosoft.com`) domain instead.
- `native_signin_user_email` is optional and left blank by default (so unrelated applies aren't
  affected). Set it to provision the External-01 **sign-in** test user up front; leave it blank and
  the sign-in E2E test auto-skips. Its mailbox must be reachable through your fakemail RSS feed if
  you also intend to inspect mail for it (the sign-in flow itself needs no mailbox access - password
  sign-in never sends an OTP).

### 3. Apply

```powershell
cd external_tenant
terraform init
terraform plan
terraform apply
```

### 4. Capture the outputs

```powershell
terraform output -raw external_native_federation_client_id
terraform output -raw external_native_signin_user_email
```

The peaster tests below resolve these automatically (see `PeasterConfig.ps1`), so this step is
just for sanity-checking the apply.

## Sign-in test user (created via Terraform)

The sign-in flow needs an existing account. Because the mailbox domain is an *external* domain
(not a verified tenant domain), the account cannot be a normal `azuread_user` (whose UPN must be a
verified domain). Instead the `./modules/user` module (referred to as the native-auth test user
module) creates a **local account with an `emailAddress` identity** through the Microsoft Graph
beta API (`msgraph_resource`), so the user can sign in with their e-mail. The initial
(`onmicrosoft.com`) domain is used as the identity `issuer`, and the module's default password
(`Aa1!Workshop-Native-External-01`) matches `PeasterConfig.ps1`'s `NATIVE_AUTH_SIGNIN_PASSWORD` default -
don't change one without the other (the password isn't currently exposed as a variable on the
`native_signin_user` module call in `main.tf`).

## End-to-end tests (peaster / Pester)

Two live E2E tests exercise the real email+password API. Sign-up reads its verification OTP back from
the fakemail **RSS** feed (`<NATIVE_AUTH_RSS_BASE>/<email>`); sign-in uses the password directly (no OTP):

| Test | What it proves |
| --- | --- |
| `tests/peaster/External-01.NativeAuth-SignUp.E2E.Tests.ps1` | A brand-new user can self-service sign up (email verified via OTP, password set); random mailbox per run; the created user is deleted afterwards. |
| `tests/peaster/External-01.NativeAuth-SignIn.E2E.Tests.ps1` | The Terraform-created user can sign in with email + password (no OTP); the password must match the module's. |

Both follow the existing peaster convention (`tests/peaster/PeasterConfig.ps1`): every live input is
an environment variable with a default (some blank so the whole context auto-skips and CI stays
green until the inputs are provided). Shared flow helpers (HTTP calls with browser-like headers,
JWT decoding, OTP scraping) live in `tests/peaster/NativeAuthHelpers.ps1`.

Inputs (`PeasterConfig.ps1` default in parentheses; blank ⇒ skip):

```
NATIVE_AUTH_TENANT_SUBDOMAIN   external CIAM subdomain (authority host) ('b2ctenantmj')      [both]
NATIVE_AUTH_CLIENT_ID          optional; else terraform output external_native_federation_client_id [both]
NATIVE_AUTH_RSS_BASE           fakemail RSS base URL; feed = <base>/<email> ('')             [sign-up]
NATIVE_AUTH_EMAIL_DOMAIN       sign-UP mailbox domain (random local-part) ('')               [sign-up]
NATIVE_AUTH_OTP_TIMEOUT_SEC    RSS poll timeout, seconds ('90')                               [sign-up]
NATIVE_AUTH_SIGNIN_USERNAME    optional; else terraform output external_native_signin_user_email [sign-in]
NATIVE_AUTH_SIGNIN_PASSWORD    must match the native_auth_test_user module password ('Aa1!Workshop-Native-External-01') [sign-in]
EXTERNAL_GRAPH_TENANT_ID / _CLIENT_ID / _CLIENT_SECRET   app-only creds to delete the signed-up user ('') [sign-up]
```

`NATIVE_AUTH_TENANT_SUBDOMAIN` and `NATIVE_AUTH_SIGNIN_PASSWORD` already default to values matching
this repo's committed `terraform.tfvars` / module defaults, so after `terraform apply` the **sign-in**
test can usually run with no environment variables at all as long as `terraform` is on `PATH` (so the
client id / username outputs resolve automatically). The **sign-up** test always needs
`NATIVE_AUTH_RSS_BASE` / `NATIVE_AUTH_EMAIL_DOMAIN` set, since a mailbox is environment-specific and
intentionally not committed.

### 5. Run the tests

```powershell
# Only required for the sign-up test (mailbox is environment-specific, not committed):
$env:NATIVE_AUTH_RSS_BASE     = '<fakemail-rss-base-url>'
$env:NATIVE_AUTH_EMAIL_DOMAIN = '<mailbox-domain>'

# Override only if you deployed a different tenant / user than the committed defaults:
# $env:NATIVE_AUTH_TENANT_SUBDOMAIN = '<subdomain>'
# $env:NATIVE_AUTH_SIGNIN_USERNAME  = '<sign-in-user-email>'

Invoke-Pester ./tests/peaster/External-01.NativeAuth-SignUp.E2E.Tests.ps1 -Output Detailed
Invoke-Pester ./tests/peaster/External-01.NativeAuth-SignIn.E2E.Tests.ps1 -Output Detailed
```

## Troubleshooting

**`oauth2/initiate failed (HTTP ...): error=HttpRequestException ... desc=...`**
A transport-level failure (no HTTP response ever arrived) - DNS resolution, TLS handshake, or a
network block, surfaced from the raw .NET exception by `Invoke-NativeAuth`. Not a Terraform/app
config issue. Common cause: `RemoteCertificateNameMismatch` from a TLS-inspecting corporate
proxy/VPN, or a brand-new CIAM tenant whose `<subdomain>.ciamlogin.com` routing/certificate hasn't
finished propagating yet. Try the same authority URL from a browser off the corporate network to
confirm.

**Authority URL has a doubled `.onmicrosoft.com` (e.g. `...onmicrosoft.com.ciamlogin.com`)**
`NATIVE_AUTH_TENANT_SUBDOMAIN` was set to the full `tenant.onmicrosoft.com` instead of the bare
subdomain. `Get-PeasterNativeAuthAuthority` now strips a trailing `.onmicrosoft.com` before building
the URL, so either form works - update if you're on an older checkout.

**`token endpoint failed ...: error=invalid_grant`**
The password sent by the test doesn't match the `native_signin_user` module's password. Check
`NATIVE_AUTH_SIGNIN_PASSWORD` against the module default (`Aa1!Workshop-Native-External-01`) or whatever you
overrode it to.

**Sign-in test fails asserting on `email`**
See the "Known gap" note above - the id_token doesn't carry an email claim today; the test checks
`sub` instead.

---
**Navigation:** [← External-00: Prerequisites](../external-00/README.md)
