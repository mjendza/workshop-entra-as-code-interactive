output "client_id" {
  description = "Client ID (application ID) of the app registration"
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the application object"
  value       = azuread_application.this.object_id
}

output "service_principal_object_id" {
  description = "Object ID of the enterprise application (service principal)"
  value       = azuread_service_principal.this_SP.object_id
}
