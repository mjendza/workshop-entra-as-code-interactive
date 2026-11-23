# =============================================================================
# workforce — Stage 04: Conditional Access
# =============================================================================
# See doc/stage-04/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "OidcDebugger_Policy" {
  source                      = "./modules/conditional_access"
  business_name               = "${var.deployment_unique_name}-EnableWorkshopForDEAndIP"
  included_applications       = [module.OidcDebugger_SSO.client_id]
  trusted_locations_ip_ranges = ["80.80.202.202/32"]
}
