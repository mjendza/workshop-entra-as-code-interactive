terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
    msgraph = {
      source = "microsoft/msgraph"
    }
  }
}

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
variable "assign_required" {
  description = "Is Assign Required to use the application?"
  type        = bool
  default     = false
}
variable "fallback_public_client_enabled" {
  description = "Enable fallback public client (native/mobile apps)"
  type        = bool
  default     = false
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
variable "resource_permissions" {
  description = "Map of resource app IDs to lists of permission IDs (app roles)"
  type        = map(list(string))
  default     = {}
  # Example:
  # {
  #   "00000003-0000-0000-c000-000000000000": ["a", "b", "c"]
  # }
}
variable "resource_permissions_delegated" {
  description = "Map of resource app IDs to lists of delegated scope IDs"
  type        = map(list(string))
  default     = {}
}
variable "user_flow_id" {
  description = "ID of the identity/authenticationEventsFlows user flow to link this application to."
  type        = string
}

resource "azuread_application" "this" {
  display_name                   = "TF.Demo.${var.business_name}.Application"
  sign_in_audience               = var.sign_in_audience
  fallback_public_client_enabled = var.fallback_public_client_enabled
  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2
  }

  dynamic "web" {
    for_each = length(var.web_uri) > 0 ? [1] : []
    content {
      redirect_uris = concat(["https://oidcdebugger.com/debug"], var.web_uri)
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
  # Add new dynamic required_resource_access blocks based on resource_permissions variable (app roles)
  dynamic "required_resource_access" {
    for_each = var.resource_permissions
    content {
      resource_app_id = required_resource_access.key

      dynamic "resource_access" {
        for_each = required_resource_access.value
        content {
          id   = resource_access.value
          type = "Role"
        }
      }

      dynamic "resource_access" {
        for_each = lookup(var.resource_permissions_delegated, required_resource_access.key, [])
        content {
          id   = resource_access.value
          type = "Scope"
        }
      }
    }
  }
  # Add required_resource_access for APIs that only have delegated scopes (no roles)
  dynamic "required_resource_access" {
    for_each = {
      for k, v in var.resource_permissions_delegated : k => v
      if !contains(keys(var.resource_permissions), k)
    }
    content {
      resource_app_id = required_resource_access.key

      dynamic "resource_access" {
        for_each = required_resource_access.value
        content {
          id   = resource_access.value
          type = "Scope"
        }
      }
    }
  }
}

resource "azuread_service_principal" "this_SP" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = var.assign_required

  use_existing = true
  feature_tags {
    enterprise = true
    gallery    = false
  }
}

resource "azuread_application_certificate" "this_cert" {
  count          = var.use_certificate ? 1 : 0
  application_id = azuread_application.this.id
  type           = "AsymmetricX509Cert"
  value          = file("${path.module}/../../cert/${var.certificate_file}")
  end_date       = timeadd(timestamp(), "8520h") //720 days
}

# Enable Entra native authentication APIs (beta-only property not supported by the azuread provider)
resource "msgraph_update_resource" "this_native_auth" {
  url         = "/applications/${azuread_application.this.object_id}"
  api_version = "beta"

  body = {
    nativeAuthenticationApisEnabled = "all"
  }

  depends_on = [azuread_application.this]
}

# Enable User Flow for that Application
# Link the application to the External ID user flow (authenticationEventsFlow) so the
# sign-up/sign-in experience it defines applies to this app. An application can only be
# linked to one user flow, and it must already have a service principal in the tenant.
# Uses the dedicated POST .../conditions/applications/includeApplications action (see
# https://learn.microsoft.com/graph/api/authenticationconditionsapplications-post-includeapplications)
# via msgraph_resource_action: the POST fires once on create and is NOT repeated on
# later applies (the action re-runs only if resource_url/body change, e.g. a new flow
# or app id — which is when the link must be re-created anyway). Destroying this
# resource only removes it from state; it does not unlink the app from the flow.
resource "msgraph_resource_action" "this_user_flow_assignment" {
  resource_url = "identity/authenticationEventsFlows/${var.user_flow_id}"
  action       = "conditions/applications/includeApplications"
  method       = "POST"
  api_version  = "v1.0"

  body = {
    "@odata.type" = "#microsoft.graph.authenticationConditionApplication"
    appId         = azuread_application.this.client_id
  }

  depends_on = [azuread_service_principal.this_SP]
}