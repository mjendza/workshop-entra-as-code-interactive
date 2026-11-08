# =============================================================================
# external_tenant — Tenant B side of the multi-tenant app (Stage 18)
# =============================================================================
# This configuration provisions the Stage-18 multi-tenant App Registration's
# Service Principal in the EXTERNAL (target) tenant and grants admin consent
# for Application.Read.All so the GitHub Actions secret-monitor workflow can
# enumerate every app's password/key credentials in this tenant.
#
# IMPORTANT: We do NOT create an `azuread_application` here. A multi-tenant app
# has exactly one App Registration — in the home tenant (Tenant A). The target
# tenant only hosts a Service Principal that references the home-tenant app's
# client ID. Creating a separate App Registration in Tenant B with the same FIC
# settings would fail with `AADSTS700236`. See doc/stage-18/README.md for the
# full architectural explanation.
# =============================================================================

# Microsoft Graph SP — exists in every tenant. Used as the resource (target) of
# the app role assignments below.
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000"
}

# Provision the multi-tenant app's Service Principal in Tenant B.
# `use_existing = true` makes this idempotent: if the SP was already created via
# the PowerShell `provision-target-tenant.ps1` script (or by a portal admin
# consenting), Terraform adopts it instead of failing on duplicate.
resource "azuread_service_principal" "multitenant_app" {
  client_id    = var.multitenant_client_id
  use_existing = true
}

# Grant admin consent for each Microsoft Graph application permission.
# Each entry creates an app role assignment from this SP onto the Graph SP.
resource "azuread_app_role_assignment" "graph" {
  for_each = toset(var.graph_permissions)

  app_role_id         = each.value
  principal_object_id = azuread_service_principal.multitenant_app.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "external_sp_object_id" {
  description = "Object ID of the SP provisioned in the target tenant."
  value       = azuread_service_principal.multitenant_app.object_id
}

output "external_sp_app_id" {
  description = "Application (client) ID of the SP — equals var.multitenant_client_id."
  value       = azuread_service_principal.multitenant_app.client_id
}
