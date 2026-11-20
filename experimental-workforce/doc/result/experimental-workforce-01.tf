# =============================================================================
# experimental-workforce — Experimental-Workforce-01: BYOD - App Protection (OpenIntuneBaseline BYOD)
# =============================================================================
# See doc/experimental-workforce-01/README.md. Terraform loads every *.tf file in
# this directory, so splitting stages into files does not change resource
# addresses.
#
# Policy content comes from OpenIntuneBaseline (GPL-3.0):
#   https://github.com/SkipToTheEndpoint/OpenIntuneBaseline
# It is downloaded at plan time from a pinned tag - do not copy the JSON here.
# =============================================================================

# ---------------------------------------------------------------------------
# Download the OIB BYOD exports and strip read-only keys
# ---------------------------------------------------------------------------
locals {
  oib_byod_base = "${var.oib_repository_raw_base}/${var.oib_byod_tag}/BYOD/IntuneManagement/AppProtection"

  oib_byod_files = {
    android = "Android - OIB - App Protection - U - BYOD L2+ - v2.0.json"
    ios     = "iOS - OIB - App Protection - U - BYOD L2+ - v2.0.json"
  }

  oib_readonly_keys = [
    "id", "version", "createdDateTime", "lastModifiedDateTime", "isAssigned",
    "deployedAppCount", "apps", "assignments",
  ]
}

data "http" "oib_byod" {
  for_each = local.oib_byod_files
  url      = "${local.oib_byod_base}/${replace(replace(each.value, " ", "%20"), "+", "%2B")}" # names contain spaces and "+"
}

locals {
  oib_byod_body = {
    for k, v in data.http.oib_byod : k => {
      for key, value in jsondecode(v.response_body) : key => value
      if(!contains(local.oib_readonly_keys, key)
        && !startswith(key, "#")
      && (key == "@odata.type" || !strcontains(key, "@odata.")))
    }
  }
}

# ---------------------------------------------------------------------------
# Pilot group
# ---------------------------------------------------------------------------
resource "azuread_group" "byod_pilot" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-BYOD.Pilot"
  security_enabled = true
}

# ---------------------------------------------------------------------------
# Assignment filters (Managed apps, unmanaged devices)
# ---------------------------------------------------------------------------
locals {
  byod_filter_platforms = {
    android = "androidMobileApplicationManagement"
    ios     = "iOSMobileApplicationManagement"
  }
}

resource "msgraph_resource" "byod_filter" {
  for_each    = local.byod_filter_platforms
  api_version = "beta"
  url         = "deviceManagement/assignmentFilters"
  body = {
    displayName                    = "TF.Workshop.${var.deployment_unique_name}-BYOD.${each.key}.Unmanaged"
    description                    = "OIB BYOD prerequisite - unmanaged (not enrolled) devices only"
    platform                       = each.value
    assignmentFilterManagementType = "apps"
    rule                           = "(app.deviceManagementType -eq \"Unmanaged\")"
  }
}

# ---------------------------------------------------------------------------
# App protection policies from the OIB JSON
# ---------------------------------------------------------------------------
locals {
  byod_app_protection_collection = {
    android = "deviceAppManagement/androidManagedAppProtections"
    ios     = "deviceAppManagement/iosManagedAppProtections"
  }
}

resource "msgraph_resource" "byod_app_protection" {
  for_each    = local.byod_app_protection_collection
  api_version = "beta"
  url         = each.value
  body = merge(local.oib_byod_body[each.key], {
    description = "Deployed by Terraform from OpenIntuneBaseline ${var.oib_byod_tag} (GPL-3.0)"
  })
}

# ---------------------------------------------------------------------------
# Assign with the filter (assign action)
# ---------------------------------------------------------------------------
resource "msgraph_resource_action" "byod_assign" {
  for_each     = msgraph_resource.byod_app_protection
  api_version  = "beta"
  resource_url = "${local.byod_app_protection_collection[each.key]}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    assignments = [{
      target = {
        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
        groupId                                    = azuread_group.byod_pilot.object_id
        deviceAndAppManagementAssignmentFilterId   = msgraph_resource.byod_filter[each.key].id
        deviceAndAppManagementAssignmentFilterType = "include"
      }
    }]
  }
}

# ---------------------------------------------------------------------------
# Conditional Access (OIB prerequisites) - report-only by default
# ---------------------------------------------------------------------------
resource "azuread_conditional_access_policy" "byod_require_app_protection" {
  display_name = "TF.Workshop.${var.deployment_unique_name}-BYOD.RequireAppProtection"
  state        = var.byod_require_app_protection

  conditions {
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]

    users {
      included_groups = [azuread_group.byod_pilot.object_id]
      excluded_users  = var.ca_break_glass_object_ids
    }

    applications {
      included_applications = ["Office365"]
    }

    platforms {
      included_platforms = ["android", "iOS"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["compliantApplication"] # "Require app protection policy"
  }
}

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "TF.Workshop.${var.deployment_unique_name}-BlockLegacyAuth"
  state        = var.byod_require_app_protection

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    users {
      included_groups = [azuread_group.byod_pilot.object_id]
      excluded_users  = var.ca_break_glass_object_ids
    }

    applications {
      included_applications = ["All"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
