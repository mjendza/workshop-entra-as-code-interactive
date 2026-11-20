# =============================================================================
# Module: custom_auth_extension  (External-05)
# =============================================================================
# ONE custom authentication extension (Graph beta
# identity/customAuthenticationExtensions): "when event X happens, POST the
# payload to target_url, authenticated with a token for resource_id".
#
#   event = "attribute_collection_submit" -> onAttributeCollectionSubmitCustomExtension
#           The customer pressed Continue on the sign-up page. Attach it to a
#           user flow (modules/user_flow, attribute_collection_submit_extension_id),
#           like the portal's "When a user submits their information".
#   event = "token_issuance_start"        -> onTokenIssuanceStartCustomExtension
#           A token is about to be issued. Set listener_app_client_ids to create
#           the onTokenIssuanceStartListener for those applications and list the
#           claim names your API returns in token_claims.
#
# Requires CustomAuthenticationExtension.ReadWrite.All and
# EventListener.ReadWrite.All on the deployer SP (External-00).
# =============================================================================

terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.4.0"
    }
  }
}

variable "event" {
  description = "attribute_collection_submit | token_issuance_start"
  type        = string

  validation {
    condition     = contains(["attribute_collection_submit", "token_issuance_start"], var.event)
    error_message = "event must be attribute_collection_submit or token_issuance_start."
  }
}

variable "display_name" {
  description = "Display name of the custom authentication extension."
  type        = string
}

variable "description" {
  description = "Description of the custom authentication extension."
  type        = string
  default     = ""
}

variable "target_url" {
  description = "HTTPS endpoint Entra POSTs the event payload to."
  type        = string

  validation {
    condition     = startswith(var.target_url, "https://")
    error_message = "target_url must be an https:// URL. External-05: set profile_api_base_url in terraform.tfvars."
  }
}

variable "resource_id" {
  description = "Identifier URI of the app registration representing the API (modules/auth_extension_api resource_id)."
  type        = string
}

variable "timeout_ms" {
  description = "How long Entra waits for the API, 250-2000 ms. Sign-up / sign-in fails when it is exceeded."
  type        = number
  default     = 2000

  validation {
    condition     = var.timeout_ms >= 250 && var.timeout_ms <= 2000
    error_message = "timeout_ms must be between 250 and 2000."
  }
}

variable "maximum_retries" {
  description = "Retries after a timeout or 5xx: 0 or 1."
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1], var.maximum_retries)
    error_message = "maximum_retries must be 0 or 1."
  }
}

variable "token_claims" {
  description = "token_issuance_start only: claim names the API returns in provideClaimsForToken (case-sensitive). Claims not listed here are dropped."
  type        = list(string)
  default     = []
}

variable "listener_app_client_ids" {
  description = "token_issuance_start only: STATIC label => client ID of the apps whose tokens are enriched. Include the CLIENT (ID token) and the API (access token). Fixed at create time - changing it needs -replace on the listener."
  type        = map(string)
  default     = {}
}

variable "listener_priority" {
  description = "token_issuance_start only: listener priority, 0-1000."
  type        = number
  default     = 500
}

locals {
  is_token = var.event == "token_issuance_start"

  odata_type = local.is_token ? "#microsoft.graph.onTokenIssuanceStartCustomExtension" : "#microsoft.graph.onAttributeCollectionSubmitCustomExtension"

  common_body = {
    "@odata.type" = local.odata_type
    displayName   = var.display_name
    description   = var.description
    endpointConfiguration = {
      "@odata.type" = "#microsoft.graph.httpRequestEndpoint"
      targetUrl     = var.target_url
    }
    authenticationConfiguration = {
      "@odata.type" = "#microsoft.graph.azureAdTokenAuthentication"
      resourceId    = var.resource_id
    }
    clientConfiguration = {
      timeoutInMilliseconds = var.timeout_ms
      maximumRetries        = var.maximum_retries
    }
  }

  # Only the token-issuance extension has claimsForTokenConfiguration.
  token_body = local.is_token ? {
    claimsForTokenConfiguration = [for c in var.token_claims : { claimIdInApiResponse = c }]
  } : {}
}

resource "msgraph_resource" "this" {
  url         = "identity/customAuthenticationExtensions"
  api_version = "beta"
  body        = merge(local.common_body, local.token_body)
}

# Token issuance is wired per APPLICATION with a listener (a user flow has no
# token-issuance step). The attribute-collection-submit extension is wired on
# the user flow instead (modules/user_flow).
resource "msgraph_resource" "listener" {
  count = local.is_token && length(var.listener_app_client_ids) > 0 ? 1 : 0

  url         = "identity/authenticationEventListeners"
  api_version = "beta"
  body = {
    "@odata.type" = "#microsoft.graph.onTokenIssuanceStartListener"
    priority      = var.listener_priority
    conditions = {
      applications = {
        includeAllApplications = false
        includeApplications    = [for k in sort(keys(var.listener_app_client_ids)) : { appId = var.listener_app_client_ids[k] }]
      }
    }
    handler = {
      "@odata.type"   = "#microsoft.graph.onTokenIssuanceStartCustomExtensionHandler"
      customExtension = { id = msgraph_resource.this.id }
    }
  }
}

output "id" {
  description = "Object ID of the custom authentication extension."
  value       = msgraph_resource.this.id
}

output "listener_id" {
  description = "ID of the onTokenIssuanceStartListener, or null."
  value       = one(msgraph_resource.listener[*].id)
}
