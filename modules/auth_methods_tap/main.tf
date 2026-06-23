terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.3.0"
    }
  }
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "state" {
  description = "Whether the Temporary Access Pass method is enabled in the tenant. Possible values: enabled, disabled."
  type        = string
  default     = "enabled"
  validation {
    condition     = contains(["enabled", "disabled"], var.state)
    error_message = "state must be one of: enabled, disabled"
  }
}

variable "default_lifetime_in_minutes" {
  description = "Default lifetime in minutes for a Temporary Access Pass. Must be between minimumLifetimeInMinutes and maximumLifetimeInMinutes (10 - 43200)."
  type        = number
  default     = 60
  validation {
    condition     = var.default_lifetime_in_minutes >= 10 && var.default_lifetime_in_minutes <= 43200
    error_message = "default_lifetime_in_minutes must be between 10 and 43200 minutes (30 days)."
  }
}

variable "is_usable_once" {
  description = "If true, all passes in the tenant are restricted to one-time use. If false, passes can be one-time use or reusable."
  type        = bool
  default     = true
}

variable "include_target_group_id" {
  description = "The object ID of the group enabled to use TAP. Use the literal 'all_users' to include every user in the tenant."
  type        = string
  default     = "all_users"
}

# Configures the tenant-wide Temporary Access Pass authentication method policy.
# This is a singleton resource: a PATCH updates the existing policy rather than
# creating a new object. It follows the same msgraph_resource_action PATCH pattern
# proven by modules/tenant_security (Stage 7).
resource "msgraph_resource_action" "temporary_access_pass" {
  resource_url = "policies/authenticationMethodsPolicy/authenticationMethodConfigurations/temporaryAccessPass"
  method       = "PATCH"

  body = {
    "@odata.type"            = "#microsoft.graph.temporaryAccessPassAuthenticationMethodConfiguration"
    state                    = var.state
    defaultLifetimeInMinutes = var.default_lifetime_in_minutes
    isUsableOnce             = var.is_usable_once

    includeTargets = [
      {
        targetType = "group"
        id         = var.include_target_group_id
      }
    ]
  }
}
