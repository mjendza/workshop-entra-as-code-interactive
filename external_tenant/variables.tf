variable "multitenant_client_id" {
  description = "Stage 18 only: Application (client) ID of the multi-tenant app from the home tenant. Get it by running `terraform output -raw multitenant_client_id` from the repo root after the root `terraform apply`. Not needed by the External-0x steps."
  type        = string
  default     = ""
}

variable "graph_permissions" {
  description = "Microsoft Graph application role IDs to grant admin consent for in the target tenant. Default is Application.Read.All — must match (or be a subset of) the permissions requested by the home-tenant app registration."
  type        = list(string)
  default     = ["9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30"] # Application.Read.All
}

variable "native_signin_user_email" {
  description = "E-mail for the External-01 native-auth sign-in test user (emailAddress identity). Its mailbox must be reachable via the fakemail RSS feed the peaster test polls. Left blank so nothing tenant-specific is committed and unrelated applies are unaffected; when blank no user is created and the sign-in test skips."
  type        = string
  default     = ""
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "deployment_unique_name" {
  description = "Unique prefix applied to resource business names so each attendee's deployment is distinct."
  type        = string
}

variable "tenant_default_domain" {
  description = "Default domain of the target tenant (e.g. yourtenant.onmicrosoft.com)."
  type        = string
}

variable "poc_spa_redirect_uris" {
  description = "External-02: SPA redirect URIs of the PoC app. Entra matches these exactly -- a trailing slash difference is a mismatch (AADSTS50011)."
  type        = list(string)
  default     = ["http://localhost:5173/", "https://oidcdebugger.com/debug", "http://localhost:3000/oidcdebugger/debug", "https://tenant.factorlabs.pl/oidcdebugger/debug"]
}

variable "poc_sign_up_allowed" {
  description = "External-02: allow self-service sign-up in the PoC app's user flow. false = sign-in only."
  type        = bool
  default     = true
}

variable "poc_require_mfa" {
  description = "External-02 (OPTIONAL): create a Conditional Access policy requiring MFA (Email OTP) on the PoC SPA and API. Security defaults MUST be disabled in the External ID tenant first."
  type        = bool
  default     = false
}

variable "otp_sign_up_allowed" {
  description = "External-03: allow self-service sign-up in the OTP PoC app's user flow. false = sign-in only."
  type        = bool
  default     = true
}

variable "otp_require_mfa" {
  description = "External-03: create a Conditional Access policy requiring MFA (SMS as the second factor) on the OTP PoC SPA and API. Security defaults MUST be disabled in the External ID tenant first."
  type        = bool
  default     = true
}

variable "otp_sms_state" {
  description = "External-03: state of the tenant-wide SMS authentication method (enabled / disabled). Required for MFA after an email-OTP sign-in."
  type        = string
  default     = "enabled"
}

variable "signup_terms_of_use_url" {
  description = "External-04: URL of the terms of use, linked from the sign-up checkbox label."
  type        = string
  default     = "https://www.example.com/terms-of-use"
}

variable "signup_privacy_policy_url" {
  description = "External-04: URL of the privacy policy, linked from the sign-up checkbox label."
  type        = string
  default     = "https://www.example.com/privacy"
}

variable "profile_api_base_url" {
  description = "External-05: base URL of YOUR profile API, e.g. https://<your-endpoint>.free.beeceptor.com. Entra POSTs to <base>/api/OnAttributeCollectionSubmit and <base>/api/OnTokenIssuanceStart. Empty = not configured (External-05 fails at plan with a hint)."
  type        = string
  default     = ""

  validation {
    condition     = var.profile_api_base_url == "" || can(regex("^https://[A-Za-z0-9.-]+/?$", var.profile_api_base_url))
    error_message = "profile_api_base_url must be https://<host> with no path, e.g. https://my-endpoint.free.beeceptor.com."
  }
}

variable "partner_theme_locale" {
  description = "External-07: localization of the Partner branding theme to fill. \"0\" = the theme's default for all languages. If Graph answers 404 for it, use a culture name such as \"en-US\" - then only browsers in that language (or ui_locales=en-US) see the theme."
  type        = string
  default     = "0"
}
