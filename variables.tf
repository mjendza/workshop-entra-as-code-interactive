variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
variable "deployment_unique_name" {
  description = "Unique prefix applied to resource business names so each attendee's deployment is distinct."
  type        = string
}
variable "trusted_locations_ip_ranges" {
  description = "(Optional)  List of IP address ranges in IPv4 CIDR format (e.g. 1.2.3.4/32) or any allowable IPv6 format from IETF RFC596 to be marked as trusted location(s)."
  type        = list(string)
  default     = null
}
variable "github_repo" {
  description = "GitHub repository in OWNER/REPO format. Used by Stage 18 to bind the multi-tenant app's Federated Identity Credential to a GitHub Actions OIDC subject (repo:OWNER/REPO:ref:refs/heads/main). Leave empty to skip Stage 18 FIC creation."
  type        = string
  default     = ""
}
variable "external_id_tenant_id" {
  description = "(Optional) External ID tenant ID. Used by External-02 to configure the external ID federation."
  type        = string
  default     = ""
  sensitive   = true
}
variable "external_id_default_domain_name" {
  description = "(Optional) External ID tenant default domain name. Used by External-02 to configure the external ID federation. For ext01.ciamlogin.com value should be ext01"
  type        = string
  default     = ""
  sensitive   = true
}