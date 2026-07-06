output "email" {
  description = "E-mail (emailAddress identity) the user signs in with."
  value       = var.email
}

output "object_id" {
  description = "Directory object ID of the created user."
  value       = msgraph_resource.user.output.object_id
}
