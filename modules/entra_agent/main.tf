terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.3.0"
    }
  }
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "business_name" {
  description = "Business name for the agent identity blueprint"
  type        = string
}

variable "sponsor_user_id" {
  description = "Object ID of the user to set as sponsor and owner"
  type        = string
}

variable "create_agent_user" {
  description = "Whether to create an Agent User linked to the Agent Identity"
  type        = bool
  default     = false
}

variable "oauth2_scope_id" {
  description = "Stable UUID for the OAuth2 permission scope (generate once with uuidgen or New-Guid)"
  type        = string
}

variable "agent_user_upn_domain" {
  description = "Domain for the Agent User's userPrincipalName (e.g. yourtenant.onmicrosoft.com)"
  type        = string
  default     = ""
}

resource "msgraph_resource" "agent_blueprint" {
  url         = "applications/graph.agentIdentityBlueprint"
  api_version = "beta"

  body = {
    displayName           = "TF.${var.deployment_env_name}.${var.business_name}.AgentBlueprint"
    "sponsors@odata.bind" = ["https://graph.microsoft.com/beta/users/${var.sponsor_user_id}"]
    "owners@odata.bind"   = ["https://graph.microsoft.com/beta/users/${var.sponsor_user_id}"]
  }

  response_export_values = {
    appId = "appId"
    id    = "id"
  }
}

# Add OAuth2 permission scope to make the agent visible in the portal
resource "msgraph_resource_action" "agent_blueprint_api_scope" {
  resource_url = "applications/${msgraph_resource.agent_blueprint.output.id}"
  api_version = "beta"
  method       = "PATCH"

  body = {
    identifierUris = ["api://${msgraph_resource.agent_blueprint.output.appId}"]
    api = {
      oauth2PermissionScopes = [
        {
          adminConsentDescription = "Allow the application to access the agent on behalf of the signed-in user."
          adminConsentDisplayName = "Access agent"
          id                      = var.oauth2_scope_id
          isEnabled               = true
          type                    = "User"
          value                   = "access_agent"
        }
      ]
    }
  }

  depends_on = [msgraph_resource.agent_blueprint]
}

resource "msgraph_resource" "agent_blueprint_principal" {
  url         = "serviceprincipals/graph.agentIdentityBlueprintPrincipal"
  api_version = "beta"

  body = {
    appId = msgraph_resource.agent_blueprint.output.appId
  }

  depends_on = [msgraph_resource_action.agent_blueprint_api_scope]

  response_export_values = {
    id = "id"
  }
}

resource "msgraph_resource" "agent_identity" {
  url         = "serviceprincipals/graph.agentIdentity"
  api_version = "beta"

  body = {
    displayName              = "TF.${var.deployment_env_name}.${var.business_name}.AgentIdentity"
    agentIdentityBlueprintId = msgraph_resource.agent_blueprint.output.appId
    "sponsors@odata.bind"    = ["https://graph.microsoft.com/beta/users/${var.sponsor_user_id}"]
  }

  depends_on = [
    msgraph_resource.agent_blueprint_principal,
    msgraph_resource_action.agent_blueprint_api_scope,
  ]

  response_export_values = {
    id = "id"
  }
}

# Create Agent User (optional)
resource "msgraph_resource" "agent_user" {
  count       = var.create_agent_user ? 1 : 0
  url         = "users"
  api_version = "beta"

  body = {
    "@odata.type"     = "microsoft.graph.agentUser"
    displayName       = "TF.${var.deployment_env_name}.${var.business_name}.AgentUser"
    userPrincipalName = "agent-${lower(var.business_name)}@${var.agent_user_upn_domain}"
    identityParentId  = msgraph_resource.agent_identity.output.id
    mailNickname      = "agent-${lower(var.business_name)}"
    accountEnabled    = true
  }

  depends_on = [msgraph_resource.agent_identity]

  response_export_values = {
    id                = "id"
    userPrincipalName = "userPrincipalName"
  }
}

output "blueprint_app_id" {
  description = "Application (client) ID of the Agent Identity Blueprint"
  value       = msgraph_resource.agent_blueprint.output.appId
}

output "blueprint_object_id" {
  description = "Object ID of the Agent Identity Blueprint"
  value       = msgraph_resource.agent_blueprint.output.id
}

output "agent_identity_id" {
  description = "Object ID of the Agent Identity"
  value       = msgraph_resource.agent_identity.output.id
}

output "agent_user_id" {
  description = "Object ID of the Agent User (if created)"
  value       = var.create_agent_user ? msgraph_resource.agent_user[0].output.id : null
}

output "agent_user_upn" {
  description = "UPN of the Agent User (if created)"
  value       = var.create_agent_user ? msgraph_resource.agent_user[0].output.userPrincipalName : null
}
