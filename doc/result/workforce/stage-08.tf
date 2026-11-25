# =============================================================================
# workforce — Stage 08: Entra ID Agent (Preview)
# =============================================================================
# See doc/stage-08/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "EntraAgent" {
  source = "./modules/entra_agent"


  deployment_env_name = var.deployment_env_name
  business_name       = "${var.deployment_unique_name}-MyAgent"
  sponsor_user_id     = "MY_USER_OBJECT_ID_HERE"
  oauth2_scope_id     = "55e4ca81-5ef2-475e-9806-b84f0af78e32"
  graph_permissions = [
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"
  ]
  create_agent_user     = true
  agent_user_upn_domain = "my.entra.id.domain.here"

  microsoft_graph_sp_id = "MY_MICROSOFT_GRAPH_SP_ID_HERE"
}
