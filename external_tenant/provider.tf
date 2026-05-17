terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.7.0"
    }
  }
}

# =============================================================================
# Provider for the EXTERNAL (target) tenant — Tenant B
# =============================================================================
# This configuration runs against a DIFFERENT tenant than the repo root.
# Replace the three placeholders below with credentials of a Service Principal
# that exists in Tenant B and has either:
#   - Application Administrator, or
#   - Cloud Application Administrator
# directory role. Those roles are required to (a) create the multi-tenant app's
# Service Principal in Tenant B and (b) grant admin consent for Graph
# application permissions.
#
# NOTE: Environment variables (ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID)
# and Azure CLI auth are also supported by the azuread provider — see
# https://registry.terraform.io/providers/hashicorp/azuread/latest/docs#authentication
# =============================================================================
provider "azuread" {
  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}
