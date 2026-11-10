output "client_id" {
  description = "Client ID (application ID) of the API app registration. This is what ENTRA_CLIENT_ID points at, and what appears in the aud claim of its access tokens. Also the map key when granting delegated access from a client app."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the API application object"
  value       = azuread_application.this.object_id
}

output "service_principal_object_id" {
  description = "Object ID of the API enterprise application (service principal). Pass this to a client's admin-consent grant, and use it to find the app under Enterprise applications."
  value       = azuread_service_principal.this_SP.object_id
}

output "identifier_uri" {
  description = "Identifier URI of the API, api://<client-id> unless overridden"
  value       = local.identifier_uri
}

output "scope_ids" {
  description = "Map of scope value => generated scope ID. Pass these to sso_app.resource_permissions_delegated."
  value       = { for k, v in random_uuid.scope : k => v.result }
}

output "scope_uris" {
  description = "Map of scope value => full scope URI, ready to paste into an MSAL scopes array."
  value       = { for k, _ in var.scopes : k => "${local.identifier_uri}/${k}" }
}

output "app_role_ids" {
  description = "Map of app role value => generated role ID. Needed to assign a role via azuread_app_role_assignment."
  value       = { for k, v in random_uuid.app_role : k => v.result }
}

output "app_role_values" {
  description = "The app role values exactly as they appear in the roles claim of an access token. The API compares against these strings."
  value       = sort(keys(var.app_roles))
}

output "user_assignment_required" {
  description = "Whether the enterprise application demands an app role assignment before Entra will issue a token. Must be false for role-less users to sign in at all."
  value       = azuread_service_principal.this_SP.app_role_assignment_required
}
