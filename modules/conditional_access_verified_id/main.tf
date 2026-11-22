terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.3.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.3.0"
    }
  }
}

variable "business_name" {
  description = "Business name"
  type        = string
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "included_applications" {
  description = "List of Client IDs (appId) of the applications protected by the identity verification step-up."
  type        = list(string)
}

variable "pilot_member_object_ids" {
  description = "Object IDs of users added to the pilot group. Only members of this group are challenged for a Verified ID. Use the same group as the scope of your identity verification profile."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.pilot_member_object_ids : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))])
    error_message = "pilot_member_object_ids must contain user object IDs (UUIDs). Replace any placeholder values."
  }
}

variable "excluded_user_ids" {
  description = "Object IDs of users always excluded from the policy (e.g. emergency access / break-glass accounts)."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.excluded_user_ids : can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))])
    error_message = "excluded_user_ids must contain user object IDs (UUIDs). Replace any placeholder values."
  }
}

variable "state" {
  description = "Policy state. Report-only mode does NOT trigger identity verification, so 'enabled' is required to see the step-up. Possible values: enabled, disabled, enabledForReportingButNotEnforced."
  type        = string
  default     = "enabled"
  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.state)
    error_message = "state must be one of: enabled, disabled, enabledForReportingButNotEnforced"
  }
}

variable "grant_control" {
  description = "Graph builtInControls value for 'Require identity verification' (preview). Not yet listed in the official Graph enum docs - confirm it by GET-ing a portal-created policy (see Stage 20 README)."
  type        = string
  default     = "verifiedID"
}

# Pilot group - scope for BOTH the Conditional Access policy (here) and the
# identity verification profile (configured manually in the portal, because the
# verifiedIdProfile Graph API supports delegated permissions only).
resource "azuread_group" "pilot" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.Pilot"
  description      = "Pilot users required to present a Verified ID (high assurance step-up)."
  security_enabled = true
  members          = var.pilot_member_object_ids
}

# The azuread provider validates builtInControls against a fixed enum that does
# not contain the identity verification control yet, so the policy is created
# through the raw Microsoft Graph beta endpoint with the msgraph provider.
resource "msgraph_resource" "policy" {
  url         = "identity/conditionalAccess/policies"
  api_version = "beta"

  body = {
    displayName = "TF.${var.deployment_env_name}.${var.business_name}.Policy"
    state       = var.state

    conditions = {
      # Legacy client types are NOT supported for identity verification step-up
      # and make the flow fail - select browser + modern clients only.
      clientAppTypes = ["browser", "mobileAppsAndDesktopClients"]

      applications = {
        includeApplications = var.included_applications
      }

      users = {
        includeGroups = [azuread_group.pilot.object_id]
        excludeUsers  = var.excluded_user_ids
      }
    }

    grantControls = {
      operator        = "OR"
      builtInControls = [var.grant_control]
    }
  }

  response_export_values = {
    id = "id"
  }

  lifecycle {
    # Graph returns preview enum members as "unknownFutureValue" unless the
    # "Prefer: include-unknown-enum-members" header is sent, which would show a
    # permanent diff on builtInControls. To change the policy later, use:
    #   terraform apply -replace='module.<name>.msgraph_resource.policy'
    ignore_changes = [body]
  }
}

output "policy_id" {
  value = msgraph_resource.policy.output.id
}

output "pilot_group_id" {
  value = azuread_group.pilot.object_id
}
