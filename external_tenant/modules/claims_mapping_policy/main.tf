# =============================================================================
# Module: claims_mapping_policy  (External-04 Step C, External-05)
# =============================================================================
# Selects which claims land in the token, and under which JWT name. Same as
# Enterprise app -> Single sign-on -> Attributes & Claims in the portal.
# Two kinds of source (source_type):
#   CustomClaimsProvider (default, External-05) - a claim returned by the
#     token-issuance custom extension (customClaimsProvider.<Claim>).
#   user (External-04) - a property of the user object. A custom user
#     attribute (extension_<appId>_<name>) is sent as ExtensionID, a built-in
#     property (e.g. givenname) as ID.
#
# Assigned per SERVICE PRINCIPAL, by token audience: the CLIENT's SP for the ID
# token, the API's SP for the access token. A service principal can have only
# ONE claims mapping policy. Each app must accept mapped claims
# (modules/sso_app and modules/api_definition set mapped_claims_enabled = true).
# Requires Policy.ReadWrite.ApplicationConfiguration (External-00).
# =============================================================================

terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

variable "display_name" {
  description = "Display name of the claims mapping policy."
  type        = string
}

variable "claims" {
  description = "source = claim name in the API response (case-sensitive, must be in the extension's token_claims) or, with source_type = \"user\", a user property / full extension_<appId>_<name> id; jwt_claim_type = claim name in the token."
  type = list(object({
    source         = string
    jwt_claim_type = string
    source_type    = optional(string, "CustomClaimsProvider")
  }))

  validation {
    condition     = alltrue([for c in var.claims : contains(["CustomClaimsProvider", "user"], c.source_type)])
    error_message = "source_type must be CustomClaimsProvider or user."
  }
}

variable "service_principal_object_ids" {
  description = "STATIC label => object ID of each service principal the policy is assigned to."
  type        = map(string)
}

locals {
  # A user-sourced extension_<appId>_<name> must be referenced as ExtensionID.
  is_extension = { for c in var.claims : c.source => c.source_type == "user" && startswith(c.source, "extension_") }
}

resource "azuread_claims_mapping_policy" "this" {
  display_name = var.display_name
  definition = [jsonencode({
    ClaimsMappingPolicy = {
      Version              = 1
      IncludeBasicClaimSet = "true"
      # Map, not object: ID and ExtensionID are mutually exclusive, null ones
      # are dropped. jsonencode sorts keys either way, so External-05's
      # definition is unchanged.
      ClaimsSchema = [for c in var.claims : { for k, v in {
        Source       = c.source_type
        ID           = local.is_extension[c.source] ? null : c.source
        ExtensionID  = local.is_extension[c.source] ? c.source : null
        JwtClaimType = c.jwt_claim_type
      } : k => v if v != null }]
    }
  })]
}

resource "azuread_service_principal_claims_mapping_policy_assignment" "this" {
  for_each = var.service_principal_object_ids

  claims_mapping_policy_id = azuread_claims_mapping_policy.this.id
  service_principal_id     = "/servicePrincipals/${each.value}"
}

output "id" {
  description = "ID of the claims mapping policy."
  value       = azuread_claims_mapping_policy.this.id
}
