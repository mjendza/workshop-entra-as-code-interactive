# =============================================================================
# workforce — Stage 19: TAP
# =============================================================================
# See doc/stage-19/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Tenant_TapPolicy" {
  source                      = "./modules/auth_methods_tap"
  state                       = "enabled"
  default_lifetime_in_minutes = 60
  is_usable_once              = true

  # Use "all_users" to target every user, or paste a specific group object ID:
  include_target_group_id = "all_users"
}
