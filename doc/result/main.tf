terraform {
 required_providers {
   azuread = {
     source  = "hashicorp/azuread"
     version = "= 3.3.0"
   }
 }
}
#########################################################################
# Basic PLACEHOLDER
#########################################################################
# Set deployment unique name
variable "deployment_unique_name" {
  default = "MJ"
}


#########################################################################
# Stage 1: Create the SSO application for OidcDebugger PLACEHOLDER
#########################################################################
module "OidcDebugger_SSO" {
  source = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-OidcDebuggerSSO"
  web_uri = ["https://oidcdebugger.com/debug"]
}

#########################################################################
# Stage 2: Demo Service Principal PLACEHOLDER
#########################################################################
module "Demo_ServicePrincipal" {
  source = "./modules/service_principal"
  business_name = "${var.deployment_unique_name}-Demo"
  graph_permissions = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"]
}

#########################################################################
# Stage 3: Workload Identity PLACEHOLDER
#########################################################################
module "Demo_WorkloadIdentity_ServicePrincipal" {
  source = "./modules/service_principal_workload_identity"
  business_name = "${var.deployment_unique_name}-WorkloadIdentity"
  enable_workload_identity = true
  subject_identifier = "system:serviceaccount:default:play-with-workload-identity"
  issuer_url = "PUT_TOKEN_ISSUER_URL_HERE"
  graph_permissions = [
    #application.read.all
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
    ]
}

#########################################################################
# Stage 4: Conditional Access PLACEHOLDER
#########################################################################
module "OidcDebugger_Policy" {
  source = "./modules/conditional_access"
  business_name = "${var.deployment_unique_name}-EnableWorkshopForDEAndIP"
  included_applications = [module.OidcDebugger_SSO.client_id]
  trusted_locations_ip_ranges = ["80.80.202.202/32"]
}

#########################################################################
# Stage 5: EntraDeveloper Access Package PLACEHOLDER
#########################################################################
module "EntraDeveloper_Package" {
  source = "./modules/access_package"
  business_name = "${var.deployment_unique_name}-EntraDeveloper"
}

#########################################################################
# Stage 6: EntraDeveloper PIM PLACEHOLDER
#########################################################################
module "EntraDeveloper_PIM" {
  source = "./modules/pim"
  business_name = "${var.deployment_unique_name}-EntraDeveloper"
  group_id_eligibility = module.EntraDeveloper_Package.group_id
}

#########################################################################
# Stage 7: Tenant Security Hardening PLACEHOLDER
#########################################################################
module "tenant_security" {
  source = "./modules/tenant_security"

  deployment_env_name                = var.deployment_env_name
  allow_invites_from                 = "adminsAndGuestInviters"
  guest_user_role_id                 = "10dae51f-b6af-4016-8d66-8c2a99b929b3"
}

#########################################################################
# Stage 8: Entra ID Agent (Preview) PLACEHOLDER
#########################################################################
module "EntraAgent" {
  source = "./modules/entra_agent"

  deployment_env_name   = var.deployment_env_name
  business_name         = "${var.deployment_unique_name}-MyAgent"
  sponsor_user_id       = "MY_USER_OBJECT_ID_HERE"
  oauth2_scope_id       = "55e4ca81-5ef2-475e-9806-b84f0af78e32"
  graph_permissions = [
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
  ]
  create_agent_user     = true
  agent_user_upn_domain = "my.entra.id.domain.here"
}

#########################################################################
# Stage 9: Maester - Configuration Assessment PLACEHOLDER
#########################################################################
module "Maester_ServicePrincipal" {
  source = "./modules/service_principal"
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

#########################################################################
# Stage 10: EntraExporter - Configuration State Export PLACEHOLDER
#########################################################################

module "MicrosoftEntraExporter_ServicePrincipal" {
  source = "./modules/service_principal"
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



#########################################################################
# Stage 11: Zero Trust Assessment PLACEHOLDER
#########################################################################
module "MicrosoftZTA_ServicePrincipal" {
  source = "./modules/service_principal"
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



#########################################################################
# Stage 13: Lokka PLACEHOLDER
#########################################################################

module "Lokka_ServicePrincipal" {
  source = "./modules/service_principal"
  business_name = "Lokka"
  graph_permissions =[
  "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
  "df021288-bdef-4463-88db-98f22de89214"
]
}