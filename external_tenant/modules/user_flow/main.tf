terraform {
  required_providers {
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.4.0" # msgraph_resource_action
    }
  }
}

variable "deployment_env_name" {
  description = "Deployment environment name"
  type        = string
}

variable "business_name" {
  description = "Business name"
  type        = string
}

variable "sign_up_allowed" {
  description = "Show the \"No account? Create one\" link. false = sign-in only: existing users can sign in, nobody can self-register."
  type        = bool
  default     = true
}

variable "app_client_ids" {
  description = "Applications to link to this user flow, as a map of STATIC label => client ID (appId). Keys must be known at plan time (e.g. \"spa\"); values may be apply-time. Each app must already have a service principal, and an application can belong to only one user flow. Leave empty when the app links itself (External-01's sso_app_native does)."
  type        = map(string)
  default     = {}
}

resource "msgraph_resource" "this" {
  url         = "identity/AuthenticationEventsFlows"
  api_version = "beta"
  body = {
    "@odata.type"               = "#microsoft.graph.externalUsersSelfServiceSignUpEventsFlow"
    displayName                 = "TF.${var.deployment_env_name}.${var.business_name}.Flow"
    description                 = null
    priority                    = 500
    onAttributeCollectionStart  = null
    onAttributeCollectionSubmit = null
    onInteractiveAuthFlowStart = {
      "@odata.type"   = "#microsoft.graph.onInteractiveAuthFlowStartExternalUsersSelfServiceSignUp"
      isSignUpAllowed = var.sign_up_allowed
    }
    onAuthenticationMethodLoadStart = {
      "@odata.type" = "#microsoft.graph.onAuthenticationMethodLoadStartExternalUsersSelfServiceSignUp"
      identityProviders = [
        {
          "@odata.type"        = "#microsoft.graph.builtInIdentityProvider"
          id                   = "EmailPassword-OAUTH"
          displayName          = "Email with password"
          supportedTenantTypes = "externalId"
          identityProviderType = "EmailPassword"
          state                = null
        }
      ]
    }
    onAttributeCollection = {
      "@odata.type"  = "#microsoft.graph.onAttributeCollectionExternalUsersSelfServiceSignUp"
      accessPackages = []
      attributeCollectionPage = {
        customStringsFileId = null
        views = [
          {
            title       = null
            description = null
            inputs = [
              {
                attribute        = "email"
                label            = "Email Address"
                inputType        = "text"
                defaultValue     = null
                hidden           = true
                editable         = false
                writeToDirectory = true
                required         = true
                validationRegEx  = "^[a-zA-Z0-9.!#$%&amp;&#8217;'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*$"
                options          = []
              },
              {
                attribute        = "displayName"
                label            = "Display Name"
                inputType        = "text"
                defaultValue     = null
                hidden           = false
                editable         = true
                writeToDirectory = true
                required         = false
                validationRegEx  = "^.*"
                options          = []
              },
            ]
          },
        ]
      }
      attributes = [
        {
          id                    = "email"
          displayName           = "Email Address"
          description           = "Email address of the user"
          userFlowAttributeType = "builtIn"
          dataType              = "string"
          supportedTenantTypes  = "externalId"
        },
        {
          id                    = "displayName"
          displayName           = "Display Name"
          description           = "Display Name of the User."
          userFlowAttributeType = "builtIn"
          dataType              = "string"
          supportedTenantTypes  = "externalId"
        },
      ]
    }
    onUserCreateStart = {
      "@odata.type"    = "#microsoft.graph.onUserCreateStartExternalUsersSelfServiceSignUp"
      userTypeToCreate = "member"
      accessPackages   = []
    }
  }
}

# Link each application in var.app_client_ids to this user flow (External-02).
# Uses the dedicated POST .../conditions/applications/includeApplications action
# (https://learn.microsoft.com/graph/api/authenticationconditionsapplications-post-includeapplications)
# via msgraph_resource_action: the POST fires once on create and is NOT repeated
# on later applies (it re-runs only if resource_url/body change, e.g. a new flow
# or app id). Destroying it only removes it from state; it does not unlink the
# app from the flow. The caller must depends_on the app's service principal --
# includeApplications rejects an app that has none yet.
resource "msgraph_resource_action" "app_assignment" {
  for_each = var.app_client_ids

  resource_url = "identity/authenticationEventsFlows/${msgraph_resource.this.id}"
  action       = "conditions/applications/includeApplications"
  method       = "POST"
  api_version  = "v1.0"

  body = {
    "@odata.type" = "#microsoft.graph.authenticationConditionApplication"
    appId         = each.value
  }
}

output "user_flow_id" {
  description = "ID of the identity/authenticationEventsFlows user flow created for this application."
  value       = msgraph_resource.this.id
}