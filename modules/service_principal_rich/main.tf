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
variable "use_certificate" {
  description = "Upload an X.509 public certificate as a credential on the Service Principal"
  type        = bool
  default     = false
}
variable "certificate_file" {
  description = "Certificate file name (located in the repo-root cert/ folder, .pem expected)"
  type        = string
  default     = "cert.pem"
}
variable "certificate_validity_months" {
  description = "Certificate validity in months from creation time"
  type        = number
  default     = 12
}

variable "permissions" {
  description = "List of additional required resource accesses. Each item contains a resource_app_id and a list of application (Role) permission IDs."
  type = list(object({
    resource_app_id = string
    permissions     = list(string)
  }))
  default = []
}

resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.ServicePrincipal"
  sign_in_audience = "AzureADMyOrg"
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
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
  dynamic "required_resource_access" {
    for_each = { for idx, p in var.permissions : idx => p }
    content {
      resource_app_id = required_resource_access.value.resource_app_id

      dynamic "resource_access" {
        for_each = required_resource_access.value.permissions
        content {
          id   = resource_access.value
          type = "Role"
        }
      }
    }
  }
}
resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
  use_existing                 = true
}

resource "time_static" "cert_created" {
  count = var.use_certificate ? 1 : 0
}

resource "azuread_application_certificate" "this_cert" {
  count          = var.use_certificate ? 1 : 0
  application_id = azuread_application.this.id
  type           = "AsymmetricX509Cert"
  value          = file("${path.module}/../../cert/${var.certificate_file}")
  start_date     = time_static.cert_created[0].rfc3339
  end_date       = timeadd(time_static.cert_created[0].rfc3339, "${var.certificate_validity_months * 30 * 24}h")
}

output "client_id" {
  value = azuread_application.this.client_id
}

output "object_id" {
  value = azuread_application.this.object_id
}
