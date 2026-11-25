# =============================================================================
# workforce — Stage 18: Multi-Tenant App with GitHub Actions OIDC
# =============================================================================
# See doc/stage-18/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "SecretMonitor" {
  source            = "./modules/multitenant_workload_identity"
  business_name     = "${var.deployment_unique_name}-SecretMonitoring"
  graph_permissions = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"]

  federated_identity_credentials = var.github_repo == "" ? [] : [
    {
      display_name = "github-actions-main"
      description  = "GitHub Actions OIDC from ${var.github_repo} on refs/heads/main"
      issuer       = "https://token.actions.githubusercontent.com"
      subject      = "repo:${var.github_repo}:ref:refs/heads/main"
      ##issuer        = "https://vc.factorlabs.pl",
      ##subject       = "system:serviceaccount:default:play-with-workload-identity"

      audiences = ["api://AzureADTokenExchange"]
    }
  ]
}

output "multitenant_client_id" {
  value = module.SecretMonitor.client_id
}

output "multitenant_sp_object_id" {
  value = module.SecretMonitor.service_principal_object_id
}
