# =============================================================================
# Module: custom_user_attribute  (External-04)
# =============================================================================
# Creates ONE tenant-level custom user attribute. Entra stores its values on the
# b2c-extensions-app and names it
#   extension_<b2c-extensions-app appId without hyphens>_<name>
# That full name is the id output, exactly what a user flow's
# onAttributeCollection (and Graph $select on users) expects.
#
# HOW: Graph identity/userFlowAttributes is NOT used for the create. Instead
# create.ps1 calls the Entra admin portal's backend API
#   POST https://main.b2cadmin.ext.azure.com/api/userAttribute?tenantId=<tid>
#   {"dataType":2,"label":"<name>","adminHelpText":"<description>",
#    "userInputType":1,"userAttributeOptions":[],"attributeType":3}
# (the call the portal makes on "Add custom attribute"). It is an internal,
# undocumented API that needs a DELEGATED user token, so the create runs via
# local-exec with the Azure CLI login of the person running Terraform:
#   az login --tenant <external tenant id> --allow-no-subscriptions
# The full id is then read back with Graph (msgraph provider, deployer SP).
#
# Tenant-wide: the attribute can be used by any user flow in the tenant.
# Destroy does NOT delete the attribute (no public delete call) - remove it in
# the portal: External Identities -> Custom user attributes.
# data_type can NOT be changed after creation.
#
# A pure-Graph alternative (POST identity/userFlowAttributes, slow) is kept
# commented out at the bottom of this file.
# =============================================================================

terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = ">= 0.4.0"
    }
  }
}

variable "name" {
  description = "Attribute name, e.g. TermsOfUseAccepted. Letters and digits only - it becomes part of extension_<appId>_<name>."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]*$", var.name))
    error_message = "name must start with a letter and contain only letters and digits."
  }
}

variable "description" {
  description = "Internal description of the attribute (not shown on the sign-up page)."
  type        = string
  default     = ""
}

variable "data_type" {
  description = "string or boolean. Immutable after creation."
  type        = string
  default     = "string"

  validation {
    condition     = contains(["string", "boolean"], var.data_type)
    error_message = "data_type must be string or boolean."
  }
}

locals {
  # b2cadmin API enum (from the portal): 1 = String, 2 = Boolean.
  b2cadmin_data_type = { string = 1, boolean = 2 }[var.data_type]
}

data "azuread_client_config" "current" {}

# Create through the portal backend API (see header). Re-runs only when the
# tenant, name or data type changes; create.ps1 is idempotent.
resource "terraform_data" "this" {
  triggers_replace = {
    tenant_id = data.azuread_client_config.current.tenant_id
    name      = var.name
    data_type = var.data_type
  }

  input = {
    description = var.description
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
    command     = "${path.module}/create.ps1"
    environment = {
      ATTR_TENANT_ID   = data.azuread_client_config.current.tenant_id
      ATTR_NAME        = var.name
      ATTR_DESCRIPTION = var.description
      ATTR_DATA_TYPE   = tostring(local.b2cadmin_data_type)
    }
  }
}

# Read the full extension_<appId>_<name> id back from Graph (deployer SP,
# IdentityUserFlow.Read(Write).All). Deferred to apply on the first create.
data "msgraph_resource" "this" {
  url         = "identity/userFlowAttributes"
  api_version = "v1.0"

  # Filter in HCL by id suffix (_<name>), not by displayName.
  response_export_values = {
    all = "value"
  }

  depends_on = [terraform_data.this]

  lifecycle {
    postcondition {
      condition     = length([for a in self.output.all : a.id if endswith(lower(a.id), lower("_${var.name}"))]) == 1
      error_message = "Custom attribute '${var.name}' is not (yet) visible in Graph identity/userFlowAttributes. If it is listed in the portal (External Identities -> Custom user attributes), wait a minute and run terraform apply again. If it is missing, re-run the create: terraform apply -replace='<this module>.terraform_data.this' (see dev/terraform.md)."
    }
  }
}

locals {
  graph_ids = [for a in data.msgraph_resource.this.output.all : a.id if endswith(lower(a.id), lower("_${var.name}"))]
}

# =============================================================================
# ALTERNATIVE (commented out): create with the documented Graph API
# =============================================================================
#   POST https://graph.microsoft.com/v1.0/identity/userFlowAttributes
#   {"displayName":"<name>","description":"<description>","dataType":"boolean"}
#
# Pure Terraform: deployer SP only (IdentityUserFlow.ReadWrite.All), no az login,
# destroy DELETEs the attribute, also supports data_type = "int64". Downside:
# the POST is VERY slow in External ID tenants, which is why the PowerShell
# (b2cadmin) path above is active for now.
#
# To switch:
#   1. comment out terraform_data.this, data.msgraph_resource.this,
#      local.graph_ids and data.azuread_client_config.current above,
#   2. uncomment the two resources below,
#   3. in output "id" use: value = msgraph_resource.this.id
#   4. (optional) allow "int64" in the data_type validation.
# Existing attributes created by the script must be imported or deleted first.
#
# resource "msgraph_resource" "this" {
#   url         = "identity/userFlowAttributes"
#   api_version = "v1.0"
#
#   body = {
#     displayName = var.name
#     description = var.description
#     dataType    = var.data_type
#   }
#
#   lifecycle {
#     replace_triggered_by = [terraform_data.data_type]
#   }
# }
#
# # dataType is immutable in Graph: changing it must recreate the attribute.
# resource "terraform_data" "data_type" {
#   input = var.data_type
# }
# =============================================================================

output "id" {
  description = "Full attribute id: extension_<b2c-extensions-app appId without hyphens>_<name>."
  value       = one(local.graph_ids) # Graph alternative: msgraph_resource.this.id
}

output "name" {
  description = "Short attribute name."
  value       = var.name
}

output "data_type" {
  description = "Data type of the attribute."
  value       = var.data_type
}
