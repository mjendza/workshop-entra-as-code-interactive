# =============================================================================
# workforce — Stage 01: Create the SSO application for OidcDebugger
# =============================================================================
# See doc/stage-01/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "OidcDebugger_SSO" {
  source        = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-OidcDebuggerSSO"
  web_uri       = ["https://oidcdebugger.com/debug"]
}
