# =============================================================================
# workforce — Stage 14: SPA SSO for Application
# =============================================================================
# See doc/stage-14/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "SPA_OidcDebugger_SSO" {
  source                       = "./modules/sso_app_rich"
  business_name                = "${var.deployment_unique_name}-SPA-OidcDebuggerSSO"
  identifier_uris              = ["api://workshop.factorlabs.pl/${var.deployment_unique_name}"]
  oauth2_permission_scope_name = "Helpdesk"
  spa_uri                      = ["https://oidcdebugger.com/debug"]
}
