variable "business_name" {
  description = "Business name prefix to use for all resources"
  type        = string
}
variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
variable "max_activation_duration_hours" {
  description = "Maximum duration in hours for PIM role activation"
  type        = number
  default     = 4
}

variable "group_id_eligibility" {
  description = "External group ID to apply PIM policy to (optional)"
  type        = string
}

resource "azuread_group" "app_administrators" {
  display_name     = "TF.${var.deployment_env_name}.${var.business_name}.ApplicationAdministrators"
  security_enabled = true
  description      = "Workshop: Group for users who need Application Administrator role"
}

resource "azuread_group_role_management_policy" "group_policy" {
  group_id = element(split("/", azuread_group.app_administrators.id), 2)
  role_id  = "member"
  eligible_assignment_rules {
    expiration_required = false
  }
}

#https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/privileged_access_group_assignment_schedule
resource "azuread_privileged_access_group_eligibility_schedule" "pim_eligible_role_assignment" {
  group_id             = element(split("/", azuread_group.app_administrators.id), 2)
  principal_id         = element(split("/", var.group_id_eligibility), 2)
  assignment_type      = "member"
  permanent_assignment = true
  #duration        = "PT4H"
  #https://github.com/hashicorp/terraform-provider-azuread/issues/1450
  depends_on = [azuread_group_role_management_policy.group_policy]
}


output "group_id" {
  value = azuread_group.app_administrators.id
}
