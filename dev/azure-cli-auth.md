# Terraform with Azure CLI credentials (`azuread` + `msgraph`)

The committed `provider.tf` files contain empty `client_id` / `client_secret` / `tenant_id`
placeholders for a Service Principal. For local development you can skip the Service Principal
and let both providers use your **active Azure CLI session** instead.

Both providers support this natively (`use_cli = true`):

- [`hashicorp/azuread` – Authenticating using the Azure CLI](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/azure_cli)
- [`microsoft/msgraph` – Authentication](https://registry.terraform.io/providers/microsoft/msgraph/latest/docs)

> [!NOTE]
> With CLI auth, Terraform acts as **you** (delegated permissions). Your account needs the Entra
> roles the configuration requires (e.g. Application Administrator, Conditional Access
> Administrator, or Global Administrator in a workshop tenant).

## 1. Sign in to the right tenant

```powershell
az login --tenant <tenant id or domain> --allow-no-subscriptions
az account show --query "{tenant:tenantId, user:user.name}" -o table
```

`--allow-no-subscriptions` is needed for Entra-only tenants (typical for External ID tenants).
Re-run `az login --tenant ...` when switching between `workforce/` and `external_tenant/`, as
they target different tenants.

## 2. Add a local provider override

Terraform merges any `*_override.tf` file over the normal configuration. Create
`provider_override.tf` in the Terraform root you work on (`workforce/` or `external_tenant/`):

```hcl
provider "azuread" {
  client_id     = null
  client_secret = null
  tenant_id     = null # or "<tenant id>" to pin the tenant
  use_cli       = true
}

provider "msgraph" {
  client_id     = null
  client_secret = null
  tenant_id     = null # or "<tenant id>" to pin the tenant
  use_cli       = true
}
```

Setting the Service Principal arguments to `null` removes the placeholders, so the providers fall
back to the Azure CLI token. With `tenant_id = null` the tenant of the current `az` session is used.

`*_override.tf` is listed in `.gitignore`, so this file stays local and the committed
`provider.tf` is unchanged.

Make sure no `ARM_CLIENT_ID` / `ARM_CLIENT_SECRET` environment variables are set, because they take
precedence over the CLI:

```powershell
Remove-Item Env:ARM_CLIENT_ID, Env:ARM_CLIENT_SECRET, Env:ARM_CLIENT_CERTIFICATE_PATH -ErrorAction SilentlyContinue
```

## 3. Run Terraform

```powershell
cd workforce
terraform init
terraform plan
```

## Troubleshooting

| Symptom                                                       | Fix                                                                    |
|---------------------------------------------------------------|------------------------------------------------------------------------|
| `Error building account` / `az: command not found`            | Install the Azure CLI and run `az login`.                              |
| Wrong tenant is used                                          | `az login --tenant <id>` again, or pin `tenant_id` in the override.    |
| `Authorization_RequestDenied` / `403 Forbidden`               | Your user lacks the required Entra role or Graph consent for the CLI.  |
| Token expired (`AADSTS700082`, `AADSTS50173`)                 | `az logout; az login --tenant <id> --allow-no-subscriptions`.          |

> [!NOTE]
> `verified_id/` uses the custom `verifiedid` provider, which needs the Service Principal
> credentials in `provider.tf`; it does not use this Azure CLI setup.
