terraform {
  required_providers {
    msgraph = {
      source = "microsoft/msgraph"
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
      isSignUpAllowed = true
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

output "user_flow_id" {
  description = "ID of the identity/authenticationEventsFlows user flow created for this application."
  value       = msgraph_resource.this.id
}