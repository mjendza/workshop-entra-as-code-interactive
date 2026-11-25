# Notes

Short tips and options that apply across the workshop. They are not stages: nothing here is required,
but they can save you time.

## Terraform can authenticate with the Azure CLI

The workshop configures each provider with an explicit Service Principal (`client_id`, `client_secret`,
`tenant_id`) in `provider.tf`. That is not the only option: both the `azuread` and the `msgraph` providers
can reuse the session of the **Azure CLI** (`az login`). Azure CLI authentication is enabled by default
(`use_cli = true`); the provider uses it when no other credentials are set.

This is handy for quick experiments in a sandbox tenant: there is no secret to create, store or rotate.

> [!WARNING]
> With the Azure CLI, Terraform acts as **your user account** (delegated permissions), not as the workshop
> Service Principal. What you can change depends on your directory roles, and you skip the
> "least privilege for the pipeline identity" exercise of the stages. Use a Service Principal (or Workload
> Identity Federation, Stage 3) for anything automated.

### 1. Sign in to the right tenant

Entra tenants often have no Azure subscription, so allow a sign-in without one:

```powershell
az login --tenant <tenant-id-or-domain> --allow-no-subscriptions
```

### 2. Update `provider.tf`

Remove (or comment out) the explicit credentials so the providers fall back to the Azure CLI.
For example, in [`workforce/provider.tf`](../../workforce/provider.tf):

```hcl
provider "azuread" {
  # Authenticate with the signed-in Azure CLI account (az login).
  use_cli   = true
  # Optional: pin the tenant so Terraform fails instead of changing a different tenant.
  tenant_id = "00000000-0000-0000-0000-000000000000"
}

provider "msgraph" {
  use_cli   = true
  tenant_id = "00000000-0000-0000-0000-000000000000"
}
```

Do not leave `client_id` / `client_secret` set (even to `""`) when you want Azure CLI authentication.
The same change works in [`external_tenant/provider.tf`](../../external_tenant/provider.tf) and
[`verified_id/provider.tf`](../../verified_id/provider.tf) - sign in to that tenant first.

Run `terraform init` (only needed the first time) and `terraform plan` as usual.

### 3. Check the current scope with `az account show`

Before every `terraform plan` / `apply`, confirm **which tenant and account** the Azure CLI is using -
Terraform will change whatever tenant that is.

```powershell
az account show
```

The fields that matter:

| Field | Meaning |
|---|---|
| `tenantId` | The active tenant - the one Terraform will change |
| `user.name` | The signed-in account (user or service principal) |
| `user.type` | `user` or `servicePrincipal` |
| `name` / `id` | The active subscription (or `N/A(tenant level account)` when signed in without one) |

A compact view:

```powershell
az account show --query "{tenant:tenantId, user:user.name, type:user.type, subscription:name}" -o table
```

Switch to a different tenant or account:

```powershell
az account list --query "[].{tenant:tenantId, user:user.name, subscription:name}" -o table  # what you are signed in to
az login --tenant <tenant-id-or-domain> --allow-no-subscriptions                           # sign in to another tenant
az account set --subscription <subscription-id-or-name>                                    # switch the active subscription
```

Further reading: [azuread provider - authenticating using the Azure CLI](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/azure_cli)
and [msgraph provider documentation](https://registry.terraform.io/providers/microsoft/msgraph/latest/docs).
