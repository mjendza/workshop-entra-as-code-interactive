# =============================================================================
# experimental-workforce — Experimental-Workforce-02: WINDOWS - Entra joined Windows 11 (OpenIntuneBaseline WINDOWS)
# =============================================================================
# See doc/experimental-workforce-02/README.md. Terraform loads every *.tf file in
# this directory, so splitting stages into files does not change resource
# addresses.
#
# Policy content comes from OpenIntuneBaseline (GPL-3.0):
#   https://github.com/SkipToTheEndpoint/OpenIntuneBaseline
# It is downloaded at plan time from a pinned tag - do not copy the JSON here.
# =============================================================================

# ---------------------------------------------------------------------------
# Selected policies (extend from WINDOWS/PolicyManifest.json)
# ---------------------------------------------------------------------------
locals {
  oib_windows_base = "${var.oib_repository_raw_base}/${var.oib_windows_tag}/WINDOWS/IntuneManagement"

  oib_windows_selected = {
    "Win - OIB - CP - Device Health - U - BitLocker - v4.0"                         = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - CP - Device Health - U - SecureBoot - v4.0"                        = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - CP - Device Security - U - Firewall - v4.0"                        = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - WUfB - Ring 1 - Pilot - v3.0"                                      = { folder = "UpdatePolicies", collection = "deviceManagement/deviceConfigurations", assign_to = "devices" }
    "Win - OIB - ES - Windows LAPS - D - LAPS Configuration - v4.0"                 = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - ES - Windows Firewall - D - Firewall Configuration - v3.1"         = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - ES - Attack Surface Reduction - D - ASR Rules (Audit Mode) - v3.1" = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - SC - Microsoft Edge - D - Security - v4.0"                         = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
  }

  oib_windows_readonly_keys = [
    "id", "version", "createdDateTime", "lastModifiedDateTime", "assignments", "settingCount",
    "creationSource", "priorityMetaData", "supportsScopeTags", "isAssigned",
  ]
}

data "http" "oib_windows" {
  for_each = local.oib_windows_selected
  url      = "${local.oib_windows_base}/${each.value.folder}/${replace(replace(each.key, " ", "%20"), "+", "%2B")}.json"
}

locals {
  oib_windows_raw = { for k, v in data.http.oib_windows : k => jsondecode(v.response_body) }

  oib_windows_body = {
    for k, raw in local.oib_windows_raw : k => merge(
      {
        for key, value in raw : key => value
        if(!contains(local.oib_windows_readonly_keys, key)
          && key != "scheduledActionsForRule"
          && !startswith(key, "#")
        && (key == "@odata.type" || !strcontains(key, "@odata.")))
      },
      # Compliance only: rebuild "Actions for noncompliance" without ids/links.
      # A for expression (not ?:) so "with" and "without" need no common type.
      {
        for _ in(can(raw.scheduledActionsForRule) ? ["x"] : []) : "scheduledActionsForRule" => [{
          ruleName = "PasswordRequired"
          scheduledActionConfigurations = [
            # IntuneManagement exports a single object here (not an array) - try() covers both
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

# ---------------------------------------------------------------------------
# Pilot groups (OIB "D" = devices, "U" = users)
# ---------------------------------------------------------------------------
resource "azuread_group" "windows_pilot_devices" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-Windows.Pilot.Devices"
  security_enabled = true
}

resource "azuread_group" "windows_pilot_users" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-Windows.Pilot.Users"
  security_enabled = true
}

# ---------------------------------------------------------------------------
# Policies
# ---------------------------------------------------------------------------
resource "msgraph_resource" "oib_windows" {
  for_each    = local.oib_windows_selected
  api_version = "beta"
  url         = each.value.collection
  body        = local.oib_windows_body[each.key]
}

# ---------------------------------------------------------------------------
# Assignments - Cloud PCs are excluded from BitLocker / Device Health
# (Experimental-Workforce-03 adds msgraph_resource.w365_filter)
# ---------------------------------------------------------------------------
locals {
  w365_excluded_windows_policies = [
    "Win - OIB - CP - Device Health - U - BitLocker - v4.0",
    "Win - OIB - ES - Encryption - D - BitLocker (OS Disk) - v3.7",
  ]
}

resource "msgraph_resource_action" "oib_windows_assign" {
  for_each     = msgraph_resource.oib_windows
  api_version  = "beta"
  resource_url = "${local.oib_windows_selected[each.key].collection}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    assignments = [{
      target = {
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId = (local.oib_windows_selected[each.key].assign_to == "devices"
          ? azuread_group.windows_pilot_devices.object_id
        : azuread_group.windows_pilot_users.object_id)
        deviceAndAppManagementAssignmentFilterId   = contains(local.w365_excluded_windows_policies, each.key) ? msgraph_resource.w365_filter.id : null
        deviceAndAppManagementAssignmentFilterType = contains(local.w365_excluded_windows_policies, each.key) ? "exclude" : "none"
      }
    }]
  }
}
