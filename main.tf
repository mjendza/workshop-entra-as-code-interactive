terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.7.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.6.0"
    }
  }
}


#########################################################################
# Basic PLACEHOLDER
#########################################################################


#########################################################################
# Stage 1: Create the SSO application for OidcDebugger PLACEHOLDER
#########################################################################


#########################################################################
# Stage 2: Demo Service Principal PLACEHOLDER
#########################################################################


#########################################################################
# Stage 3: Workload Identity PLACEHOLDER
#########################################################################


#########################################################################
# Stage 4: Conditional Access PLACEHOLDER
#########################################################################


#########################################################################
# Stage 5: EntraDeveloper Access Package PLACEHOLDER
#########################################################################


#########################################################################
# Stage 6: EntraDeveloper PIM PLACEHOLDER
#########################################################################


#########################################################################
# Stage 7: Tenant Security Hardening PLACEHOLDER
#########################################################################


#########################################################################
# Stage 8: Entra ID Agent (Preview) PLACEHOLDER
#########################################################################


#########################################################################
# Stage 9: Maester - Configuration Assessment PLACEHOLDER
#########################################################################


#########################################################################
# Stage 10: EntraExporter - Configuration State Export PLACEHOLDER
#########################################################################


#########################################################################
# Stage 11: Zero Trust Assessment PLACEHOLDER
#########################################################################


#########################################################################
# Stage 13: Lokka PLACEHOLDER
#########################################################################


#########################################################################
# Stage 14: SPA SSO for Application PLACEHOLDER
#########################################################################


#########################################################################
# Stage 15: Application Roles for SPA SSO PLACEHOLDER
#########################################################################


#########################################################################
# Stage 16: Certificate-Based SP Authentication PLACEHOLDER
#########################################################################


#########################################################################
# Stage 17: Maester & ZTA & EntraExporter in GitHub Actions (Workload Federated Identity) PLACEHOLDER
#########################################################################


#########################################################################
# Stage 18: Multi-Tenant App with GitHub Actions OIDC PLACEHOLDER
#########################################################################


#########################################################################
# Stage 19: TAP PLACEHOLDER
#########################################################################


#########################################################################
# Stage 20: High Assurance - Verified ID step-up with Conditional Access PLACEHOLDER
#########################################################################
module "HighAssurance_SSO" {
  source        = "./modules/sso_app"
  business_name = "${var.deployment_unique_name}-HighAssurance-OidcDebuggerSSO"
  web_uri       = ["https://oidcdebugger.com/debug"]
}

module "HighAssurance_Policy" {
  source                  = "./modules/conditional_access_verified_id"
  business_name           = "${var.deployment_unique_name}-RequireVerifiedId"
  included_applications   = [module.HighAssurance_SSO.client_id]
  pilot_member_object_ids = ["e07763ba-b4bf-4129-9a9e-0ca94661804c"]
  excluded_user_ids       = ["31e4ca81-5ef2-475e-9806-b84f0af78e32"]
  state                   = "enabled"
}

output "high_assurance_client_id" {
  value = module.HighAssurance_SSO.client_id
}

output "high_assurance_policy_id" {
  value = module.HighAssurance_Policy.policy_id
}

output "high_assurance_pilot_group_id" {
  value = module.HighAssurance_Policy.pilot_group_id
}

#########################################################################
# Stage 21: Entra ID App Role PIM (Private Preview) PLACEHOLDER
#########################################################################
module "AppRolePim" {
  source          = "./modules/pim_app_roles"
  business_name   = "${var.deployment_unique_name}-AppRolePim"
  app_role_values = ["reader", "operator", "admin"]
  # Paste your test user object ID, e.g. ["00000000-0000-0000-0000-000000000000"]
  eligible_member_object_ids = ["e07763ba-b4bf-4129-9a9e-0ca94661804c"]
  standing_role_value        = "reader"
}

output "app_role_pim_client_id" {
  value = module.AppRolePim.client_id
}

output "app_role_pim_service_principal_object_id" {
  value = module.AppRolePim.service_principal_object_id
}

output "app_role_pim_eligible_group_id" {
  value = module.AppRolePim.eligible_group_id
}

output "app_role_pim_app_role_ids" {
  value = module.AppRolePim.app_role_ids
}
##########################################################################
# Stage 101: Verified ID — Credential Contract (Service Principal for dedicated stack) PLACEHOLDER
#########################################################################
