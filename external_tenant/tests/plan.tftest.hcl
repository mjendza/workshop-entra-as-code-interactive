# Offline plan test — runs in CI with mocked providers (no tenant, no creds).
#   terraform init -backend=false && terraform test

mock_provider "azuread" {
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
}

mock_provider "msgraph" {}
# random is NOT mocked: it needs no credentials, and the starter config may
# not declare it (mocking an undeclared provider is an error).

# Replace workshop placeholders from terraform.tfvars with valid shapes.
variables {
  multitenant_client_id    = "99999999-9999-9999-9999-999999999999"
  deployment_unique_name   = "CiTest"
  tenant_default_domain    = "citest.onmicrosoft.com"
  native_signin_user_email = "ci.user@example.com"
  profile_api_base_url     = "https://citest.free.beeceptor.com"
}

run "plan" {
  command = plan
}
