# =============================================================================
# external_tenant — External-02: SSO for a PoC application (SPA + API)
# =============================================================================
# See doc/external-02/README.md. Three parts:
#   1. the PoC application itself: API + SPA + admin consent (+ OPTIONAL CA,
#      which requires security defaults to be DISABLED),
#   2. a DEDICATED email + password user flow, assigned to the PoC SPA only,
#   3. outputs for the PoC app's MSAL configuration.
# =============================================================================

# ---------------------------------------------------------------------------
# External-02 PoC application: API + SPA + admin consent (+ optional CA)
# ---------------------------------------------------------------------------
module "poc_app" {
  source            = "./modules/poc_app"
  name              = "${var.deployment_unique_name}-PoC"
  spa_redirect_uris = var.poc_spa_redirect_uris

  # OPTIONAL - Conditional Access (MFA via Email OTP). Off by default.
  # Security defaults must be disabled in the tenant before setting this to true.
  require_mfa = var.poc_require_mfa
}

# "User assignment required?" on the API enterprise application would make Entra
# refuse tokens to every role-less customer, one layer above the API.
check "poc_api_open_to_role_less_users" {
  assert {
    condition     = module.poc_app.api_user_assignment_required == false
    error_message = "The PoC API enterprise application requires user assignment. Role-less customers cannot obtain a token at all."
  }
}

# ---------------------------------------------------------------------------
# External-02 dedicated user flow (email + password) assigned to the PoC SPA
# ---------------------------------------------------------------------------
# A separate flow from External-01's password_user_flow: an application can be
# assigned to ONLY ONE user flow, and a dedicated flow lets the PoC app have its
# own sign-up policy (poc_sign_up_allowed) without touching other apps.
#
# app_client_ids assigns the SPA via POST .../conditions/applications/includeApplications.
# The SPA needs a service principal before it can be assigned -> depends_on.
# Only the SPA is assigned: the API is never signed in to directly, it only
# receives tokens issued during the SPA's sign-in.
module "poc_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-PoC"
  sign_up_allowed     = var.poc_sign_up_allowed

  app_client_ids = {
    poc_spa = module.poc_app.spa_client_id
  }

  depends_on = [module.poc_app]
}

# ---------------------------------------------------------------------------
# External-02 outputs - everything the PoC app needs in its MSAL config
# ---------------------------------------------------------------------------
output "external_poc_authority" {
  description = "MSAL authority for the External ID tenant (https://<subdomain>.ciamlogin.com/)."
  value       = "https://${split(".", var.tenant_default_domain)[0]}.ciamlogin.com/"
}

output "external_poc_spa_client_id" {
  description = "Client ID of the PoC SPA (MSAL clientId)."
  value       = module.poc_app.spa_client_id
}

output "external_poc_api_client_id" {
  description = "Client ID of the PoC API (expected aud claim of its access tokens)."
  value       = module.poc_app.api_client_id
}

output "external_poc_api_scope" {
  description = "Scope the SPA requests to call the API."
  value       = module.poc_app.api_scope_uri
}

output "external_poc_user_flow_id" {
  description = "ID of the PoC app's dedicated email + password user flow."
  value       = module.poc_user_flow.user_flow_id
}

output "external_poc_ca_policy_id" {
  description = "Object ID of the optional require-MFA Conditional Access policy, or null when poc_require_mfa = false."
  value       = module.poc_app.ca_policy_id
}
