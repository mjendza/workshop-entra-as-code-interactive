# =============================================================================
# workforce — Stage 20: High Assurance - Verified ID step-up with Conditional Access
# =============================================================================
# See doc/stage-20/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

variable "high_assurance_pilot_user_ids" {
  description = "Object IDs of pilot users for the Verified ID policy."
  type        = list(string)
}

variable "high_assurance_break_glass_user_ids" {
  description = "Object IDs of emergency access users excluded from the Verified ID policy."
  type        = list(string)
}

module "HighAssurance_SSO" {
  source        = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-HighAssurance-OidcDebuggerSSO"
  web_uri       = ["https://oidcdebugger.com/debug"]
  spa_uri       = ["https://tenant.factorlabs.pl/oidcdebugger/debug"]
}

module "HighAssurance_Policy" {
  source                  = "./modules/conditional_access_verified_id"
  business_name           = "${var.deployment_unique_name}-RequireVerifiedId"
  included_applications   = [module.HighAssurance_SSO.client_id]
  pilot_member_object_ids = var.high_assurance_pilot_user_ids
  excluded_user_ids       = var.high_assurance_break_glass_user_ids
  # After creating the profiles: all profile IDs from scripts/stage-20/verify.ps1
  verified_id_profile_ids = []
  state                   = "enabled"
}

output "high_assurance_client_id" {
  value = module.HighAssurance_SSO.client_id
}

output "high_assurance_policy_id" {
  value = module.HighAssurance_Policy.policy_id
}

output "high_assurance_pilot_group_id" {
  value = module.HighAssurance_Policy.pilot_group_id
}

output "high_assurance_oidc_debugger_link" {
  value = module.HighAssurance_SSO.oidc_debugger_link
}
