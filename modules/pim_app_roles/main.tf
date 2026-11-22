terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
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

variable "spa_uri" {
  description = "SPA redirect URIs (PKCE) used to test the roles claim, e.g. OidcDebugger."
  type        = list(string)
  default     = ["https://oidcdebugger.com/debug"]
}

variable "oidc_debugger_url" {
  description = "OIDC debugger page used to build the oidc_debugger_link output (?data=<base64 JSON>)."
  type        = string
  default     = "https://tenant.factorlabs.pl/oidcdebugger"
}

variable "app_role_values" {
  description = "App role values defined on the application. PIM for app roles manages assignments to these roles; it doesn't define them."
  type        = list(string)
  default     = ["reader", "operator", "admin"]
}

variable "eligible_member_object_ids" {
  description = "Object IDs of users added to the group that receives the PIM eligible app role assignment."
  type        = list(string)
  default     = []
}

variable "standing_role_value" {
  description = "Optional app role value assigned to the group as a standing (permanent active) assignment managed by Terraform. Leave empty to skip. Never use the privileged role here, it would bypass PIM."
  type        = string
  default     = ""
  validation {
    condition     = var.standing_role_value == "" || contains(var.app_role_values, var.standing_role_value)
    error_message = "standing_role_value must be empty or one of app_role_values."
  }
}

resource "random_uuid" "app_role_id" {
  for_each = toset(var.app_role_values)
}

resource "azuread_application" "this" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.Application"
  sign_in_audience = "AzureADMyOrg"

  single_page_application {
    redirect_uris = var.spa_uri
  }

  required_resource_access {
    # Microsoft Graph
    resource_app_id = "00000003-0000-0000-c000-000000000000"
    # openid
    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e"
      type = "Scope"
    }
    # profile
    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1"
      type = "Scope"
    }
    # User.Read
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
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

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
  use_existing                 = true
  feature_tags {
    enterprise = true
    gallery    = false
  }
}

# Target of the PIM *eligible* assignment, created manually in the portal: the
# PIM for app roles API isn't publicly available during the private preview.
resource "azuread_group" "eligible" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.Eligible"
  description      = "Members are eligible (PIM for app roles) to activate a privileged app role just-in-time."
  security_enabled = true
  members          = var.eligible_member_object_ids
}

# Classic appRoleAssignment = permanent ACTIVE (standing) access, for contrast.
resource "azuread_app_role_assignment" "standing" {
  count               = var.standing_role_value == "" ? 0 : 1
  app_role_id         = random_uuid.app_role_id[var.standing_role_value].result
  principal_object_id = azuread_group.eligible.object_id
  resource_object_id  = azuread_service_principal.this.object_id
}

data "azuread_client_config" "current" {}

output "client_id" {
  value = azuread_application.this.client_id
}

# Same format as doc/external-05/New-SpaConfigBase64.ps1: ?data=<url-encoded base64 JSON>.
# The redirect URI <oidc_debugger_url>/debug must be in spa_uri.
output "oidc_debugger_link" {
  value = "${trimsuffix(var.oidc_debugger_url, "/")}?data=${urlencode(base64encode(jsonencode({
    name                  = azuread_application.this.display_name
    authorizationEndpoint = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/oauth2/v2.0/authorize"
    clientId              = azuread_application.this.client_id
    scope                 = "openid profile"
  })))}"
}

output "service_principal_object_id" {
  value = azuread_service_principal.this.object_id
}

output "app_role_ids" {
  value = { for v in var.app_role_values : v => random_uuid.app_role_id[v].result }
}

output "eligible_group_id" {
  value = azuread_group.eligible.object_id
}
