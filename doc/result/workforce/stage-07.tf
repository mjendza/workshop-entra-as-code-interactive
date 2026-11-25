# =============================================================================
# workforce — Stage 07: Tenant Security Hardening
# =============================================================================
# See doc/stage-07/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "tenant_security" {
  source = "./modules/tenant_security"

  deployment_env_name = var.deployment_env_name
  allow_invites_from  = "adminsAndGuestInviters"
  guest_user_role_id  = "10dae51f-b6af-4016-8d66-8c2a99b929b3"
}
