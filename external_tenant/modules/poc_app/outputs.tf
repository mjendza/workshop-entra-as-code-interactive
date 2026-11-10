output "api_client_id" {
  description = "Client ID of the API; appears in the aud claim of its access tokens."
  value       = module.api.client_id
}

output "api_identifier_uri" {
  description = "Identifier URI of the API, api://<client-id>."
  value       = module.api.identifier_uri
}

output "api_scope_uri" {
  description = "Full scope URI the SPA asks for (MSAL scopes array)."
  value       = module.api.scope_uris["access_as_user"]
}

output "api_app_role_values" {
  description = "Role strings as they appear in the roles claim."
  value       = module.api.app_role_values
}

output "api_service_principal_object_id" {
  description = "Object ID of the API enterprise application (Users and groups -> assign roles here)."
  value       = module.api.service_principal_object_id
}

output "api_user_assignment_required" {
  description = "Must be false, otherwise role-less customers cannot get a token."
  value       = module.api.user_assignment_required
}

output "spa_client_id" {
  description = "Client ID of the SPA (MSAL clientId)."
  value       = module.spa.client_id
}

output "spa_service_principal_object_id" {
  description = "Object ID of the SPA enterprise application. The SPA must have one before it can be assigned to a user flow."
  value       = module.spa.service_principal_object_id
}

output "spa_redirect_uris" {
  description = "Redirect URIs registered on the SPA."
  value       = var.spa_redirect_uris
}

output "ca_policy_id" {
  description = "Object ID of the optional require-MFA Conditional Access policy, or null when require_mfa = false."
  value       = one(module.ca_require_mfa[*].policy_id)
}
