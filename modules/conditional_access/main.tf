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
  description = "List of Client IDs for the applications to include in the policy"
  type        = list(string)
  default     = []
}
variable "trusted_locations_ip_ranges" {
  description = "List of IP ranges for trusted locations"
  type        = list(string)
  default     = null
}
resource "azuread_named_location" "trusted_locations_countries" {
  display_name = "TF.Workshop.${var.business_name}.Trusted Countries"
  country {
    countries_and_regions = [
      "DE",
      "US",
    ]
    include_unknown_countries_and_regions = false
  }
}
resource "azuread_named_location" "trusted_locations_ip_ranges" {
  display_name = "TF.${var.deployment_env_name}.${var.business_name}.TrustedLocationsByIpRanges"
  ip {
    ip_ranges = var.trusted_locations_ip_ranges
    trusted   = true
  }
}
resource "azuread_conditional_access_policy" "this" {
  display_name = "TF.${var.deployment_env_name}.${var.business_name}.Policy"
  #state        = "enabledForReportingButNotEnforced"
  state = "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = var.included_applications
    }

    users {
      included_users = ["all"]
    }

    locations {
      included_locations = ["All"]
      #https://github.com/hashicorp/terraform-provider-azuread/issues/1504
      excluded_locations = [element(split("/", azuread_named_location.trusted_locations_ip_ranges.id), 4), element(split("/", azuread_named_location.trusted_locations_countries.id), 4)]
      #excluded_locations = [azuread_named_location.trusted_locations_ip_ranges.id, azuread_named_location.trusted_locations_countries.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}