variable "deployment_unique_name" {
  description = "Unique prefix applied to resource business names so each attendee's deployment is distinct."
  type        = string
}

variable "oib_repository_raw_base" {
  description = "Raw content base URL of the OpenIntuneBaseline repository (GPL-3.0). Policy JSON is downloaded from here at plan time and never committed to this repo."
  type        = string
  default     = "https://raw.githubusercontent.com/SkipToTheEndpoint/OpenIntuneBaseline"
}

variable "oib_byod_tag" {
  description = "Experimental-Workforce-01: OpenIntuneBaseline release tag for the BYOD (App Protection) baseline."
  type        = string
  default     = "byod-v2.0"
}

variable "oib_windows_tag" {
  description = "Experimental-Workforce-02: OpenIntuneBaseline release tag for the Windows baseline."
  type        = string
  default     = "windows-v4.0"
}

variable "oib_windows365_tag" {
  description = "Experimental-Workforce-03: OpenIntuneBaseline release tag for the Windows 365 baseline."
  type        = string
  default     = "win365-v1.0"
}

variable "byod_require_app_protection" {
  description = "Experimental-Workforce-01: state of the Conditional Access policy requiring an app protection policy on iOS/Android. Start in report-only."
  type        = string
  default     = "enabledForReportingButNotEnforced"

  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.byod_require_app_protection)
    error_message = "Must be enabled, disabled or enabledForReportingButNotEnforced."
  }
}

variable "ca_break_glass_object_ids" {
  description = "Object IDs of break-glass accounts excluded from every Conditional Access policy in this path."
  type        = list(string)
  default     = []
}

variable "w365_create_provisioning_policy" {
  description = "Experimental-Workforce-03 (OPTIONAL): create the Windows 365 provisioning policy matching the OIB use-case. Needs CloudPC.ReadWrite.All and a Windows 365 Enterprise license."
  type        = bool
  default     = false
}

variable "w365_gallery_image_id" {
  description = "Experimental-Workforce-03: Windows 11 Enterprise gallery image id for the provisioning policy - pick one from GET deviceManagement/virtualEndpoint/galleryImages."
  type        = string
  default     = ""
}
