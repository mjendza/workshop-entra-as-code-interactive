# =============================================================================
# external_tenant — External-04: sign-up with extra attributes
# =============================================================================
# See doc/external-04/README.md. Applied in THREE steps:
#   Step A (apply #1)
#     1. two tenant-level CUSTOM boolean attributes: TermsOfUseAccepted and
#        PrivacyPolicyAccepted (portal API, see modules/custom_user_attribute)
#        + their ids output,
#   Step B (apply #2)
#     2. a third PoC application: API + SPA (admin consent = MANUAL, step 5),
#     3. a DEDICATED email + password user flow that also collects first name,
#        last name and both REQUIRED consent checkboxes, assigned to that SPA,
#     4. outputs.
#   Step C (apply #3)
#     5. a claims mapping policy that adds both consent flags to the SPA's
#        ID token and the API's access token.
# =============================================================================

# ---------------------------------------------------------------------------
# Step A - External-04 custom user attributes (terms of use + privacy policy)
# ---------------------------------------------------------------------------
# Tenant-level: created once, usable by any user flow. The id output is the
# full extension_<b2c-extensions-app appId>_<name> the flow and Graph expect.
module "attr_terms_of_use" {
  source      = "./modules/custom_user_attribute"
  name        = "TermsOfUseAccepted"
  description = "The customer accepted the terms of use during sign-up."
  data_type   = "boolean"
}

module "attr_privacy_policy" {
  source      = "./modules/custom_user_attribute"
  name        = "PrivacyPolicyAccepted"
  description = "The customer accepted the privacy policy during sign-up."
  data_type   = "boolean"

  # Serialize the two creates: parallel POSTs to the portal API can drop one
  # attribute (both report success, only one is stored).
  depends_on = [module.attr_terms_of_use]
}

output "external_signup_custom_attribute_ids" {
  description = "Full ids of the custom attributes - use them in Graph $select on users."
  value = {
    terms_of_use   = module.attr_terms_of_use.id
    privacy_policy = module.attr_privacy_policy.id
  }
}

# ---------------------------------------------------------------------------
# Step B - External-04 PoC application: API + SPA; consent = manual
# ---------------------------------------------------------------------------
# A THIRD poc_app instance: an application can belong to only ONE user flow.
module "signup_app" {
  source            = "./modules/poc_app"
  name              = "${var.deployment_unique_name}-PoC-Extensions"
  spa_redirect_uris = var.poc_spa_redirect_uris
}

check "signup_api_open_to_role_less_users" {
  assert {
    condition     = module.signup_app.api_user_assignment_required == false
    error_message = "The Signup PoC API enterprise application requires user assignment. Role-less customers cannot obtain a token at all."
  }
}

# ---------------------------------------------------------------------------
# Step B - External-04 dedicated user flow with extra sign-up attributes
# ---------------------------------------------------------------------------
# Order on the sign-up page = list order (after email and display name).
# Boolean attributes render as a single checkbox; required = true means the box
# must be ticked before the customer can continue. Labels support Markdown links.
module "signup_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-PoC-Extensions"
  sign_up_allowed     = true

  extra_attributes = [
    {
      attribute    = "givenName"
      display_name = "Given Name"
      description  = "The user's given name (also known as first name)."
      label        = "First name"
      required     = true
    },
    {
      attribute    = "surname"
      display_name = "Surname"
      description  = "The user's surname (also known as family name or last name)."
      label        = "Last name"
      required     = true
    },
    {
      attribute                = module.attr_terms_of_use.id
      display_name             = module.attr_terms_of_use.name
      description              = "The customer accepted the terms of use during sign-up."
      label                    = "I have read and agree to the [terms of use](${var.signup_terms_of_use_url})"
      data_type                = "boolean"
      user_flow_attribute_type = "custom"
      input_type               = "boolean"
      required                 = true
    },
    {
      attribute                = module.attr_privacy_policy.id
      display_name             = module.attr_privacy_policy.name
      description              = "The customer accepted the privacy policy during sign-up."
      label                    = "I have read and agree to the [privacy policy](${var.signup_privacy_policy_url})"
      data_type                = "boolean"
      user_flow_attribute_type = "custom"
      input_type               = "boolean"
      required                 = true
    },
  ]

  app_client_ids = {
    signup_spa = module.signup_app.spa_client_id
  }

  depends_on = [module.signup_app]
}

# ---------------------------------------------------------------------------
# Step B - External-04 outputs
# ---------------------------------------------------------------------------
output "external_signup_authority" {
  description = "MSAL authority for the External ID tenant (https://<subdomain>.ciamlogin.com/)."
  value       = "https://${split(".", var.tenant_default_domain)[0]}.ciamlogin.com/"
}

output "external_signup_spa_client_id" {
  description = "Client ID of the Signup PoC SPA (MSAL clientId)."
  value       = module.signup_app.spa_client_id
}

output "external_signup_api_client_id" {
  description = "Client ID of the Signup PoC API (expected aud claim of its access tokens)."
  value       = module.signup_app.api_client_id
}

output "external_signup_api_scope" {
  description = "Scope the Signup PoC SPA requests to call the API."
  value       = module.signup_app.api_scope_uri
}

output "external_signup_user_flow_id" {
  description = "ID of the Signup PoC app's dedicated user flow."
  value       = module.signup_user_flow.user_flow_id
}

# ---------------------------------------------------------------------------
# Step C - External-04 token claims: the consent flags in ID + access token
# ---------------------------------------------------------------------------
# The flow stores the custom attributes on the user, but they are NOT in any
# token by default. A claims mapping policy (Source = user, ExtensionID = the
# full extension_<appId>_<name>) adds them. Assigned by token AUDIENCE: the
# SPA's SP for the ID token, the API's SP for the access token. Both apps
# already accept mapped claims (sso_app / api_definition set
# mapped_claims_enabled = true). Requires Policy.ReadWrite.ApplicationConfiguration.
module "signup_claims_policy" {
  source       = "./modules/claims_mapping_policy"
  display_name = "TF.${var.deployment_unique_name}.PoC-Extensions.ConsentClaims"

  claims = [
    {
      source_type    = "user"
      source         = module.attr_terms_of_use.id
      jwt_claim_type = "terms_of_use_accepted"
    },
    {
      source_type    = "user"
      source         = module.attr_privacy_policy.id
      jwt_claim_type = "privacy_policy_accepted"
    },
  ]

  service_principal_object_ids = {
    signup_spa = module.signup_app.spa_service_principal_object_id
    signup_api = module.signup_app.api_service_principal_object_id
  }
}
