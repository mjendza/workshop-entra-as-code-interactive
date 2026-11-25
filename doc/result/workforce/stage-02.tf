# =============================================================================
# workforce — Stage 02: Demo Service Principal
# =============================================================================
# See doc/stage-02/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Demo_ServicePrincipal" {
  source            = "./modules/service_principal"
  business_name     = "${var.deployment_unique_name}-Demo"
  graph_permissions = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"]
}
