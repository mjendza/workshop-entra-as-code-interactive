variable "business_name" {
  description = "Business name used in the application display name (TF.Demo.<business_name>.API)"
  type        = string
}

variable "identifier_uri" {
  description = <<-EOT
    Identifier URI of the API. Leave null (the default) to use api://<client-id>,
    which is what a client requests scopes against as api://<client-id>/<scope>.

    Set it explicitly to use a vanity URI instead, e.g. api://contoso.com/PoC.
    A vanity URI requires the domain to be verified on the tenant; api://<client-id>
    never does, which is why it is the default.
  EOT
  type        = string
  default     = null
}

variable "scopes" {
  description = <<-EOT
    Delegated scopes exposed by this API, keyed by scope value (the part after the
    identifier URI). Full scope URI is <identifier_uri>/<key>.

    consent_type: "User" lets an end user consent, "Admin" requires an administrator.
    Prefer "Admin" together with a Terraform-managed grant on the client -- that way
    the consent happens at apply time and no user ever sees a consent prompt.
  EOT
  type = map(object({
    display_name = string
    description  = string
    consent_type = optional(string, "User")
  }))

  validation {
    condition     = alltrue([for s in var.scopes : contains(["Admin", "User"], s.consent_type)])
    error_message = "Each scope consent_type must be Admin or User."
  }
}

variable "app_roles" {
  description = <<-EOT
    App roles exposed by this API, keyed by role VALUE.

    The key is the string that lands in the `roles` claim of the access token and
    that the API matches on, so the keys are part of the API's contract. Renaming
    one is a breaking change even though nothing in Terraform complains.

    allowed_member_types: ["User"] covers both users and groups -- Entra has no
    separate "Group" member type. Use ["Application"] for app-only (client
    credentials) roles, or both.
  EOT
  type = map(object({
    display_name         = string
    description          = string
    allowed_member_types = optional(list(string), ["User"])
  }))
  default = {}

  validation {
    condition = alltrue([
      for r in var.app_roles :
      length(r.allowed_member_types) > 0 &&
      alltrue([for t in r.allowed_member_types : contains(["User", "Application"], t)])
    ])
    error_message = "Each app role allowed_member_types must be a non-empty subset of [\"User\", \"Application\"]."
  }
}
