# =============================================================================
# workforce — Stage 05: EntraDeveloper Access Package
# =============================================================================
# See doc/stage-05/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "EntraDeveloper_Package" {
  source        = "./modules/access_package"
  business_name = "${var.deployment_unique_name}-EntraDeveloper"
}
