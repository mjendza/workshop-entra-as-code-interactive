variable "web_uri" {
  description = "List of Web URIs redirect"
  type        = list(string)
  default     = []
}

variable "graph_permissions" {
  description = "List of Graph API permissions for Role"
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
variable "graph_permissions_basic" {
  description = "List of Graph API permissions for Scope"
  type        = list(string)
  ###scope
  default = [
    #User.Read (sign-in and read user profile)
    "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
    #email
    "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0",
    #offline_access
    "7427e0e9-2fba-42fe-b0c0-848c9e6a8182",
    #openid
    "37f7f235-527c-4136-accd-4a02d197296e",
    #profile
    "14dad69e-099b-42c9-810b-d002981feec1"
  ]
}
resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.Application"
  sign_in_audience = "AzureADMyOrg"
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }
  web {
    redirect_uris = var.web_uri

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
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
    dynamic "resource_access" {
      for_each = var.graph_permissions_basic
      content {
        id   = resource_access.value
        type = "Scope"
      }
    }
  }
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
}

output "client_id" {
  value = azuread_application.this.client_id
}