# =============================================================================
# workforce — Stage 13: Lokka
# =============================================================================
# See doc/stage-13/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Lokka_ServicePrincipal" {
  source        = "./modules/service_principal"
  business_name = "Lokka"
  graph_permissions = [
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
    "df021288-bdef-4463-88db-98f22de89214"
  ]
}
