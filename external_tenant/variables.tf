variable "multitenant_client_id" {
  description = "Application (client) ID of the multi-tenant app from the home tenant. Get it by running `terraform output -raw multitenant_client_id` from the repo root after the root `terraform apply`."
  type        = string
}

variable "graph_permissions" {
  description = "Microsoft Graph application role IDs to grant admin consent for in the target tenant. Default is Application.Read.All — must match (or be a subset of) the permissions requested by the home-tenant app registration."
  type        = list(string)
  default     = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"] # Application.Read.All
}

variable "native_signin_user_email" {
  description = "E-mail for the External-01 native-auth sign-in test user (emailAddress identity). Its mailbox must be reachable via the fakemail RSS feed the peaster test polls. Left blank so nothing tenant-specific is committed and unrelated applies are unaffected; when blank no user is created and the sign-in test skips."
  type        = string
  default     = ""
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "deployment_unique_name" {
  description = "Unique prefix applied to resource business names so each attendee's deployment is distinct."
  type        = string
}

variable "tenant_default_domain" {
  description = "Default domain of the target tenant (e.g. yourtenant.onmicrosoft.com)."
  type        = string
}