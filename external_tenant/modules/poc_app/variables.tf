variable "name" {
  description = "Instance name, e.g. Alice-CustomerHelpdesk. Prefixes every display name: TF.Demo.<name>.API.API, TF.Demo.<name>.Spa.Application."
  type        = string
}

variable "spa_redirect_uris" {
  description = "SPA redirect URIs. Entra matches these exactly -- a trailing slash difference is a mismatch."
  type        = list(string)
}

variable "app_roles" {
  description = "App roles exposed by the API, keyed by role VALUE (what lands in the roles claim). See modules/api_definition."
  type = map(object({
    display_name         = string
    description          = string
    allowed_member_types = optional(list(string), ["User"])
  }))
  default = {
    "CustomerHelpdesk.Admin" = {
      display_name = "CustomerHelpdesk administrator"
      description  = "Administrative access to the CustomerHelpdesk application."
    }
  }
}

variable "require_mfa" {
  description = "OPTIONAL. Create a Conditional Access policy requiring MFA (Email OTP) for this SPA and API. Security defaults must be disabled in the tenant first."
  type        = bool
  default     = false
}

variable "mfa_policy_state" {
  description = "State of the optional require-MFA policy: enabled, enabledForReportingButNotEnforced (report-only) or disabled."
  type        = string
  default     = "enabled"
}
