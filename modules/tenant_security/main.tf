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

variable "allow_invites_from" {
  description = "Who can invite guest users to the tenant"
  type        = string
  default     = "adminsAndGuestInviters"
  validation {
    condition     = contains(["none", "adminsAndGuestInviters", "adminsGuestInvitersAndAllMembers", "everyone"], var.allow_invites_from)
    error_message = "allow_invites_from must be one of: none, adminsAndGuestInviters, adminsGuestInvitersAndAllMembers, everyone"
  }
}

variable "guest_user_role_id" {
  description = "The role template ID for guest users (restricted or default)"
  type        = string
  default     = "10dae51f-b6af-4016-8d66-8c2a99b929b3"
}

variable "allowed_to_create_apps" {
  description = "Whether users are allowed to create app registrations"
  type        = bool
  default     = false
}

variable "allowed_to_create_security_groups" {
  description = "Whether users are allowed to create security groups"
  type        = bool
  default     = false
}

variable "allowed_to_read_other_users" {
  description = "Whether users are allowed to read other users in the directory"
  type        = bool
  default     = true
}

variable "allow_email_verified_users_to_join" {
  description = "Allow users to join tenant via email verification (viral B2B join attacks)"
  type        = bool
  default     = false
}

variable "allow_user_consent_for_risky_apps" {
  description = "Allow users to consent to risky OAuth applications (illicit consent grant attacks)"
  type        = bool
  default     = false
}

variable "allowed_to_signup_email_subscriptions" {
  description = "Allow users to sign up for email-based subscriptions like Power BI free, Microsoft Forms, etc."
  type        = bool
  default     = false
}

variable "allowed_to_create_tenants" {
  description = "Allow regular users to create new Entra ID tenants (shadow IT risk)"
  type        = bool
  default     = false
}

variable "disable_user_consent_to_apps" {
  description = "Disable all user consent to OAuth applications - requires admin approval for all app permissions"
  type        = bool
  default     = true
}

resource "msgraph_resource_action" "authorization_policy" {
  resource_url    = "policies/authorizationPolicy"
  method = "PATCH"

  body = {
    displayName = "TF.${var.deployment_env_name}.TenantAuthorizationPolicy"
    description = "Tenant-wide authorization policy managed by Terraform - restricts guest access and admin portal"

    allowInvitesFrom = var.allow_invites_from
    guestUserRoleId  = var.guest_user_role_id

    # Additional security controls
    allowEmailVerifiedUsersToJoinOrganization = var.allow_email_verified_users_to_join
    allowUserConsentForRiskyApps = var.allow_user_consent_for_risky_apps
    allowedToSignUpEmailBasedSubscriptions = var.allowed_to_signup_email_subscriptions

    defaultUserRolePermissions = {
      allowedToCreateApps = var.allowed_to_create_apps
      allowedToCreateSecurityGroups = var.allowed_to_create_security_groups
      allowedToReadOtherUsers = var.allowed_to_read_other_users

      # Additional security controls in defaultUserRolePermissions
      allowedToCreateTenants = var.allowed_to_create_tenants
      permissionGrantPoliciesAssigned = var.disable_user_consent_to_apps ? [] : ["managePermissionGrantsForSelf.microsoft-user-default-low"]
    }
  }
}

