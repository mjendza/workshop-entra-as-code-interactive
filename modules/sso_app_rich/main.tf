variable "sign_in_audience" {
  description = "Sign in audience"
  type        = string
  default     = "AzureADMyOrg"
}
variable "use_certificate" {
  description = "Use certificate"
  type        = bool
  default     = false
}
variable "certificate_file" {
  description = "certificate file with extension (now tested with pem)"
  type        = string
  default     = "cert.pem"
}
variable "web_uri" {
  description = "List of Web URIs redirect"
  type        = list(string)
  default     = []
}
variable "spa_uri" {
  description = "List of Web URIs redirect"
  type        = list(string)
  default     = []
}
variable "graph_permissions" {
  description = "List of Graph API permissions for Role (application)"
  type        = list(string)
  default     = []
}
variable "graph_permissions_delegated" {
  description = "List of Graph API permissions for Scope (delegated)"
  type        = list(string)
  default     = []
}
variable "business_name" {
  description = "Business name"
  type        = string
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
variable "identifier_uris" {
  description = "List of identifier URIs"
  type        = list(string)
  default     = []
}
variable "oauth2_permission_scope_name" {
  description = "OAuth2 permission scope name"
  type        = string
  default     = ""
}
variable "certificate_validity_months" {
  description = "Certificate validity in months from creation time"
  type        = number
  default     = 12
}

variable deployment_env_name {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
resource "random_uuid" "oauth2_permission_scope_id" {
}

resource "random_uuid" "app_role_id" {
  for_each = toset(var.app_role_values)
}
variable "app_role_values" {
  description = "List of application role values to ensure uniqueness"
  type        = list(string)
  default     = []
}

resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.Application"
  sign_in_audience = var.sign_in_audience
  identifier_uris  = var.identifier_uris
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
    dynamic "oauth2_permission_scope" {
      for_each = var.oauth2_permission_scope_name != "" ? [1] : []
      content {
        admin_consent_description  = "Allow the application to access ${var.oauth2_permission_scope_name} on behalf of the signed-in user."
        admin_consent_display_name = "Access ${var.oauth2_permission_scope_name}"
        id                         = random_uuid.oauth2_permission_scope_id.result
        type                       = "User"
        user_consent_description   = "Allow the application to access ${var.oauth2_permission_scope_name} on your behalf."
        user_consent_display_name  = "Access ${var.oauth2_permission_scope_name}"
        value                      = var.oauth2_permission_scope_name
      }
    }
  }

  dynamic "web" {
    for_each = length(var.web_uri) > 0 ? [1] : []
    content {
      redirect_uris = var.web_uri
      implicit_grant {
        access_token_issuance_enabled = false
        id_token_issuance_enabled     = false
      }
    }
  }

  dynamic "single_page_application" {
    for_each = length(var.spa_uri) > 0 ? [1] : []
    content {
      redirect_uris = var.spa_uri
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
      for_each = var.graph_permissions_delegated
      content {
        id   = resource_access.value
        type = "Scope"
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

  dynamic "app_role" {
    for_each = toset(var.app_role_values)
    content {
      id                   = random_uuid.app_role_id[app_role.value].result
      allowed_member_types = ["User"]
      description          = "Role for ${app_role.value}"
      display_name         = app_role.value
      value                = app_role.value
    }
  }
}

resource "azuread_service_principal" "this_SP" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
  use_existing                 = true
  feature_tags {
    enterprise = true
    gallery    = false
  }
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
