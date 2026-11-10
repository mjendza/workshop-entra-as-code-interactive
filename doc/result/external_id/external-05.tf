# =============================================================================
# external_tenant — External-05: sync the sign-up profile to YOUR API +
#                                enrich tokens from it (custom authentication extensions)
# =============================================================================
# See doc/external-05/README.md. Five parts:
#   1. the app registration that represents your profile API towards Entra
#      (api://<host>/<client-id> + Receive.Payload consent),
#   2. two custom authentication extensions on that API:
#        - OnAttributeCollectionSubmit -> POST <api>/api/OnAttributeCollectionSubmit
#          (sign-up data: email, first/last name, both consent flags),
#        - OnTokenIssuanceStart        -> POST <api>/api/OnTokenIssuanceStart
#          (returns profile claims for the token),
#   3. a fourth PoC application (API + SPA) and its sign-up flow - the
#      External-04 attributes plus the submit extension,
#   4. the token listener + claims mapping policy for that SPA and API,
#   5. outputs.
# Start point: a Beeceptor mock (profile_api_base_url) to SEE the payloads.
# Requires External-04's module.attr_terms_of_use and module.attr_privacy_policy.
# =============================================================================

locals {
  # https://my-endpoint.free.beeceptor.com -> my-endpoint.free.beeceptor.com
  # ("" when the variable is not set -> the module validation explains it).
  profile_api_host = try(regex("^https://([^/]+)", var.profile_api_base_url)[0], "")

  # Same paths as the real profile API, so moving from the mock to the real
  # API is a change of profile_api_base_url only.
  profile_api_submit_url = "${trimsuffix(var.profile_api_base_url, "/")}/api/OnAttributeCollectionSubmit"
  profile_api_token_url  = "${trimsuffix(var.profile_api_base_url, "/")}/api/OnTokenIssuanceStart"

  # Claim name in the API response (case-sensitive) => claim name in the token.
  profile_token_claims = {
    CorrelationId = "correlationId"
    ApiVersion    = "apiVersion"
    CrmId         = "crmId"
    LoyaltyNumber = "loyaltyNumber"
    LoyaltyTier   = "loyaltyTier"
  }
}

# ---------------------------------------------------------------------------
# External-05 profile API registration (represents your REST API to Entra)
# ---------------------------------------------------------------------------
module "profile_api" {
  source   = "./modules/auth_extension_api"
  name     = "${var.deployment_unique_name}-PoC-TokenEnrichment"
  api_host = local.profile_api_host
}

# ---------------------------------------------------------------------------
# External-05 custom authentication extensions (submit + token issuance)
# ---------------------------------------------------------------------------
module "profile_sync_extension" {
  source       = "./modules/custom_auth_extension"
  event        = "attribute_collection_submit"
  display_name = "TF.${var.deployment_unique_name}.PoC-TokenEnrichment.OnAttributeCollectionSubmit"
  description  = "Push the sign-up profile (name + consents) to the profile API."
  target_url   = local.profile_api_submit_url
  resource_id  = module.profile_api.resource_id

  depends_on = [module.profile_api]
}

# ---------------------------------------------------------------------------
# External-05 PoC application: API + SPA; consent = manual
# ---------------------------------------------------------------------------
# A FOURTH poc_app instance: an application can belong to only ONE user flow.
module "sync_app" {
  source            = "./modules/poc_app"
  name              = "${var.deployment_unique_name}-PoC-TokenEnrichment"
  spa_redirect_uris = var.poc_spa_redirect_uris
}

check "sync_api_open_to_role_less_users" {
  assert {
    condition     = module.sync_app.api_user_assignment_required == false
    error_message = "The Sync PoC API enterprise application requires user assignment. Role-less customers cannot obtain a token at all."
  }
}

# Token issuance: enrich the SPA's ID token AND the PoC API's access token.
module "profile_token_extension" {
  source       = "./modules/custom_auth_extension"
  event        = "token_issuance_start"
  display_name = "TF.${var.deployment_unique_name}.PoC-TokenEnrichment.OnTokenIssuanceStart"
  description  = "Read the customer's profile from the profile API into the token."
  target_url   = local.profile_api_token_url
  resource_id  = module.profile_api.resource_id
  token_claims = keys(local.profile_token_claims)

  listener_app_client_ids = {
    sync_spa = module.sync_app.spa_client_id
    sync_api = module.sync_app.api_client_id
  }

  depends_on = [module.profile_api]
}

module "profile_claims_policy" {
  source       = "./modules/claims_mapping_policy"
  display_name = "TF.${var.deployment_unique_name}.PoC-TokenEnrichment.ProfileClaims"
  claims       = [for source, jwt in local.profile_token_claims : { source = source, jwt_claim_type = jwt }]

  # ID token (audience = SPA) and access token (audience = API).
  service_principal_object_ids = {
    sync_spa = module.sync_app.spa_service_principal_object_id
    sync_api = module.sync_app.api_service_principal_object_id
  }
}

# ---------------------------------------------------------------------------
# External-05 sign-up flow: External-04 attributes + the submit extension
# ---------------------------------------------------------------------------
module "sync_user_flow" {
  source              = "./modules/user_flow"
  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-PoC-TokenEnrichment"
  sign_up_allowed     = true

  # The External-04 tenant-level attributes, collected again on THIS flow.
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

  # "When a user submits their information" -> POST to the profile API.
  attribute_collection_submit_extension_id = module.profile_sync_extension.id

  app_client_ids = {
    sync_spa = module.sync_app.spa_client_id
  }

  depends_on = [module.sync_app]
}

# ---------------------------------------------------------------------------
# External-05 outputs
# ---------------------------------------------------------------------------
output "external_sync_authority" {
  description = "MSAL authority for the External ID tenant (https://<subdomain>.ciamlogin.com/)."
  value       = "https://${split(".", var.tenant_default_domain)[0]}.ciamlogin.com/"
}

output "external_sync_spa_client_id" {
  description = "Client ID of the Sync PoC SPA (MSAL clientId)."
  value       = module.sync_app.spa_client_id
}

output "external_sync_api_client_id" {
  description = "Client ID of the Sync PoC API (expected aud claim of its access tokens)."
  value       = module.sync_app.api_client_id
}

output "external_sync_api_scope" {
  description = "Scope the Sync PoC SPA requests to call the API."
  value       = module.sync_app.api_scope_uri
}

output "external_sync_user_flow_id" {
  description = "ID of the Sync PoC app's sign-up flow."
  value       = module.sync_user_flow.user_flow_id
}

output "external_sync_profile_api" {
  description = "Everything your profile API (or the Beeceptor mock) must know."
  value = {
    submit_url         = local.profile_api_submit_url
    token_issuance_url = local.profile_api_token_url
    # Validate the bearer token Entra sends: aud = this, azp = 99045fe1-7639-4a75-9d4a-577b6ca3810f
    expected_audience           = module.profile_api.client_id
    resource_id                 = module.profile_api.resource_id
    submit_extension_id         = module.profile_sync_extension.id
    token_issuance_extension_id = module.profile_token_extension.id
    token_issuance_listener_id  = module.profile_token_extension.listener_id
    claims_mapping_policy_id    = module.profile_claims_policy.id
    claims_returned_by_api      = keys(local.profile_token_claims)
  }
}
