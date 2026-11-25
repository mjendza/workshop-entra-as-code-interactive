# =============================================================================
# workforce — Stage 21: Entra ID App Role PIM (Private Preview)
# =============================================================================
# See doc/stage-21/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "AppRolePim" {
  source          = "./modules/pim_app_roles"
  business_name   = "${var.deployment_unique_name}-AppRolePim"
  app_role_values = ["reader", "operator", "admin"]
  spa_uri         = ["https://oidcdebugger.com/debug", "https://tenant.factorlabs.pl/oidcdebugger/debug"]
  # Paste your test user object ID, e.g. ["00000000-0000-0000-0000-000000000000"]
  eligible_member_object_ids = []
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
