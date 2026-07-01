output "client_id" {
  description = "The application (client) ID of the SSO application"
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "The object ID of the SSO application"
  value       = azuread_application.this.object_id
}

output "application_id" {
  description = "The application ID of the SSO application (alias for client_id)"
  value       = azuread_application.this.client_id
}

output "service_principal_object_id" {
  description = "The object ID of the service principal"
  value       = azuread_service_principal.this_SP.object_id
}
