# =============================================================================
# external_tenant — External-03: SSO for a PoC application with Email OTP + MFA
# =============================================================================
# See doc/external-03/README.md. Four parts:
#   1. the tenant: SMS enabled as an authentication method (second factor),
#   2. a second PoC application: API + SPA + REQUIRED CA (MFA), which requires
#      security defaults to be DISABLED. Admin consent is NOT granted here - do
#      it MANUALLY in the Azure Portal (README step 6),
#   3. a DEDICATED passwordless Email OTP user flow, assigned to that SPA only,
#   4. outputs for the OTP PoC app's MSAL configuration.
# =============================================================================

# ---------------------------------------------------------------------------
# External-03 tenant: SMS authentication method (second factor for MFA)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# External-03 PoC application: API + SPA + CA (MFA); consent = manual
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# External-03 dedicated user flow (Email OTP, passwordless) assigned to the SPA
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# External-03 outputs - everything the OTP PoC app needs in its MSAL config
# ---------------------------------------------------------------------------
