# =============================================================================
# external_tenant — External-01: Native Authentication (email + password)
# =============================================================================
# See doc/external-01/README.MD. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

# ---------------------------------------------------------------------------
# External-01 Password User Flow for application
# ---------------------------------------------------------------------------

module "password_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-Password"
}

# ---------------------------------------------------------------------------
# External-01 native-auth SIGN-IN test user (created only when an email is set)
# ---------------------------------------------------------------------------
module "native_signin_user" {
  source       = "./modules/user"
  count        = var.native_signin_user_email != "" ? 1 : 0
  email        = var.native_signin_user_email
  display_name = "Workshop Test User"
  issuer       = var.tenant_default_domain
}

output "external_native_signin_user_email" {
  description = "E-mail (emailAddress identity) of the native-auth sign-in test user, or null when not created."
  value       = length(module.native_signin_user) > 0 ? module.native_signin_user[0].email : null
}

output "external_native_signin_user_object_id" {
  description = "Object ID of the native-auth sign-in test user, or null when not created."
  value       = length(module.native_signin_user) > 0 ? module.native_signin_user[0].object_id : null
}

# ---------------------------------------------------------------------------
# External-01 native auth application
# ---------------------------------------------------------------------------
module "native_auth_app" {
  source                         = "./modules/sso_app_native"
  business_name                  = "${var.deployment_unique_name}-NativeAuth"
  sign_in_audience               = "AzureADMyOrg"
  web_uri                        = []
  spa_uri                        = []
  fallback_public_client_enabled = true
  user_flow_id                   = module.password_user_flow.user_flow_id
}

output "external_native_federation_client_id" {
  description = "Application (client) ID of the native-auth application created in the external tenant."
  value       = module.native_auth_app.client_id
}
