# =============================================================================
# workforce — Stage 15: Application Roles for SPA SSO
# =============================================================================
# See doc/stage-15/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Demo_Roles_OidcDebugger_SSO" {
  source                       = "./modules/sso_app_rich"
  business_name                = "${var.deployment_unique_name}-Roles-OidcDebuggerSSO"
  identifier_uris              = ["api://premium.factorlabs.pl/${var.deployment_unique_name}"]
  oauth2_permission_scope_name = "PremiumHelpdesk"
  spa_uri                      = ["https://oidcdebugger.com/debug"]
  app_role_values              = ["vip", "basic", "premium"]
}
