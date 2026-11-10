# =============================================================================
# external_tenant — External-03: SSO for a PoC application with Email OTP + MFA
# =============================================================================
# See doc/external-03/README.md. Four parts:
#   1. the tenant: SMS enabled as an authentication method (second factor),
#   2. a second PoC application: API + SPA + REQUIRED CA (MFA), which requires
#      security defaults to be DISABLED. Admin consent is NOT granted here - do
#      it MANUALLY in the Azure Portal (README step 6),
#   3. a DEDICATED passwordless Email OTP user flow, assigned to that SPA only,
#   4. outputs for the OTP PoC app's MSAL configuration.
# =============================================================================

# ---------------------------------------------------------------------------
# External-03 tenant: SMS authentication method (second factor for MFA)
# ---------------------------------------------------------------------------
# The primary sign-in is an Email OTP, so Email OTP cannot ALSO be the second
# factor. SMS is the second factor. Tenant-wide singleton PATCH: destroy does
# not switch SMS off again (set otp_sms_state = "disabled" and apply instead).
module "otp_sms" {
  source = "./modules/auth_methods_sms"
  state  = var.otp_sms_state
}

# ---------------------------------------------------------------------------
# External-03 PoC application: API + SPA + CA (MFA); consent = manual
# ---------------------------------------------------------------------------
# A SECOND instance of the External-02 poc_app module - a new SPA is required,
# because an application can be assigned to only ONE user flow and External-02's
# SPA already belongs to the email + password flow.
module "otp_app" {
  source            = "./modules/poc_app"
  name              = "${var.deployment_unique_name}-PoC-OTP"
  spa_redirect_uris = var.poc_spa_redirect_uris

  # Conditional Access (MFA via SMS). On by default in this stage.
  # Security defaults must be disabled in the tenant first.
  require_mfa = var.otp_require_mfa

  # The CA policy only makes sense once SMS can be used as the second factor.
  depends_on = [module.otp_sms]
}

check "otp_api_open_to_role_less_users" {
  assert {
    condition     = module.otp_app.api_user_assignment_required == false
    error_message = "The OTP PoC API enterprise application requires user assignment. Role-less customers cannot obtain a token at all."
  }
}

check "otp_mfa_has_second_factor" {
  assert {
    condition     = !var.otp_require_mfa || var.otp_sms_state == "enabled"
    error_message = "otp_require_mfa = true but SMS is disabled: after an Email OTP sign-in there is no second factor left and the CA policy blocks every sign-in."
  }
}

# ---------------------------------------------------------------------------
# External-03 dedicated user flow (Email OTP, passwordless) assigned to the SPA
# ---------------------------------------------------------------------------
# primary_method = "otp" -> identity provider EmailOtpSignup-OAUTH
# ("Email one-time passcode"): no password at sign-up or sign-in.
module "otp_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-PoC-OTP"
  sign_up_allowed     = var.otp_sign_up_allowed
  primary_method      = "otp"

  app_client_ids = {
    otp_spa = module.otp_app.spa_client_id
  }

  depends_on = [module.otp_app]
}

# ---------------------------------------------------------------------------
# External-03 outputs - everything the OTP PoC app needs in its MSAL config
# ---------------------------------------------------------------------------
output "external_otp_authority" {
  description = "MSAL authority for the External ID tenant (https://<subdomain>.ciamlogin.com/)."
  value       = "https://${split(".", var.tenant_default_domain)[0]}.ciamlogin.com/"
}

output "external_otp_spa_client_id" {
  description = "Client ID of the OTP PoC SPA (MSAL clientId)."
  value       = module.otp_app.spa_client_id
}

output "external_otp_api_client_id" {
  description = "Client ID of the OTP PoC API (expected aud claim of its access tokens)."
  value       = module.otp_app.api_client_id
}

output "external_otp_api_scope" {
  description = "Scope the OTP PoC SPA requests to call the API."
  value       = module.otp_app.api_scope_uri
}

output "external_otp_user_flow_id" {
  description = "ID of the OTP PoC app's dedicated Email OTP user flow."
  value       = module.otp_user_flow.user_flow_id
}

output "external_otp_ca_policy_id" {
  description = "Object ID of the require-MFA Conditional Access policy, or null when otp_require_mfa = false."
  value       = module.otp_app.ca_policy_id
}
