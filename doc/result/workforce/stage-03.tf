# =============================================================================
# workforce — Stage 03: Workload Identity
# =============================================================================
# See doc/stage-03/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Demo_WorkloadIdentity_ServicePrincipal" {
  source                   = "./modules/service_principal_workload_identity"
  business_name            = "${var.deployment_unique_name}-WorkloadIdentity"
  enable_workload_identity = true
  subject_identifier       = "system:serviceaccount:default:play-with-workload-identity"
  issuer_url               = "PUT_TOKEN_ISSUER_URL_HERE"
  graph_permissions = [
    #application.read.all
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
  ]
}
