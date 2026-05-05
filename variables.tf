variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}
variable "trusted_locations_ip_ranges" {
  description = "(Optional)  List of IP address ranges in IPv4 CIDR format (e.g. 1.2.3.4/32) or any allowable IPv6 format from IETF RFC596 to be marked as trusted location(s)."
  type        = list(string)
  default     = null
}