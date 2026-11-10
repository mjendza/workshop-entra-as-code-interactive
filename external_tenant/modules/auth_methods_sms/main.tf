# =============================================================================
# Module: auth_methods_sms  (External-03)
# =============================================================================
# Enables SMS (text message) as an authentication method in the External ID
# tenant, so customers can register a phone number and use an SMS code as the
# SECOND factor when Conditional Access requires MFA.
#
# Why SMS: when the user flow's PRIMARY method is the email one-time passcode,
# Email OTP cannot also count as the second factor -- SMS is the only other MFA
# method External ID offers to customers.
#
# This is a tenant-wide SINGLETON: a PATCH updates the existing policy instead
# of creating an object (same msgraph_resource_action PATCH pattern as
# modules/auth_methods_tap, Stage 19). `terraform destroy` only removes it from
# state -- it does NOT switch SMS off again. Set state = "disabled" and apply
# to turn it off.
#
# Prerequisites (see doc/external-03/README.md):
#   - deployer SP: Policy.ReadWrite.AuthenticationMethod (External-00)
#   - SMS in External ID is a paid add-on: link the tenant to an Azure
#     subscription (billing), otherwise no SMS is sent.
# =============================================================================

terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.4.0"
    }
  }
}

variable "state" {
  description = "Whether the SMS authentication method is enabled in the tenant: enabled or disabled."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.state)
    error_message = "state must be enabled or disabled."
  }
}

variable "include_target_group_id" {
  description = "Object ID of the group allowed to use SMS. The literal 'all_users' includes every user in the tenant."
  type        = string
  default     = "all_users"
}

resource "msgraph_resource_action" "sms" {
  resource_url = "policies/authenticationMethodsPolicy/authenticationMethodConfigurations/Sms"
  method       = "PATCH"

  body = {
    "@odata.type" = "#microsoft.graph.smsAuthenticationMethodConfiguration"
    state         = var.state

    includeTargets = [
      {
        targetType = "group"
        id         = var.include_target_group_id
        # SMS is a second factor only - never a primary (passwordless) sign-in.
        isUsableForSignIn = false
      }
    ]
  }
}

output "state" {
  description = "State applied to the SMS authentication method."
  value       = var.state
}
