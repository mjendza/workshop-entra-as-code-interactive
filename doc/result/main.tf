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
  business_name         = "${var.deployment_unique_name}-MyFirstAgent"
  sponsor_user_id       = "<your-user-object-id>"
  oauth2_scope_id       = "<generate-a-uuid>"

  create_agent_user     = true
  agent_user_upn_domain = "tenant-name.onmicrosoft.com"
}