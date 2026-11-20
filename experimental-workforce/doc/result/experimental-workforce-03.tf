# =============================================================================
# experimental-workforce — Experimental-Workforce-03: WINDOWS365 - Cloud PC add-on (OpenIntuneBaseline WINDOWS365)
# =============================================================================
# See doc/experimental-workforce-03/README.md. Terraform loads every *.tf file in
# this directory, so splitting stages into files does not change resource
# addresses.
#
# Policy content comes from OpenIntuneBaseline (GPL-3.0):
#   https://github.com/SkipToTheEndpoint/OpenIntuneBaseline
# It is downloaded at plan time from a pinned tag - do not copy the JSON here.
# =============================================================================

# ---------------------------------------------------------------------------
# Groups and the Cloud PC filter
# ---------------------------------------------------------------------------
resource "azuread_group" "w365_users" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-W365.Users"
  security_enabled = true
}

resource "msgraph_resource" "w365_filter" {
  api_version = "beta"
  url         = "deviceManagement/assignmentFilters"
  body = {
    displayName                    = "TF.Workshop.${var.deployment_unique_name}-W365.CloudPCs"
    description                    = "Windows 365 Cloud PCs (OIB W365 exclusions)"
    platform                       = "windows10AndLater"
    assignmentFilterManagementType = "devices"
    rule                           = "(device.model -startsWith \"Cloud PC\")"
  }
}

# ---------------------------------------------------------------------------
# W365 policies
# ---------------------------------------------------------------------------
locals {
  oib_w365_base = "${var.oib_repository_raw_base}/${var.oib_windows365_tag}/WINDOWS365/IntuneManagement"

  oib_w365_selected = {
    "Win365 - OIB - Device Security - D - Connectivity Settings - v1.0" = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies" }
    "Win365 - OIB - Device Security - D - Resource Redirection - v1.0"  = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies" }
    "Win365 - OIB - Compliance - U - Device Health - v1.0"              = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies" }
  }
}

data "http" "oib_w365" {
  for_each = local.oib_w365_selected
  url      = "${local.oib_w365_base}/${each.value.folder}/${replace(each.key, " ", "%20")}.json"
}

locals {
  oib_w365_raw = { for k, v in data.http.oib_w365 : k => jsondecode(v.response_body) }

  # Same strip/rebuild as local.oib_windows_body (Experimental-Workforce-02)
  oib_w365_body = {
    for k, raw in local.oib_w365_raw : k => merge(
      {
        for key, value in raw : key => value
        if(!contains(local.oib_windows_readonly_keys, key)
          && key != "scheduledActionsForRule"
          && !startswith(key, "#")
        && (key == "@odata.type" || !strcontains(key, "@odata.")))
      },
      {
        for _ in(can(raw.scheduledActionsForRule) ? ["x"] : []) : "scheduledActionsForRule" => [{
          ruleName = "PasswordRequired"
          scheduledActionConfigurations = [
            for a in try(raw.scheduledActionsForRule[0], raw.scheduledActionsForRule).scheduledActionConfigurations : {
              actionType                = a.actionType
              gracePeriodHours          = a.gracePeriodHours
              notificationTemplateId    = a.notificationTemplateId
              notificationMessageCCList = a.notificationMessageCCList
            }
          ]
        }]
      }
    )
  }
}

resource "msgraph_resource" "oib_w365" {
  for_each    = local.oib_w365_selected
  api_version = "beta"
  url         = each.value.collection
  body        = local.oib_w365_body[each.key]
}

# ---------------------------------------------------------------------------
# Assign to Cloud PCs only: "D" policies -> all devices, "U" -> W365 users,
# both with the Cloud PC filter in include mode
# ---------------------------------------------------------------------------
locals {
  # Looked up by key, so the two target shapes don't need a common type
  w365_assignment_targets = {
    devices = {
      "@odata.type"                              = "#microsoft.graph.allDevicesAssignmentTarget"
      deviceAndAppManagementAssignmentFilterId   = msgraph_resource.w365_filter.id
      deviceAndAppManagementAssignmentFilterType = "include"
    }
    users = {
      "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
      groupId                                    = azuread_group.w365_users.object_id
      deviceAndAppManagementAssignmentFilterId   = msgraph_resource.w365_filter.id
      deviceAndAppManagementAssignmentFilterType = "include"
    }
  }
}

resource "msgraph_resource_action" "oib_w365_assign" {
  for_each     = msgraph_resource.oib_w365
  api_version  = "beta"
  resource_url = "${local.oib_w365_selected[each.key].collection}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    assignments = [{
      target = local.w365_assignment_targets[strcontains(each.key, " - D - ") ? "devices" : "users"]
    }]
  }
}

# ---------------------------------------------------------------------------
# (Optional) Provisioning policy matching the OIB use-case
# ---------------------------------------------------------------------------
resource "msgraph_resource" "w365_provisioning" {
  count       = var.w365_create_provisioning_policy ? 1 : 0
  api_version = "beta"
  url         = "deviceManagement/virtualEndpoint/provisioningPolicies"
  body = {
    displayName        = "TF.Workshop.${var.deployment_unique_name}-W365.OIB"
    description        = "Entra joined, Microsoft hosted network, SSO - OIB W365 use-case"
    provisioningType   = "dedicated"
    imageType          = "gallery"
    imageId            = var.w365_gallery_image_id
    enableSingleSignOn = true
    domainJoinConfigurations = [{
      domainJoinType = "azureADJoin"
      regionGroup    = "europeUnion"
      regionName     = "automatic"
    }]
    windowsSetting = { locale = "en-US" }
  }

  lifecycle {
    precondition {
      condition     = var.w365_gallery_image_id != ""
      error_message = "Set w365_gallery_image_id (GET deviceManagement/virtualEndpoint/galleryImages) when w365_create_provisioning_policy = true."
    }
  }
}
