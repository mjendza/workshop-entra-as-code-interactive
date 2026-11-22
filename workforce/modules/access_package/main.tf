variable "business_name" {
  description = "Business name prefix to use for all resources"
  type        = string
}
variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
resource "azuread_group" "entraid_app_developers" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.EntraID.ApplicationDevelopers"
  security_enabled = true
  description      = "Group for developers who need Application Administrator access"

  lifecycle {
    prevent_destroy = false
  }
}

resource "azuread_access_package_catalog" "dev_catalog" {
  display_name = "TF.${var.deployment_env_name}.${var.business_name}.Developer.Catalog"
  description  = "Catalog for developer access packages"
}

resource "azuread_access_package" "app_admin_access" {
  display_name = "TF.${var.deployment_env_name}.${var.business_name}.ApplicationAdministrator.Package"
  description  = "Provides Application Administrator access for 6 months"
  catalog_id   = azuread_access_package_catalog.dev_catalog.id
}

resource "azuread_access_package_resource_catalog_association" "group_association" {
  catalog_id             = azuread_access_package_catalog.dev_catalog.id
  resource_origin_id     = azuread_group.entraid_app_developers.object_id
  resource_origin_system = "AadGroup"
}

resource "azuread_access_package_resource_package_association" "group_resource" {
  access_package_id               = azuread_access_package.app_admin_access.id
  catalog_resource_association_id = azuread_access_package_resource_catalog_association.group_association.id
}

resource "azuread_access_package_assignment_policy" "no_approval_policy" {
  access_package_id = azuread_access_package.app_admin_access.id
  display_name      = "TF.${var.deployment_env_name}.${var.business_name}.DeveloperAccessNoApproval"
  description       = "Self-service access for developers - no approval needed"
  duration_in_days  = 180 # 6 months validity

  requestor_settings {
    scope_type        = "AllExistingDirectoryMemberUsers"
    requests_accepted = true
  }

  assignment_review_settings {
    enabled                        = false
    review_frequency               = "halfyearly"
    duration_in_days               = 7
    review_type                    = "Self"
    access_review_timeout_behavior = "keepAccess"
  }
  extension_enabled = false
}

output "group_id" {
  value       = azuread_group.entraid_app_developers.id
  description = "ID of the created group"
}

output "access_package_id" {
  value       = azuread_access_package.app_admin_access.id
  description = "ID of the created access package"
}

output "access_package_catalog_id" {
  value       = azuread_access_package_catalog.dev_catalog.id
  description = "ID of the created access package catalog"
}

output "access_policy_id" {
  value       = azuread_access_package_assignment_policy.no_approval_policy.id
  description = "ID of the assignment policy"
}