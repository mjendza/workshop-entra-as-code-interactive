# Offline plan test — runs in CI with mocked providers (no tenant, no creds).
#   terraform init -backend=false && terraform test

mock_provider "verifiedid" {
  mock_data "verifiedid_resource" {
    defaults = {
      output = {
        value = [{ id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" }]
      }
    }
  }
}

variables {
  deployment_unique_name = "CiTest"
}

run "plan" {
  command = plan
}
