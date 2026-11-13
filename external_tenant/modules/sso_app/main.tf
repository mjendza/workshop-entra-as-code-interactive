# =============================================================================
# Module: sso_app
# =============================================================================
# Creates an SSO-enabled app registration (OIDC/OAuth2) plus its enterprise
# application (service principal) in the Entra External ID tenant.
#
# Unlike ../sso_app_native this module does NOT enable the native
# authentication APIs and does NOT link itself to a user flow -- the caller
# links it (see ../user_flow, var.app_client_ids). Used by External-02 for the
# CustomerHelpdesk SPA (browser redirect + PKCE).
#
# Note: owners are intentionally never set. The deployer service principal is
# added as owner automatically when it creates the app.
# =============================================================================

resource "azuread_application" "this" {
  display_name     = "TF.Demo.${var.business_name}.Application"
  sign_in_audience = var.sign_in_audience

  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }

  dynamic "web" {
    for_each = length(var.web_uri) > 0 ? [1] : []
    content {
      redirect_uris = var.web_uri
      implicit_grant {
        access_token_issuance_enabled = false
        id_token_issuance_enabled     = false
      }
    }
  }

  dynamic "single_page_application" {
    for_each = length(var.spa_uri) > 0 ? [1] : []
    content {
      redirect_uris = var.spa_uri
    }
  }

  required_resource_access {
    # Microsoft Graph
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    dynamic "resource_access" {
      for_each = var.graph_permissions_basic
      content {
        id   = resource_access.value
        type = "Scope"
      }
    }
  }

  # Delegated permissions on APIs exposed by the api_definition module.
  dynamic "required_resource_access" {
    for_each = var.resource_permissions_delegated
    content {
      resource_app_id = required_resource_access.key

      dynamic "resource_access" {
        for_each = required_resource_access.value
        content {
          id   = resource_access.value
          type = "Scope"
        }
      }
    }
  }
}

resource "azuread_service_principal" "this_SP" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = var.assign_required
  use_existing                 = true
  feature_tags {
    enterprise = true
    gallery    = false
  }
}
