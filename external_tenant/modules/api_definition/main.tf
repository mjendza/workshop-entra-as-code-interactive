# =============================================================================
# Module: api_definition
# =============================================================================
# Exposes an API in the Entra External ID tenant: an app registration with
# an identifier URI, one or more delegated OAuth2 scopes, optional app roles,
# plus its enterprise application (service principal) so the API shows up under
# Enterprise applications and can be consented to.
#
# The app registration deliberately has NO redirect URI and NO client secret.
# It is a resource server: it is named in the audience of access tokens and it
# validates them. It never performs an authorization flow of its own.
#
# Note: owners are intentionally never set -- see the comment in
# ../sso_app/main.tf for why.
# =============================================================================

locals {
  # Default identifier URI is api://<client-id>, which is why it cannot be set
  # inline on the application -- the application would depend on its own
  # computed client_id. azuread_application_identifier_uri below breaks that
  # cycle by assigning the URI in a second apply step.
  identifier_uri = coalesce(var.identifier_uri, "api://${azuread_application.this.client_id}")
}

# Scope and role IDs must be stable across applies, so they are generated once
# and kept in state rather than derived from the name.
resource "random_uuid" "scope" {
  for_each = var.scopes
}

resource "random_uuid" "app_role" {
  for_each = var.app_roles
}

resource "azuread_application" "this" {
  display_name = "TF.Demo.${var.business_name}.API"

  # identifier_uris is deliberately absent -- see azuread_application_identifier_uri.

  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2

    dynamic "oauth2_permission_scope" {
      for_each = var.scopes
      content {
        id                         = random_uuid.scope[oauth2_permission_scope.key].result
        value                      = oauth2_permission_scope.key
        type                       = oauth2_permission_scope.value.consent_type
        admin_consent_display_name = oauth2_permission_scope.value.display_name
        admin_consent_description  = oauth2_permission_scope.value.description
        user_consent_display_name  = oauth2_permission_scope.value.display_name
        user_consent_description   = oauth2_permission_scope.value.description
      }
    }
  }

  # The `value` of each role is what lands in the `roles` claim of the access
  # token. The API matches on that string, so the map keys here are load-bearing
  # -- renaming one silently stops the API from recognising the role.
  dynamic "app_role" {
    for_each = var.app_roles
    content {
      id                   = random_uuid.app_role[app_role.key].result
      value                = app_role.key
      display_name         = app_role.value.display_name
      description          = app_role.value.description
      allowed_member_types = app_role.value.allowed_member_types
      enabled              = true
    }
  }

  # identifier_uris is managed by azuread_application_identifier_uri below, not
  # here. Without this the two fight: this resource wants the property empty
  # because the configuration omits it, the other wants the URI present, and
  # every plan shows a diff that every apply "fixes" in one direction only.
  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

# Assigned separately so the default can be api://<client-id> without the
# application resource depending on its own attribute.
resource "azuread_application_identifier_uri" "this" {
  application_id = azuread_application.this.id
  identifier_uri = local.identifier_uri
}

resource "azuread_service_principal" "this_SP" {
  client_id = azuread_application.this.client_id

  # ---------------------------------------------------------------------------
  # This false is load-bearing and must stay false.
  #
  # Setting it true turns on "User assignment required?" on the enterprise
  # application. Entra then refuses to issue a token to any user without an app
  # role assignment -- and it refuses one layer ABOVE the API, during token
  # issuance, so no amount of permissiveness inside the API can compensate. Every
  # customer without a role would be locked out at sign-in.
  #
  # App roles are still defined and still land in the `roles` claim; they are
  # just not a precondition for getting a token at all.
  # ---------------------------------------------------------------------------
  app_role_assignment_required = false

  use_existing = true
  feature_tags {
    enterprise = true
    gallery    = false
  }
}
