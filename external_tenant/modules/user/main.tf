# =============================================================================
# native_auth_test_user — a local account for External-01 native-auth SIGN-IN
# =============================================================================
# The External-01 sign-in E2E test needs an EXISTING user that signs in with an
# e-mail address and receives an OTP in that mailbox. The mailbox domain is an
# external (non-verified) domain, so this cannot be a normal `azuread_user`
# (whose userPrincipalName must be a verified tenant domain). Instead we create
# a local account with an `emailAddress` identity via the Microsoft Graph API
# (msgraph_resource), using the tenant's initial onmicrosoft.com domain as the
# identity issuer.
# =============================================================================

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

variable "email" {
  description = "E-mail address (emailAddress identity) the user signs in with via native-auth OTP."
  type        = string
}

variable "display_name" {
  description = "Display name for the sign-in test user."
  type        = string
  default     = "Native Auth SignIn Test User"
}

variable "password" {
  description = "Initial password for the local account. Native email-OTP sign-in never uses it, but Graph requires a passwordProfile when creating a local account."
  type        = string
  default     = "Aa1!Workshop-Native-External-01"
  sensitive   = true
}

variable "issuer" {
  description = "Issuer for the emailAddress identity. Must be the tenant's initial onmicrosoft.com domain."
  type        = string
}

resource "msgraph_resource" "user" {
  url         = "users"
  api_version = "v1.0"

  body = {
    accountEnabled = true
    displayName    = var.display_name
    identities = [
      {
        signInType       = "emailAddress"
        issuer           = var.issuer
        issuerAssignedId = var.email
      }
    ]
    passwordProfile = {
      forceChangePasswordNextSignIn = false
      password                      = var.password
    }
    passwordPolicies = "DisablePasswordExpiration"
  }

  response_export_values = {
    object_id = "id"
  }
}
