variable "business_name" {
  description = "Business name used in the application display name (TF.Demo.<business_name>.Application)"
  type        = string
}

variable "sign_in_audience" {
  description = "Sign in audience. External ID (CIAM) tenants only support AzureADMyOrg."
  type        = string
  default     = "AzureADMyOrg"
}

variable "web_uri" {
  description = "List of Web redirect URIs. Leave empty for a SPA -- a Web redirect URI turns it into a confidential client."
  type        = list(string)
  default     = []
}

variable "spa_uri" {
  description = "List of single-page application redirect URIs (auth code + PKCE)."
  type        = list(string)
  default     = []
}

variable "graph_permissions_basic" {
  description = "Microsoft Graph delegated permission IDs requested for sign-in (Scope)."
  type        = list(string)
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

variable "resource_permissions_delegated" {
  description = "Delegated permissions on APIs other than Microsoft Graph, as a map of resource client ID => list of scope IDs. Used to consume the APIs created by the api_definition module."
  type        = map(list(string))
  default     = {}
}

variable "assign_required" {
  description = "Require an explicit app role assignment before a user can sign in"
  type        = bool
  default     = false
}
