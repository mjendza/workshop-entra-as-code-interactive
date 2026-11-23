# =============================================================================
# workforce — Stage 11: Zero Trust Assessment
# =============================================================================
# See doc/stage-11/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "MicrosoftZTA_ServicePrincipal" {
  source        = "./modules/service_principal"
  business_name = "MicrosoftZTA"
  graph_permissions = [
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "cac88765-0581-4025-9725-5ebc13f729ee",
    "7a6ee1e7-141e-4cec-ae74-d9db155731ff",
    "dc377aa6-52d8-4e23-b271-2a7ae04cedf3",
    "2f51be20-0bb4-4fed-bf7b-db946066c75e",
    "58ca0d9a-1575-47e1-a3cb-007ef2e4583b",
    "06a5fe6d-c49d-46a7-b082-56b1b14103c7",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "ae73097b-cb2a-4447-b064-5d80f6093921",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e",
    "dc5007c0-2d7d-4c42-879c-2dab87571379",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "37730810-e9ba-4e46-b07e-8ca78d182097",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "4cdc2547-9148-4295-8d11-be0db1391d6b",
    "01e37dc9-c035-40bd-b438-b2879c4870a6",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f"
  ]
}
