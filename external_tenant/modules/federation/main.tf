terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
    msgraph = {
      source = "microsoft/msgraph"
    }
  }
}

variable "business_name" {
  description = "Business name"
  type        = string
}
variable "client_id" {
  description = "Client ID"
  type        = string
}
variable "tenant_id" {
  description = "Tenant ID"
  type        = string
}
variable "client_secret" {
  description = "Client Secret"
  type        = string
  sensitive = true
}

resource "msgraph_resource" "identity_providers_workforce_federation" {
  url         = "identity/identityProviders"
  api_version = "beta"
  body = {
    "@odata.type"     = "#microsoft.graph.oidcIdentityProvider"
    displayName       = "${var.business_name}-Workforce-Federation"
    clientId          = "${var.client_id}"
    issuer            = "https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration"
    responseType      = "code"
    scope             = "openid profile email"
    wellKnownEndpoint = "https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration"
    clientAuthentication = {
      clientSecret  = "${var.client_secret}"
      "@odata.type" = "#microsoft.graph.oidcClientSecretAuthentication"
    }
    inboundClaimMapping = {
      sub                   = "sub"
      name                  = "name"
      given_name            = "given_name"
      family_name           = "family_name"
      email                 = "email"
      email_verified        = "email_verified"
      phone_number          = "phone_number"
      phone_number_verified = "phone_number_verified"
      address = {
        street_address = "street_address"
        locality       = "locality"
        region         = "region"
        postal_code    = "postal_code"
        country        = "country"
      }
    }
  }
}

output "identity_provider_id" {
  value = msgraph_resource.identity_providers_workforce_federation.id
}