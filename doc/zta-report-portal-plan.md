# ZTA Report Portal — Azure Static Web Apps + Entra ID Auth (Plan)

Goal: serve the Zero Trust Assessment HTML reports (currently pushed to Blob Storage
by `.github/workflows/zta-assessment.yml`) as a website that requires **Entra ID
sign-in** to view.

Chosen approach: **Azure Static Web Apps (SWA)** with the built-in Microsoft Entra
provider and role-based access. Cheapest option, purpose-built for static HTML, and
the identity plumbing fits the repo's existing `azuread` Terraform pattern.

---

## Why SWA (recap of the constraint)

Azure Storage **static website hosting** (`$web` / `web.core.windows.net`) is
**anonymous-only** — no Entra integration. To require a browser login you need a
compute/edge layer in front. SWA provides that with built-in auth and near-zero cost.

---

## Architecture

```
GitHub Actions (zta-assessment.yml)
   └─ Invoke-ZtAssessment  ->  entra-zta/ (HTML + assets)
        ├─ (keep) upload to Blob Storage        [archive / history]
        └─ (new)  deploy folder to Static Web App content
                     │
                     ▼
        Azure Static Web App  ──(built-in Entra provider)──>  requires sign-in
                     │  staticwebapp.config.json: allowedRoles = ["reader"]
                     ▼
             Authorized viewers (Entra group members)
```

---

## Components to create

### Terraform — Entra (`azuread` provider)
- **App registration** for the SWA (web platform).
  - Redirect URI: `https://<swa-hostname>/.auth/login/aad/callback`
  - Issue ID token (implicit) as required by the SWA AAD provider.
- **Client secret** for the app (stored as a SWA app setting;
  `AAD_CLIENT_ID` / `AAD_CLIENT_SECRET`).
- **Security group** — e.g. `sg-zta-report-readers` — controls who may view reports.
  - Assign group (or specific users) to the app registration / enterprise app.
- *(Optional)* **Conditional Access policy** scoping the app (MFA / compliant device).

### Terraform — Azure (`azurerm` provider)
- **Resource group** (or reuse existing).
- **azurerm_static_web_app** (Standard tier — required for custom Entra auth &
  app settings). Free tier only supports the pre-configured providers with limited
  control; Standard needed for custom AAD + `allowedRoles`.
- App settings on the SWA: `AAD_CLIENT_ID`, `AAD_CLIENT_SECRET`.
- Output: deployment token (for the CI deploy step) and default hostname.

> Note: SWA custom authentication (custom Entra app registration) requires the
> **Standard** plan (~\$9/mo). The Free plan's built-in AAD works but can't restrict
> by app roles/allowedRoles the same way.

### Repo content
- **`staticwebapp.config.json`** at the deployed content root:
  ```jsonc
  {
    "routes": [
      { "route": "/*", "allowedRoles": ["reader"] }
    ],
    "responseOverrides": {
      "401": { "redirect": "/.auth/login/aad", "statusCode": 302 }
    },
    "auth": {
      "identityProviders": {
        "azureActiveDirectory": {
          "registration": {
            "openIdIssuer": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
            "clientIdSettingName": "AAD_CLIENT_ID",
            "clientSecretSettingName": "AAD_CLIENT_SECRET"
          }
        }
      }
    }
  }
  ```
- Role assignment: map the Entra group to the `reader` role via the SWA
  **role management** (invite/assign) or via app roles + group claim.

---

## CI/CD changes (`zta-assessment.yml`)

Add a deploy step after the report is generated (keep the Blob upload for archive):

1. Copy `staticwebapp.config.json` into the `entra-zta` output folder.
2. Deploy with `Azure/static-web-apps-deploy@v1` using
   `azure_static_web_apps_api_token` (the SWA deployment token secret) and
   `app_location: entra-zta`, `skip_app_build: true`.

Secrets to add:
- `AZURE_STATIC_WEB_APPS_API_TOKEN` (from Terraform output).

---

## Access model (decide before build)

Who may view — **not yet decided**. Options:
- **Entra security group** (recommended): create `sg-zta-report-readers`, gate on it.
- **All tenant users**: no group restriction.
- **Named users**: explicit assignment list.

---

## Cost

- SWA Standard: ~\$9/month (needed for custom Entra auth + role control).
- SWA Free: \$0 but limited auth control — viable only if built-in AAD with
  "any authenticated tenant user" is acceptable.

---

## Open decisions / TODO

- [ ] Confirm access scope (group vs. all tenant vs. named users).
- [ ] Free vs. Standard SWA tier (depends on whether we need `allowedRoles`).
- [ ] History: deploy only latest report, or an index of all runs?
- [ ] Custom domain? (SWA supports it; adds a DNS + cert step.)
- [ ] Keep Blob upload as archive (yes, recommended) alongside SWA deploy.
- [ ] Optional Conditional Access policy for the report app.

---

## Not chosen (for reference)

- **App Service + Easy Auth** — no per-run redeploy (serve mounted blob), but
  always-on compute cost (~\$13+/mo).
- **Container App + oauth2-proxy** — private blob behind proxy, scale-to-zero cheap,
  more moving parts.
- **API Management `validate-jwt`** — overkill/expensive for static reports.
- **User-delegation SAS links** — not a login-gated website; shareable bearer URLs.
