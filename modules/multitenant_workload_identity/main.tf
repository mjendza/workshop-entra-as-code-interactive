# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "business_name" {
  description = "Business name used in resource display names"
  type        = string
}

variable "deployment_env_name" {
  description = "Deployment environment name prefix"
  type        = string
  default     = "Workshop"
}

variable "managed_identity_principal_id" {
  description = "Object (principal) ID of the user-assigned managed identity in the home tenant. Leave empty to skip FIC creation."
  type        = string
  default     = ""
}

variable "home_tenant_id" {
  description = "Tenant ID where the managed identity resides. If empty, derived from the current azuread provider context."
  type        = string
  default     = ""
}

variable "graph_permissions" {
  description = "List of Microsoft Graph application (Role) permission IDs to request"
  type        = list(string)
  default     = []
}

variable "use_certificate" {
  description = "Attach an X.509 certificate credential to the app for dev/test cross-tenant authentication"
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

variable "federated_identity_credentials" {
  description = "Additional Federated Identity Credentials (e.g. Kubernetes workload identity, GitHub Actions). Each entry creates a separate FIC on the app."
  type = list(object({
    display_name = string
    description  = optional(string, "")
    issuer       = string
    subject      = string
    audiences    = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

data "azuread_client_config" "current" {}

locals {
  tenant_id       = var.home_tenant_id != "" ? var.home_tenant_id : data.azuread_client_config.current.tenant_id
  create_fic      = var.managed_identity_principal_id != ""
  has_permissions = length(var.graph_permissions) > 0
}

# ---------------------------------------------------------------------------
# Multi-tenant App Registration
# ---------------------------------------------------------------------------

resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.MultiTenantApp"
  sign_in_audience = "AzureADMultipleOrgs"

  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }

  dynamic "required_resource_access" {
    for_each = local.has_permissions ? [1] : []
    content {
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
}

# ---------------------------------------------------------------------------
# Service Principal (home tenant)
# ---------------------------------------------------------------------------

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
}

# ---------------------------------------------------------------------------
# Federated Identity Credential — trusts the Managed Identity
# ---------------------------------------------------------------------------

resource "azuread_application_federated_identity_credential" "mi_fic" {
  count          = local.create_fic ? 1 : 0
  application_id = azuread_application.this.id
  display_name   = "TF.${var.deployment_env_name}.${var.business_name}.ManagedIdentityFIC"
  description    = "Cross-tenant FIC trusting managed identity ${var.managed_identity_principal_id}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://login.microsoftonline.com/${local.tenant_id}/v2.0"
  subject        = var.managed_identity_principal_id
}

# ---------------------------------------------------------------------------
# Additional Federated Identity Credentials (Kubernetes, GitHub Actions, etc.)
# ---------------------------------------------------------------------------

resource "azuread_application_federated_identity_credential" "additional_fic" {
  for_each       = { for idx, fic in var.federated_identity_credentials : fic.display_name => fic }
  application_id = azuread_application.this.id
  display_name   = each.value.display_name
  description    = each.value.description
  audiences      = each.value.audiences
  issuer         = each.value.issuer
  subject        = each.value.subject
}

# ---------------------------------------------------------------------------
# Certificate Credential (optional — for dev/test cross-tenant auth)
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "client_id" {
  description = "Application (client) ID of the multi-tenant app"
  value       = azuread_application.this.client_id
}

output "application_id" {
  description = "Object ID of the application registration"
  value       = azuread_application.this.id
}

output "service_principal_id" {
  description = "Object ID of the service principal in the home tenant"
  value       = azuread_service_principal.this.id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal (alias for service_principal_id)"
  value       = azuread_service_principal.this.object_id
}
