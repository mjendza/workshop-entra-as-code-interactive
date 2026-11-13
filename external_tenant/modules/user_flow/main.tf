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

variable "primary_method" {
  description = "Primary sign-in method of the flow: \"password\" = Email with password (External-01/02), \"otp\" = Email one-time passcode, passwordless (External-03)."
  type        = string
  default     = "password"

  validation {
    condition     = contains(["password", "otp"], var.primary_method)
    error_message = "primary_method must be password or otp."
  }
}

variable "extra_attributes" {
  description = <<-EOT
    Additional attributes collected on the sign-up page, AFTER email and displayName, in list order (External-04).
      attribute             - "givenName", "surname", ... (built-in) or the id of a custom attribute
                              (extension_<b2c-extensions-app id without hyphens>_<Name>, from identity/userFlowAttributes).
      display_name          - attribute display name.
      label                 - text on the sign-up page. Markdown links are allowed, e.g. "I accept the [terms](https://...)".
      data_type             - string | boolean | int64.
      user_flow_attribute_type - builtIn | custom.
      input_type            - text | boolean | checkboxSingleSelect | radioSingleSelect | checkboxMultiSelect.
      required              - for a boolean checkbox: the box must be ticked to continue.
      validation_regex      - ignored (sent as null) for boolean attributes.
  EOT
  type = list(object({
    attribute                = string
    display_name             = string
    description              = optional(string, "")
    label                    = string
    data_type                = optional(string, "string")
    user_flow_attribute_type = optional(string, "builtIn")
    input_type               = optional(string, "text")
    required                 = optional(bool, false)
    validation_regex         = optional(string, "^.*")
  }))
  default = []
}

variable "attribute_collection_submit_extension_id" {
  description = "OPTIONAL (External-05). Object ID of an onAttributeCollectionSubmit custom authentication extension (modules/custom_auth_extension) called when the customer submits the sign-up page - the portal's \"When a user submits their information\". null = no call."
  type        = string
  default     = null
}

locals {
  extra_inputs = [for a in var.extra_attributes : {
    attribute        = a.attribute
    label            = a.label
    inputType        = a.input_type
    defaultValue     = null
    hidden           = false
    editable         = true
    writeToDirectory = true
    required         = a.required
    # Boolean (checkbox) inputs: send exactly what Entra stores - an empty regex
    # and one option (the label, value "true"). Sending null / [] works on
    # create, but the server normalizes it, so the next apply PATCHes the flow
    # and Graph rejects that PATCH with 400 "The request body is null or in bad format".
    validationRegEx = a.data_type == "boolean" ? "" : a.validation_regex
    options         = a.data_type == "boolean" ? [{ label = a.label, value = "true" }] : []
  }]

  extra_attribute_definitions = [for a in var.extra_attributes : {
    id                    = a.attribute
    displayName           = a.display_name
    description           = a.description
    userFlowAttributeType = a.user_flow_attribute_type
    dataType              = a.data_type
    supportedTenantTypes  = "externalId"
  }]
}

locals {
  # Built-in local-account identity providers of an External ID user flow.
  identity_providers = {
    password = {
      id                   = "EmailPassword-OAUTH"
      displayName          = "Email with password"
      identityProviderType = "EmailPassword"
    }
    otp = {
      id                   = "EmailOtpSignup-OAUTH"
      displayName          = "Email one-time passcode"
      identityProviderType = "EmailOTP"
    }
  }
  identity_provider = local.identity_providers[var.primary_method]
}

resource "msgraph_resource" "this" {
  url         = "identity/AuthenticationEventsFlows"
  api_version = "beta"
  body = {
    "@odata.type"              = "#microsoft.graph.externalUsersSelfServiceSignUpEventsFlow"
    displayName                = "TF.${var.deployment_env_name}.${var.business_name}.Flow"
    description                = null
    priority                   = 500
    onAttributeCollectionStart = null
    onAttributeCollectionSubmit = var.attribute_collection_submit_extension_id == null ? null : {
      "@odata.type"   = "#microsoft.graph.onAttributeCollectionSubmitCustomExtensionHandler"
      customExtension = { id = var.attribute_collection_submit_extension_id }
    }
    onInteractiveAuthFlowStart = {
      "@odata.type"   = "#microsoft.graph.onInteractiveAuthFlowStartExternalUsersSelfServiceSignUp"
      isSignUpAllowed = var.sign_up_allowed
    }
    onAuthenticationMethodLoadStart = {
      "@odata.type" = "#microsoft.graph.onAuthenticationMethodLoadStartExternalUsersSelfServiceSignUp"
      identityProviders = [
        {
          "@odata.type"        = "#microsoft.graph.builtInIdentityProvider"
          id                   = local.identity_provider.id
          displayName          = local.identity_provider.displayName
          supportedTenantTypes = "externalId"
          identityProviderType = local.identity_provider.identityProviderType
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
            inputs = concat([
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
            ], local.extra_inputs)
          },
        ]
      }
      attributes = concat([
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
      ], local.extra_attribute_definitions)
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