# =============================================================================
# Module: poc_app  (External-02)
# =============================================================================
# One self-contained PoC application stack in the External ID tenant:
#   - the exposed API (resource server),
#   - the SPA that signs customers in and calls the API (auth code + PKCE),
#   - NOT admin consent: it is granted MANUALLY in the Azure Portal
#     (SPA -> API permissions -> Grant admin consent, see doc/external-02 step 5),
#   - OPTIONAL: a Conditional Access policy requiring MFA on the SPA and API.
#
# Based on sandbox-terraform-entra-id/mail-external-id-local/modules/mail_instance.
# Every display name is prefixed by var.name so several instances can live side
# by side in one tenant.
#
# The dedicated email + password USER FLOW the SPA is assigned to is deliberately
# NOT in this module -- it is the focus of External-02 and is declared in the
# root (external-02.tf, module "poc_user_flow" -> ../user_flow).
# =============================================================================

##########################################################################################################################
## EXPOSED API
##
## Resource server only: no redirect URI, no client secret. Identifier URI is
## api://<client-id>; clients request api://<client-id>/access_as_user.
##########################################################################################################################

module "api" {
  source        = "../api_definition"
  business_name = "${var.name}.API"

  # "Admin" consent type -- no customer is ever shown a consent prompt; the
  # consent is granted MANUALLY in the Azure Portal (SPA -> API permissions ->
  # Grant admin consent), not by Terraform.
  scopes = {
    "access_as_user" = {
      display_name = "Access the API as the signed-in user"
      description  = "Allow the application to call the API on behalf of the signed-in user."
      consent_type = "Admin"
    }
  }

  app_roles = var.app_roles
}

##########################################################################################################################
## SPA
##
## Public client, SPA platform only (auth code + PKCE, no secret). Holds the
## basic sign-in Graph scopes and the API's access_as_user delegated permission.
##########################################################################################################################

module "spa" {
  source        = "../sso_app"
  business_name = "${var.name}.Spa"

  # web_uri left empty on purpose: a Web redirect URI would make this a
  # confidential client in Entra's eyes.
  spa_uri = var.spa_redirect_uris

  resource_permissions_delegated = {
    (module.api.client_id) = [
      module.api.scope_ids["access_as_user"],
    ]
  }
}

##########################################################################################################################
## CONDITIONAL ACCESS (OPTIONAL)
##
## require_mfa = true adds a policy forcing MFA (Email OTP in a default External
## ID tenant) on this SPA and API -- both, because CA is evaluated against the
## resource each token is issued for.
##
## PREREQUISITE: Security defaults must be DISABLED in the tenant, otherwise the
## Graph API refuses to create any Conditional Access policy.
##########################################################################################################################

module "ca_require_mfa" {
  count  = var.require_mfa ? 1 : 0
  source = "../ca_require_mfa"

  business_name  = var.name
  app_client_ids = [module.spa.client_id, module.api.client_id]
  policy_state   = var.mfa_policy_state
}
