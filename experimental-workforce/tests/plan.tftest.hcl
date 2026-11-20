# Offline plan test — runs with mocked providers (no tenant, no creds, no network).
#   terraform init -backend=false && terraform test
# The OIB JSON download (data "http") is mocked too, so nothing is fetched from
# GitHub. The final-solution assertions live in doc/result/tests/ and are copied
# next to this file by scripts/ci/validate.sh (final variant).

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

# Minimal IntuneManagement-style export: read-only keys, annotations, an action
# marker and a compliance scheduledActionsForRule object (exported as an object,
# not an array) - enough to exercise the strip/rebuild logic.
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"@odata.context\":\"https://graph.microsoft.com/beta/$metadata#x/$entity\",\"@odata.type\":\"#microsoft.graph.windows10CompliancePolicy\",\"id\":\"33333333-3333-3333-3333-333333333333\",\"displayName\":\"CI mock policy\",\"createdDateTime\":\"2026-01-01T00:00:00Z\",\"bitLockerEnabled@odata.type\":\"#Boolean\",\"bitLockerEnabled\":true,\"assignments\":[],\"#microsoft.graph.assign\":{\"title\":\"microsoft.graph.assign\"},\"scheduledActionsForRule\":{\"id\":\"44444444-4444-4444-4444-444444444444\",\"ruleName\":null,\"scheduledActionConfigurations\":[{\"id\":\"55555555-5555-5555-5555-555555555555\",\"actionType\":\"block\",\"gracePeriodHours\":12,\"notificationTemplateId\":\"00000000-0000-0000-0000-000000000000\",\"notificationMessageCCList\":[]}]}}"
    }
  }
}

# Replace workshop placeholders from terraform.tfvars with valid shapes.
variables {
  deployment_unique_name = "CiTest"
}

run "plan" {
  command = plan
}
