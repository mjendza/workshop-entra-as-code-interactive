output "policy_id" {
  description = "Object ID of the Conditional Access policy"
  value       = azuread_conditional_access_policy.this.id
}
