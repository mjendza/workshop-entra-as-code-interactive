# =============================================================================
# workforce — Stage 17: Maester & ZTA & EntraExporter in GitHub Actions (Workload Federated Identity)
# =============================================================================
# See doc/stage-17/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "GitHubMaester_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "${var.deployment_unique_name}-GitHubActionsMaester"
  enable_workload_identity = true
  subject_identifier       = "repo:mjendza/workshop-entra-as-code-interactive:environment:workshop-artefacts"
  issuer_url               = "https://token.actions.githubusercontent.com"
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

module "GitHubMicrosoftEntraExporter_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "${var.deployment_unique_name}-GitHubEntraExporter"
  enable_workload_identity = true
  subject_identifier       = "repo:mjendza/workshop-entra-as-code-interactive:environment:workshop-artefacts"
  issuer_url               = "https://token.actions.githubusercontent.com"
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

module "GitHubMicrosoftZTA_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "${var.deployment_unique_name}-GitHubMicrosoftZTA"
  enable_workload_identity = true
  subject_identifier       = "repo:mjendza/workshop-entra-as-code-interactive:environment:workshop-artefacts"
  issuer_url               = "https://token.actions.githubusercontent.com"
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
