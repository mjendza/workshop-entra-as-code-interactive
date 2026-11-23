# =============================================================================
# workforce — Stage 09: Maester - Configuration Assessment
# =============================================================================
# See doc/stage-09/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Maester_ServicePrincipal" {
  source        = "./modules/service_principal"
  business_name = "Maester"
  graph_permissions = [
    "dc377aa6-52d8-4e23-b271-2a7ae04cedf3",
    "2f51be20-0bb4-4fed-bf7b-db946066c75e",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "ae73097b-cb2a-4447-b064-5d80f6093921",
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e",
    "bb70e231-92dc-4729-aff5-697b3f04be95",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "37730810-e9ba-4e46-b07e-8ca78d182097",
    "4cdc2547-9148-4295-8d11-be0db1391d6b",
    "01e37dc9-c035-40bd-b438-b2879c4870a6",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "ee353f83-55ef-4b78-82da-555bfa2b4b95",
    "ff278e11-4a33-4d0c-83d2-d01dc58929a5",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "f8dcd971-5d83-4e1e-aa95-ef44611ad351",
    "5f0ffea2-f474-4cf2-9834-61cda2bcea5c",
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888",
    "dd98c7f5-2d42-42d3-a0e4-633161547251",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f",
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
  ]
}
