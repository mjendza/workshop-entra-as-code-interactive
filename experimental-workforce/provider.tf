terraform {
  required_version = ">= 1.7" # mock_provider in tests/ needs 1.7+

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.7.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "~> 0.6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

# =============================================================================
# Provider for the EXPERIMENTAL Workforce (Intune) path
# =============================================================================
# This root is independent of the repo root and of external_tenant/. It runs
# against a Workforce tenant WITH an active Intune license, using a dedicated
# Service Principal (see doc/experimental-workforce-01 "Prerequisites").
#
# - azuread : groups + Conditional Access
# - msgraph : Intune objects (app protection, assignment filters, settings
#             catalog, compliance, Windows 365) - most of them are Graph beta
# - http    : downloads the OpenIntuneBaseline (GPL-3.0) policy JSON at plan
#             time from a pinned release tag - the files are NOT vendored here
#
# NOTE: Environment variables (ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID)
# and Azure CLI auth are also supported by the azuread provider.
# =============================================================================
provider "azuread" {
  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}

provider "msgraph" {
  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}
