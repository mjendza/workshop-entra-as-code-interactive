# Final-solution assertions — copied into experimental-workforce/tests/ by
# scripts/ci/validate.sh (final variant) next to plan.tftest.hcl, which provides
# the same mocks. Kept separate because the starter files have none of these
# resources/locals.

mock_provider "azuread" {
  mock_resource "azuread_group" {
    defaults = {
      id        = "/groups/11111111-1111-1111-1111-111111111111"
      object_id = "11111111-1111-1111-1111-111111111111"
    }
  }
}

mock_provider "msgraph" {
  mock_resource "msgraph_resource" {
    defaults = {
      id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"@odata.context\":\"https://graph.microsoft.com/beta/$metadata#x/$entity\",\"@odata.type\":\"#microsoft.graph.windows10CompliancePolicy\",\"id\":\"33333333-3333-3333-3333-333333333333\",\"displayName\":\"CI mock policy\",\"createdDateTime\":\"2026-01-01T00:00:00Z\",\"bitLockerEnabled@odata.type\":\"#Boolean\",\"bitLockerEnabled\":true,\"assignments\":[],\"#microsoft.graph.assign\":{\"title\":\"microsoft.graph.assign\"},\"scheduledActionsForRule\":{\"id\":\"44444444-4444-4444-4444-444444444444\",\"ruleName\":null,\"scheduledActionConfigurations\":[{\"id\":\"55555555-5555-5555-5555-555555555555\",\"actionType\":\"block\",\"gracePeriodHours\":12,\"notificationTemplateId\":\"00000000-0000-0000-0000-000000000000\",\"notificationMessageCCList\":[]}]}}"
    }
  }
}

variables {
  deployment_unique_name = "CiTest"
}

run "final_plan" {
  command = plan

  # --- 01 BYOD -------------------------------------------------------------
  assert {
    condition     = length(msgraph_resource.byod_app_protection) == 2 && length(msgraph_resource.byod_filter) == 2
    error_message = "Expected Android + iOS app protection policies and filters."
  }

  assert {
    condition = alltrue([
      for k, b in local.oib_byod_body :
      !contains(keys(b), "id") && !contains(keys(b), "assignments") && !contains(keys(b), "#microsoft.graph.assign")
      && !contains(keys(b), "bitLockerEnabled@odata.type") && contains(keys(b), "@odata.type")
    ])
    error_message = "OIB read-only keys / annotations were not stripped from the BYOD request bodies."
  }

  assert {
    condition     = msgraph_resource.byod_filter["ios"].body.rule == "(app.deviceManagementType -eq \"Unmanaged\")"
    error_message = "BYOD filter must target unmanaged devices (OIB prerequisite)."
  }

  assert {
    condition     = azuread_conditional_access_policy.byod_require_app_protection.state == "enabledForReportingButNotEnforced"
    error_message = "Conditional Access must start in report-only."
  }

  # --- 02 WINDOWS ----------------------------------------------------------
  assert {
    condition     = length(msgraph_resource.oib_windows) == 8
    error_message = "Expected the 8 curated Windows OIB policies."
  }

  assert {
    condition = alltrue([
      for k, b in local.oib_windows_body :
      length(b.scheduledActionsForRule[0].scheduledActionConfigurations) == 1
      && !contains(keys(b.scheduledActionsForRule[0].scheduledActionConfigurations[0]), "id")
    ])
    error_message = "scheduledActionsForRule must be rebuilt as an array without ids."
  }

  assert {
    condition     = msgraph_resource_action.oib_windows_assign["Win - OIB - CP - Device Health - U - BitLocker - v4.0"].body.assignments[0].target.deviceAndAppManagementAssignmentFilterType == "exclude"
    error_message = "Cloud PCs must be excluded from the BitLocker compliance policy (OIB W365 note)."
  }

  # --- 03 WINDOWS365 -------------------------------------------------------
  assert {
    condition     = length(msgraph_resource.oib_w365) == 3 && length(msgraph_resource.w365_provisioning) == 0
    error_message = "Expected 3 W365 OIB policies and no provisioning policy by default."
  }

  assert {
    condition     = msgraph_resource_action.oib_w365_assign["Win365 - OIB - Device Security - D - Resource Redirection - v1.0"].body.assignments[0].target["@odata.type"] == "#microsoft.graph.allDevicesAssignmentTarget"
    error_message = "W365 device (D) policies must target all devices with the Cloud PC filter."
  }
}
