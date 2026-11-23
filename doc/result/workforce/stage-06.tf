# =============================================================================
# workforce — Stage 06: EntraDeveloper PIM
# =============================================================================
# See doc/stage-06/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "EntraDeveloper_PIM" {
  source               = "./modules/pim"
  business_name        = "${var.deployment_unique_name}-EntraDeveloper"
  group_id_eligibility = module.EntraDeveloper_Package.group_id
}
