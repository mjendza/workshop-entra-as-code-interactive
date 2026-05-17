variable "multitenant_client_id" {
  description = "Application (client) ID of the multi-tenant app from the home tenant. Get it by running `terraform output -raw multitenant_client_id` from the repo root after the root `terraform apply`."
  type        = string
}

variable "graph_permissions" {
  description = "Microsoft Graph application role IDs to grant admin consent for in the target tenant. Default is Application.Read.All — must match (or be a subset of) the permissions requested by the home-tenant app registration."
  type        = list(string)
  default     = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"] # Application.Read.All
}
