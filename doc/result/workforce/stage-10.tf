# =============================================================================
# workforce — Stage 10: EntraExporter - Configuration State Export
# =============================================================================
# See doc/stage-10/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "MicrosoftEntraExporter_ServicePrincipal" {
  source        = "./modules/service_principal"
  business_name = "EntraExporter"
  graph_permissions = [
    "d07a8cc0-3d51-4b77-b3b0-32704d1f69fa",
    "2f3e6f8c-093b-4c57-a58b-ba5ce494a169",
    "b86848a7-d5b1-41eb-a9b4-54a4e6306e97",
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "e321f0bb-e7f7-481e-bb28-e3b0b32d4bd0",
    "1b0c317f-dd31-4305-9932-259a8b6e8099",
    "bb70e231-92dc-4729-aff5-697b3f04be95",
    "498476ce-e0fe-48b0-b801-37ba7e2685c6",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "edb419d6-7edc-42a3-9345-509bfdf5d87c",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "ff278e11-4a33-4d0c-83d2-d01dc58929a5",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888",
    "75bcfbce-a647-4fba-ad51-b63d73b210f4",
    "ab5b445e-8f10-45f4-9c79-dd3f8062cc4e",
    "df021288-bdef-4463-88db-98f22de89214",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f"
  ]
}
