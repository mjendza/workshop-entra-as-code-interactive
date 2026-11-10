# Terraform state: removing and re-creating items

Notes for developers working on `external_tenant`. All commands run from `external_tenant/` in
PowerShell.

## 1. Look at what is in the state

```powershell
terraform state list
terraform state list | Select-String attr_          # filter, e.g. the External-04 attributes
terraform state show 'module.attr_terms_of_use.terraform_data.this'
```

Always put addresses in **single quotes** in PowerShell. Addresses with an index need the inner
double quotes kept as-is:

```powershell
terraform state show 'module.poc_users["alice"].msgraph_resource.this'
```

## 2. Pick the right tool

| Goal                                                                 | Command                                                   | Touches the tenant?               |
|----------------------------------------------------------------------|-----------------------------------------------------------|-----------------------------------|
| Re-run a create (provisioner / `terraform_data`) on the next apply   | `terraform apply -replace='<address>'`                    | Yes: destroy + create of that item |
| Make Terraform forget an object, keep it in the tenant               | `terraform state rm '<address>'`                          | No                                |
| Forget an object declaratively (reviewed in plan, TF >= 1.7)         | `removed { from = <address> lifecycle { destroy = false } }` | No                             |
| Take an object that already exists in the tenant into the state      | `terraform import '<address>' '<id>'` or an `import {}` block | No                            |
| Rename / move an address without recreating                          | `terraform state mv '<old>' '<new>'` or a `moved {}` block | No                               |

Prefer `-replace` when you want something to run again. Use `state rm` when the state points at an
object that doesn't exist any more, or one you want Terraform to stop managing.

> [!WARNING]
> `terraform state rm` doesn't delete anything in Entra. If the object still exists, the next
> `apply` tries to create it again, and that may fail with "already exists". Then import it or
> delete it by hand.

Terraform writes `terraform.tfstate.backup` on every state change. Make an extra copy before manual
state surgery anyway:

```powershell
Copy-Item terraform.tfstate "terraform.tfstate.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
```

## 3. Example: External-04 `Resource postcondition failed`

```text
Error: Resource postcondition failed
  on modules\custom_user_attribute\main.tf line 116, in data "msgraph_resource" "this":
  │ self.output.all is tuple with 13 elements
  │ var.name is "TermsOfUseAccepted"
Custom attribute 'TermsOfUseAccepted' is not (yet) visible in Graph identity/userFlowAttributes.
```

### What it means

The `custom_user_attribute` module has two steps:

1. `terraform_data.this` runs `create.ps1` (portal API POST) **once**. After that it is in the
   state and the script doesn't run again.
2. `data.msgraph_resource.this` lists `identity/userFlowAttributes` and must find exactly one
   `..._TermsOfUseAccepted`.

The data source is read on every plan, so it isn't the item to remove. If step 2 fails, the
question is whether the attribute really exists in the tenant.

### 3.1 Check the tenant

```powershell
$tid   = '<external tenant id>'
$token = az account get-access-token --resource https://management.core.windows.net/ --tenant $tid --query accessToken -o tsv
(Invoke-RestMethod -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } `
  -Uri "https://main.b2cadmin.ext.azure.com/api/userAttribute/GetAllUserAttributes?tenantId=$tid") |
  Where-Object attributeType -eq 3 | Select-Object id, dataType
```

Or look in the portal: External Identities → Custom user attributes.

- **The attribute is listed:** Graph is just slow to catch up. Wait a minute and run `terraform apply` again.
- **The attribute is missing**, because it was deleted by hand or the POST never created it: the
  state says "already created", but it isn't there. Go to 3.2.

### 3.2 Make the create run again

Recommended: one command, and the script is idempotent:

```powershell
terraform apply -replace='module.attr_terms_of_use.terraform_data.this'
```

Equivalent, in two steps: forget the item, then apply. On the next apply Terraform sees no
`terraform_data.this`, so it creates it, and that runs `create.ps1`.

```powershell
terraform state rm 'module.attr_terms_of_use.terraform_data.this'
terraform apply
```

For the privacy-policy attribute use `module.attr_privacy_policy.terraform_data.this`.

### 3.3 Remove the whole attribute module from the state

Use this to drop the attribute from Terraform completely, for example before you delete it by hand
or switch to the Graph alternative in `modules/custom_user_attribute/main.tf`:

```powershell
terraform state list | Select-String 'module.attr_terms_of_use'
terraform state rm 'module.attr_terms_of_use'      # removes every item of the module
```

If a user flow still references the module, comment out or remove that usage too (Step B in
`external-04.tf`). Otherwise the next plan creates the module again.

## 4. Other useful commands

```powershell
terraform plan -refresh-only                  # compare the state with the tenant, change nothing
terraform apply -refresh-only                 # write the refreshed values to the state
terraform plan -target='module.attr_terms_of_use'   # plan one module only (debugging, not routine)
terraform force-unlock <lock id>              # after a crashed run left the state locked
```
