terraform {
  required_providers {
    verifiedid = {
      source  = "mjendza/verifiedid"
      version = "= 0.1.14-beta"
    }
  }
}

#########################################################################
# Stage 101: Verified ID — Credential Contract
#########################################################################
data "verifiedid_resource" "authorities" {
  url = "verifiableCredentials/authorities"
  response_export_values = {
    value = "value"
  }
}

module "Demo_Credential_Contract" {
  source       = "./modules/verified_id"
  authority_id = data.verifiedid_resource.authorities.output.value[0].id

  credential_name = "${var.deployment_unique_name}WorkshopCredential"
  credential_type = "${var.deployment_unique_name}WorkshopCredential"
  card_title      = "${var.deployment_unique_name} Workshop Credential"
}

output "vc_authority_id" {
  value = data.verifiedid_resource.authorities.output.value[0].id
}