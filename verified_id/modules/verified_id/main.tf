terraform {
  required_providers {
    verifiedid = {
      source = "mjendza/verifiedid"
    }
  }
}

variable "deployment_env_name" {
  description = "Unique name for the deployment"
  type        = string
  default     = "Workshop"
}

variable "authority_id" {
  description = "The Verified ID authority identifier (GUID)"
  type        = string
}

variable "credential_name" {
  description = "Name of the verifiable credential contract. Alphanumeric and spaces only; cannot start or end with a space or a number."
  type        = string
  default     = "WorkshopCredential"
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9 ]*[A-Za-z]$", var.credential_name)) && !can(regex("(^ )|( $)", var.credential_name))
    error_message = "credential_name must contain only alphanumeric characters and spaces, must not start or end with a space, and must not end with a number."
  }
}

variable "validity_interval" {
  description = "Credential validity interval in seconds"
  type        = number
  default     = 2592000
  validation {
    condition     = var.validity_interval > 0
    error_message = "validity_interval must be greater than 0"
  }
}

variable "credential_type" {
  description = "The verifiable credential type identifier"
  type        = string
  default     = "FactorlabsCertificateL1DEVMJ1"
}

variable "card_background_color" {
  description = "Background color for the credential card (hex)"
  type        = string
  default     = "#BDD0A7"
  validation {
    condition     = can(regex("^#[0-9A-Fa-f]{6}$", var.card_background_color))
    error_message = "card_background_color must be a valid hex color (e.g. #BDD0A7)"
  }
}

variable "card_text_color" {
  description = "Text color for the credential card (hex)"
  type        = string
  default     = "#000000"
  validation {
    condition     = can(regex("^#[0-9A-Fa-f]{6}$", var.card_text_color))
    error_message = "card_text_color must be a valid hex color (e.g. #000000)"
  }
}

variable "card_description" {
  description = "Short description displayed on the credential card"
  type        = string
  default     = "CERT L1 DEV-MJ"
}

variable "card_title" {
  description = "Title displayed on the credential card"
  type        = string
  default     = "Factorlabs Certificate Level 1"
}

variable "issued_by" {
  description = "Issuer name displayed on the credential card"
  type        = string
  default     = "factorlabs.pl"
}

variable "logo_uri" {
  description = "URI for the credential card logo image"
  type        = string
  default     = "https://verified-id.factorlabs.pl/l1.jpeg"
}

variable "logo_description" {
  description = "Alt text for the credential card logo"
  type        = string
  default     = "Factorlabs"
}

variable "consent_title" {
  description = "Title shown on the consent screen when sharing the credential"
  type        = string
  default     = "Share Factorlabs Certificate Level 1"
}

variable "consent_instructions" {
  description = "Instructions shown on the consent screen. Required by the Verified ID API; must be non-empty."
  type        = string
  default     = "Please review and accept to receive this credential."
  validation {
    condition     = length(trimspace(var.consent_instructions)) > 0
    error_message = "consent_instructions must be a non-empty string."
  }
}

variable "locale" {
  description = "Locale for the credential display"
  type        = string
  default     = "en-US"
}

variable "claims" {
  description = "List of claims included in the verifiable credential"
  type = list(object({
    claim = string
    label = string
    type  = string
  }))
  default = [
    {
      claim = "vc.credentialSubject.certNumber"
      label = "Certificate Number"
      type  = "String"
    }
  ]
}

resource "verifiedid_resource" "credential" {
  url = "verifiableCredentials/authorities/${var.authority_id}/contracts"
  body = {
    "name" : var.credential_name,
    "rules" : {
      "attestations" : {
        "idTokenHints" : [
          {
            "mapping" : [
              for c in var.claims : {
                "outputClaim" : split(".", c.claim)[length(split(".", c.claim)) - 1],
                "required" : true,
                "inputClaim" : split(".", c.claim)[length(split(".", c.claim)) - 1],
                "indexed" : false
              }
            ],
            "required" : true
          }
        ]
      },
      "validityInterval" : var.validity_interval,
      "vc" : {
        "type" : [var.credential_type]
      }
    },
    "displays" : [
      {
        "locale" : var.locale,
        "card" : {
          "backgroundColor" : var.card_background_color,
          "description" : var.card_description,
          "issuedBy" : var.issued_by,
          "textColor" : var.card_text_color,
          "title" : var.card_title,
          "logo" : {
            "description" : var.logo_description,
            "uri" : var.logo_uri
          }
        },
        "consent" : {
          "instructions" : var.consent_instructions,
          "title" : var.consent_title
        },
        "claims" : [
          for c in var.claims : {
            "claim" : c.claim,
            "label" : c.label,
            "type" : c.type
          }
        ]
      }
    ]
  }
}
