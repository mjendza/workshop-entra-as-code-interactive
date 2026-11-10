# =============================================================================
# external_tenant — External-02: SSO for a PoC application (SPA + API)
# =============================================================================
# See doc/external-02/README.md. Three parts:
#   1. the PoC application itself: API + SPA (+ OPTIONAL CA,
#      which requires security defaults to be DISABLED). Admin consent is NOT
#      granted here - do it MANUALLY in the Azure Portal (README step 5),
#   2. a DEDICATED email + password user flow, assigned to the PoC SPA only,
#   3. outputs for the PoC app's MSAL configuration.
# =============================================================================

# ---------------------------------------------------------------------------
# External-02 PoC application: API + SPA (+ optional CA); consent = manual
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# External-02 dedicated user flow (email + password) assigned to the PoC SPA
# ---------------------------------------------------------------------------
# A separate flow from External-01's password_user_flow: an application can be
# assigned to ONLY ONE user flow, and a dedicated flow lets the PoC app have its
# own sign-up policy (poc_sign_up_allowed) without touching other apps.
#
# app_client_ids assigns the SPA via POST .../conditions/applications/includeApplications.
# The SPA needs a service principal before it can be assigned -> depends_on.
# Only the SPA is assigned: the API is never signed in to directly, it only
# receives tokens issued during the SPA's sign-in.

# ---------------------------------------------------------------------------
# External-02 outputs - everything the PoC app needs in its MSAL config
# ---------------------------------------------------------------------------
