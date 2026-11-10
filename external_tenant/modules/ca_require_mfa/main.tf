# =============================================================================
# Module: ca_require_mfa
# =============================================================================
# Conditional Access in the External ID tenant: every user signing in to the
# given applications must complete MFA.
#
# In an External ID tenant the second factors on offer to customers are Email
# OTP and SMS. SMS is a paid add-on and off unless someone enables it, so with
# the default tenant setup "mfa" here is satisfied by an Email one-time passcode
# sent to the user's sign-up address. That works because the user flow's
# primary method is email + PASSWORD -- an email-OTP primary sign-in cannot also
# count as the second factor.
#
# Prerequisites (tenant-wide, NOT managed here -- see doc/external-02/README.md):
#   - Security defaults disabled (CA policies cannot be created otherwise)
#   - Email OTP enabled in Authentication methods
#   - deployer SP: Policy.ReadWrite.ConditionalAccess + Policy.Read.All
#
# Scoped to the listed apps only, so it cannot lock anyone out of the portal or
# out of other applications in the tenant.
# =============================================================================

resource "azuread_conditional_access_policy" "this" {
  display_name = "TF.Demo.${var.business_name}.RequireMFA"
  state        = var.policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = var.app_client_ids
    }

    users {
      included_users = ["All"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
