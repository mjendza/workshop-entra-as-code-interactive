## Configure the Azure Active Directory Provider
provider "azuread" {

  # NOTE: Uses the same authentication as azuread provider
  # Can use environment variables, Azure CLI, or explicit credentials - for workshop purposes, we will use explicit credentials
  # See official docs: https://registry.terraform.io/providers/microsoft/msgraph/latest/docs

  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}

# Configure the Microsoft Graph Provider
# This provider is used for tenant-wide policies and settings
provider "msgraph" {
  # NOTE: Uses the same authentication as msgraph provider
  # Can use environment variables, Azure CLI, or explicit credentials - for workshop purposes, we will use explicit credentials
  # See official docs: https://registry.terraform.io/providers/microsoft/msgraph/latest/docs

  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}

## Configure the Verified ID Provider
provider "verifiedid" {
  # NOTE: Uses the same authentication as verifiedid provider
  # Can use environment variables, Azure CLI, or explicit credentials - for workshop purposes, we will use explicit credentials
  # See official docs: https://registry.terraform.io/providers/microsoft/verifiedid/latest/docs

  client_id     = ""
  client_secret = ""
  tenant_id     = ""
}