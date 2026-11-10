# External-02: Federation with Entra Workforce ID (OpenID Connect)

This stage validates the **OpenID Connect federation** between the External ID (CIAM) tenant and the
Workforce tenant. An SSO application registered in the **workforce** tenant (`OidcDebugger_SSO` in
the root `main.tf`) has its redirect URIs configured to include the CIAM tenant's federation
endpoint, enabling users from the workforce directory to authenticate into the external tenant via
standard OIDC flows.

The peaster test constructs the `/authorize` URL against the CIAM tenant's `ciamlogin.com` endpoint,
proving the federation plumbing is alive and reachable.

## What gets tested

| Test | What it proves |
| --- | --- |
| **Simple authorize** | The CIAM tenant's `/oauth2/v2.0/authorize` endpoint responds with a login page (HTTP 200) when called with PKCE and `scope=openid`. |
| **Authorize with `domain_hint`** | Adding `domain_hint={workforce_domain}` causes the endpoint to redirect/federate to the workforce IdP without home-realm discovery. |

## Architecture overview

```
┌─────────────────────────────────┐       ┌──────────────────────────────────┐
│  Workforce Tenant (Tenant A)    │       │  External ID / CIAM (Tenant B)   │
│                                 │       │                                  │
│  OidcDebugger_SSO App Reg       │◄──────│  /oauth2/v2.0/authorize          │
│  (Federation SSO)               │       │  (ciamlogin.com)                 │
│                                 │       │                                  │
│  redirect_uri includes:         │       │  Federates back to Tenant A      │
│  https://{sub}.ciamlogin.com/   │       │  when domain_hint is provided    │
│    {tenant_id}/federation/oauth2│       │                                  │
└─────────────────────────────────┘       └──────────────────────────────────┘
```

## The authorize URL

The test builds the OpenID Connect authorize URL in the following format:

```
https://{NATIVE_AUTH_TENANT_SUBDOMAIN}.ciamlogin.com/{FEDERATION_EXTERNAL_TENANT_ID}/oauth2/v2.0/authorize
  ?client_id={FEDERATION_WORKFORCE_CLIENT_ID}
  &nonce={random}
  &redirect_uri=https://oidcdebugger.com/debug
  &scope=openid
  &response_type=code
  &prompt=login
  &code_challenge_method=S256
  &code_challenge={PKCE_challenge}
```

For the `domain_hint` variant an additional parameter is appended:

```
  &domain_hint={WORKFORCE_FEDERATION_DOMAIN_NAME}
```

This tells the CIAM authorize endpoint to skip home-realm discovery and immediately federate the
user to the workforce IdP identified by that domain.

## Workshop steps

### 1. Prerequisites

- Complete [External-00: Prerequisites](../external-00/README.md) and
  [External-01: Native Authentication](../external-01/README.MD) - the external tenant must
  already exist and be reachable.
- The **workforce** SSO application (`OidcDebugger_SSO`) must be deployed in the root Terraform
  (`main.tf`). Its `web_uri` already includes the CIAM federation redirect:
  ```hcl
  module "OidcDebugger_SSO" {
    source        = "./modules/sso_app"
    business_name = "${var.deployment_unique_name}-OidcEEID-Federation-SSO"
    web_uri       = [
      "https://oidcdebugger.com/debug",
      "https://b2ctenantmj.ciamlogin.com/52270bb2-ed98-4b79-9314-1af808682b4b/federation/oauth2"
    ]
  }
  ```
- `terraform` ≥ 1.6, `pwsh` ≥ 7.4, the `Pester` module (≥ 5.0).

### 2. Identify the required values

| Value | Source | Example |
| --- | --- | --- |
| `NATIVE_AUTH_TENANT_SUBDOMAIN` | External tenant initial domain prefix | `b2ctenantmj` |
| `FEDERATION_EXTERNAL_TENANT_ID` | External tenant directory (tenant) ID | `52270bb2-ed98-4b79-9314-1af808682b4b` |
| `FEDERATION_WORKFORCE_CLIENT_ID` | Application (client) ID of `OidcDebugger_SSO` from the workforce tenant | *(GUID from Entra portal or `terraform output`)* |
| `WORKFORCE_FEDERATION_DOMAIN_NAME` | A verified domain of the workforce tenant | `contoso.onmicrosoft.com` |

The `FEDERATION_WORKFORCE_CLIENT_ID` is the client ID of the workforce SSO app. Find it in the
Azure Portal → Entra ID → App registrations → `TF.Workshop.*-OidcEEID-Federation-SSO` → Application
(client) ID, or add an output to `main.tf`:

```hcl
output "federation_workforce_client_id" {
  value = module.OidcDebugger_SSO.client_id
}
```

### 3. Set environment variables

```powershell
# Already defaults in PeasterConfig.ps1:
# $env:NATIVE_AUTH_TENANT_SUBDOMAIN    = 'b2ctenantmj'
# $env:FEDERATION_EXTERNAL_TENANT_ID   = '52270bb2-ed98-4b79-9314-1af808682b4b'

# Required — no default (skip if empty):
$env:FEDERATION_WORKFORCE_CLIENT_ID   = '<your-workforce-app-client-id>'

# Required for the domain_hint test (skip if empty):
$env:WORKFORCE_FEDERATION_DOMAIN_NAME = '<your-workforce-verified-domain>'
```

### 4. Run the test

```powershell
Invoke-Pester ./tests/peaster/External-02.FederationWithEntra.Simple.Tests.ps1 -Output Detailed
```

Expected output when all inputs are set:

```
Describing External-02: Federation with Entra - OpenID Connect authorize endpoint
  Context OpenID Connect authorize (simple)
    [+] constructs a valid OpenID Connect authorize URL
    [+] receives an HTTP 200 from the authorize endpoint (login page)
  Context OpenID Connect authorize (domain_hint)
    [+] constructs a valid OpenID Connect authorize URL with domain_hint
    [+] receives an HTTP 200 from the authorize endpoint with domain_hint (federation redirect)
Tests Passed: 4, Failed: 0, Skipped: 0
```

## Environment variables reference

All inputs are declared in [`tests/peaster/PeasterConfig.ps1`](../../tests/peaster/PeasterConfig.ps1).
Blank defaults cause the corresponding test context to auto-skip (CI stays green without configuration).

| Variable | Default | Purpose |
| --- | --- | --- |
| `NATIVE_AUTH_TENANT_SUBDOMAIN` | `b2ctenantmj` | CIAM tenant subdomain (authority host) |
| `FEDERATION_EXTERNAL_TENANT_ID` | `52270bb2-ed98-4b79-9314-1af808682b4b` | External CIAM tenant GUID |
| `FEDERATION_WORKFORCE_CLIENT_ID` | *(empty → skip)* | Client ID of the workforce federation SSO app |
| `WORKFORCE_FEDERATION_DOMAIN_NAME` | *(empty → skip domain_hint test)* | Workforce tenant verified domain for `domain_hint` |

## Troubleshooting

**Test skipped with "FEDERATION_WORKFORCE_CLIENT_ID is missing"**
Set the environment variable to the Application (client) ID of the `OidcDebugger_SSO` app in your
workforce tenant. The test cannot resolve it from Terraform outputs unless you add an explicit
`output` block (see step 2 above).

**HTTP 400 / "invalid_client" from the authorize endpoint**
The `client_id` doesn't match an application registered to accept tokens from this CIAM tenant. Verify
that the `OidcDebugger_SSO` app's redirect URIs include
`https://{subdomain}.ciamlogin.com/{tenant_id}/federation/oauth2`.

**HTTP timeout / DNS failure on `*.ciamlogin.com`**
Corporate proxy or VPN is blocking the CIAM login domain. Try from an unrestricted network or add
`*.ciamlogin.com` to your proxy allowlist.

**domain_hint test skipped but simple test passes**
Only `WORKFORCE_FEDERATION_DOMAIN_NAME` is missing. Set it to any verified domain of your workforce
tenant (e.g. `contoso.onmicrosoft.com` or a custom domain).

## Completion checklist

- [ ] I have identified the `FEDERATION_WORKFORCE_CLIENT_ID` from my workforce tenant.
- [ ] I have set the required environment variables.
- [ ] The simple authorize test passes (HTTP 200 from the CIAM endpoint).
- [ ] The domain_hint authorize test passes (federation redirect works).
- [ ] I understand how `domain_hint` skips home-realm discovery and routes directly to the workforce IdP.
