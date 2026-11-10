# =============================================================================
# Module: auth_extension_api  (External-05)
# =============================================================================
# The app registration that REPRESENTS your REST API (the handler) towards
# Entra custom authentication extensions:
#   - identifier URI api://<api host>/<client-id> (the format Microsoft
#     documents for custom authentication extensions),
#   - access token v2,
#   - service principal,
#   - Microsoft Graph application permission
#     CustomAuthenticationExtension.Receive.Payload, GRANTED (admin consent) by
#     Terraform. This is the portal's "Grant permission" button on a custom
#     authentication extension: without it Entra cannot get a token for your
#     API and every call fails.
#
# Entra calls the API with client_credentials. The bearer token has
#   aud = this app's client id,
#   azp = 99045fe1-7639-4a75-9d4a-577b6ca3810f (Entra "Authentication Events" app),
#   iss = the ciamlogin.com issuer of your tenant (copy it from a decoded token)
# A real API MUST validate exactly that. A mock (Beeceptor) just ignores it.
#
# One registration can back several extensions (submit + token issuance)
# hosted on the same API.
# =============================================================================

terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

variable "name" {
  description = "Display name prefix, e.g. Alice-PoC-TokenEnrichment -> TF.Demo.<name>.ExtensionAPI."
  type        = string
}

variable "api_host" {
  description = "Host name of the REST API (no scheme, no path), e.g. my-endpoint.free.beeceptor.com. Used in the identifier URI api://<api_host>/<client-id>."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+$", var.api_host))
    error_message = "api_host must be a bare host name, e.g. my-endpoint.free.beeceptor.com (no https://, no path). External-05: set profile_api_base_url in terraform.tfvars."
  }
}

locals {
  graph_app_id = "00000003-0000-0000-c000-000000000000"
  # Microsoft Graph application permission CustomAuthenticationExtension.Receive.Payload
  receive_payload_role_id = "214e810f-fda8-4fd7-a475-29461495eb00"
}

data "azuread_service_principal" "msgraph" {
  client_id = local.graph_app_id
}

resource "azuread_application" "this" {
  display_name     = "TF.Demo.${var.name}.ExtensionAPI"
  sign_in_audience = "AzureADMyOrg"

  api {
    requested_access_token_version = 2
  }

  # Shown under API permissions in the portal; the grant itself is the
  # azuread_app_role_assignment below.
  required_resource_access {
    resource_app_id = local.graph_app_id
    resource_access {
      id   = local.receive_payload_role_id
      type = "Role"
    }
  }

  # Managed by azuread_application_identifier_uri (it needs the client id).
  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_application_identifier_uri" "this" {
  application_id = azuread_application.this.id
  identifier_uri = "api://${var.api_host}/${azuread_application.this.client_id}"
}

resource "azuread_service_principal" "this" {
  client_id    = azuread_application.this.client_id
  use_existing = true
}

# Admin consent for CustomAuthenticationExtension.Receive.Payload.
# Needs AppRoleAssignment.ReadWrite.All on the deployer SP (External-00).
resource "azuread_app_role_assignment" "receive_payload" {
  app_role_id         = local.receive_payload_role_id
  principal_object_id = azuread_service_principal.this.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

output "client_id" {
  description = "Client ID of the extension API app registration (aud of the token Entra sends to your API)."
  value       = azuread_application.this.client_id
}

output "resource_id" {
  description = "Identifier URI api://<host>/<client-id> - authenticationConfiguration.resourceId of the custom extensions."
  value       = azuread_application_identifier_uri.this.identifier_uri
}

output "service_principal_object_id" {
  description = "Object ID of the extension API service principal."
  value       = azuread_service_principal.this.object_id
}

output "receive_payload_grant_id" {
  description = "ID of the CustomAuthenticationExtension.Receive.Payload grant (depend on it before creating extensions)."
  value       = azuread_app_role_assignment.receive_payload.id
}
