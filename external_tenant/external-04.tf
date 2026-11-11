# =============================================================================
# external_tenant — External-04: sign-up with extra attributes
# =============================================================================
# See doc/external-04/README.md. Applied in THREE steps:
#   Step A (apply #1)
#     1. two tenant-level CUSTOM boolean attributes: TermsOfUseAccepted and
#        PrivacyPolicyAccepted (portal API, see modules/custom_user_attribute)
#        + their ids output,
#   Step B (apply #2)
#     2. a third PoC application: API + SPA (admin consent = MANUAL, step 5),
#     3. a DEDICATED email + password user flow that also collects first name,
#        last name and both REQUIRED consent checkboxes, assigned to that SPA,
#     4. outputs.
#   Step C (apply #3)
#     5. a claims mapping policy that adds both consent flags to the SPA's
#        ID token and the API's access token.
# =============================================================================

# ---------------------------------------------------------------------------
# Step A - External-04 custom user attributes (terms of use + privacy policy)
# ---------------------------------------------------------------------------
# Tenant-level: created once, usable by any user flow. The id output is the
# full extension_<b2c-extensions-app appId>_<name> the flow and Graph expect.

# ---------------------------------------------------------------------------
# Step B - External-04 PoC application: API + SPA; consent = manual
# ---------------------------------------------------------------------------
# A THIRD poc_app instance: an application can belong to only ONE user flow.

# ---------------------------------------------------------------------------
# Step B - External-04 dedicated user flow with extra sign-up attributes
# ---------------------------------------------------------------------------
# Order on the sign-up page = list order (after email and display name).
# Boolean attributes render as a single checkbox; required = true means the box
# must be ticked before the customer can continue. Labels support Markdown links.

# ---------------------------------------------------------------------------
# Step B - External-04 outputs
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Step C - External-04 token claims: the consent flags in ID + access token
# ---------------------------------------------------------------------------
# The flow stores the custom attributes on the user, but they are NOT in any
# token by default. A claims mapping policy (Source = user, ExtensionID = the
# full extension_<appId>_<name>) adds them. Assigned by token AUDIENCE: the
# SPA's SP for the ID token, the API's SP for the access token. Both apps
# already accept mapped claims (sso_app / api_definition set
# mapped_claims_enabled = true). Requires Policy.ReadWrite.ApplicationConfiguration.

