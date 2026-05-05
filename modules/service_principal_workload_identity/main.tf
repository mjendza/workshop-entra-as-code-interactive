

variable "graph_permissions" {
  description = "List of Graph API permissions"
  type        = list(string)
  default     = []
}
variable "business_name" {
  description = "Business name"
  type        = string
}
variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
variable "enable_workload_identity" {
  description = "Enable workload identity federation"
  type        = bool
}
variable "subject_identifier" {
  description = "Subject identifier for the federated credential"
  type        = string
}
variable "issuer_url" {
  description = "Issuer URL for the federated credential"
  type        = string
}

resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.ServicePrincipal"
  sign_in_audience = "AzureADMyOrg"
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }
  feature_tags {
    enterprise = true
    gallery    = true
  }
  required_resource_access {
    # Microsoft Graph
    resource_app_id = "00000003-0000-0000-c000-000000000000"
    dynamic "resource_access" {
      for_each = var.graph_permissions
      content {
        id   = resource_access.value
        type = "Role"
      }
    }
  }
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
}

resource "azuread_application_federated_identity_credential" "this" {
  count          = var.enable_workload_identity ? 1 : 0
  application_id = azuread_application.this.id
  display_name   = "TF.${var.deployment_env_name}.${var.business_name}.FederatedCredential"
  description    = "Workload Identity federation for ${var.business_name}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.issuer_url
  subject        = var.subject_identifier
}

output "application_id" {
  value = azuread_application.this.id
}

output "application_client_id" {
  value = azuread_application.this.client_id
}

output "service_principal_id" {
  value = azuread_service_principal.this.id
}
