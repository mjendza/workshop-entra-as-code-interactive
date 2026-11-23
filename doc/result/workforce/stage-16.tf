# =============================================================================
# workforce — Stage 16: Certificate-Based SP Authentication
# =============================================================================
# See doc/stage-16/README.md. Terraform loads every *.tf file in this
# directory, so splitting stages into files does not change resource addresses.
# =============================================================================

module "Workload_CertSp" {
  source        = "./modules/service_principal_rich"
  business_name = "${var.deployment_unique_name}-SpWithCertificate"
  graph_permissions = [
    "df021288-bdef-4463-88db-98f22de89214", # User.Read.All
    "29c18626-4985-4dcd-85c0-193eef327366", # Policy.ReadWrite.AuthenticationMethod (manage TAP policy)
    "50483e42-d915-4231-9639-7fdb7fd190e5", # UserAuthenticationMethod.ReadWrite.All (issue a TAP for a user)
  ]
  use_certificate             = true
  certificate_file            = "cert.pem"
  certificate_validity_months = 12
}

output "sp_with_certificate_client_id" {
  value = module.Workload_CertSp.client_id
}

output "sp_with_certificate_cert_end_date" {
  value = module.Workload_CertSp.cert_end_date
}
