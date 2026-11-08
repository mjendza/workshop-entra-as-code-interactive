variable "business_name" {
  description = "Business name used in the policy display name (TF.Demo.<business_name>.RequireMFA)"
  type        = string
}

variable "app_client_ids" {
  description = "Client IDs (appId) of the applications the policy targets. Include both the SPA and the API it calls: CA is evaluated against the resource a token is issued for."
  type        = list(string)
}

variable "policy_state" {
  description = "enabled, enabledForReportingButNotEnforced (report-only) or disabled"
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.policy_state)
    error_message = "policy_state must be enabled, enabledForReportingButNotEnforced or disabled."
  }
}
