# Offline plan test — runs in CI with mocked providers (no tenant, no creds).
# Catches what `terraform validate` cannot: variable validation rules,
# count/for_each errors, module wiring, provider-side argument validation.
#   terraform init -backend=false && terraform test

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
      object_id = "22222222-2222-2222-2222-222222222222"
      client_id = "33333333-3333-3333-3333-333333333333"
    }
  }
  mock_data "azuread_service_principal" {
    defaults = {
      object_id = "44444444-4444-4444-4444-444444444444"
      client_id = "00000003-0000-0000-c000-000000000000"
    }
  }
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/55555555-5555-5555-5555-555555555555"
      object_id = "55555555-5555-5555-5555-555555555555"
      client_id = "66666666-6666-6666-6666-666666666666"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = {
      id        = "/servicePrincipals/77777777-7777-7777-7777-777777777777"
      object_id = "77777777-7777-7777-7777-777777777777"
      client_id = "66666666-6666-6666-6666-666666666666"
    }
  }
  mock_resource "azuread_group" {
    defaults = {
      id        = "/groups/88888888-8888-8888-8888-888888888888"
      object_id = "88888888-8888-8888-8888-888888888888"
    }
  }
}

mock_provider "msgraph" {}
# random/time are NOT mocked: they need no credentials, and the starter
# config may not declare them (mocking an undeclared provider is an error).

variables {
  deployment_unique_name = "CiTest"
}

run "plan" {
  command = plan
}
