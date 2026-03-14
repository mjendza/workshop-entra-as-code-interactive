# Stage 11: Zero Trust Assessment - Security Posture Evaluation

## Rationale

Once you understand your current configuration (via EntraExporter), the next critical question is: **"How does my security posture compare to zero trust principles?"** The **ZeroTrustAssessment** (ZTA) tool evaluates your Entra ID tenant against established Zero Trust benchmarks and provides actionable insights into security gaps.

Zero Trust is a security model that requires continuous verification of all users, devices, and applications before granting access. The ZTA tool helps you:

- Measure compliance with Zero Trust principles.
- Identify security gaps in your identity infrastructure.
- Prioritize remediation efforts based on risk.
- Generate executive-friendly reports on security posture.
- Embed continuous assessment into your deployment pipeline.

---

## ⏱️ Estimated Time: 15 minutes

---

## Goals

- Automate the provisioning of a Service Principal with the required ZeroTrustAssessment permissions using Terraform.
- Review the assessment results to understand your tenant's security posture and identify areas for improvement.

---

## Documentation & References

- [Zero Trust Assessment - Official GitHub Repository](https://github.com/microsoft/zerotrustassessment)

---

## Implementation & Code

We will utilize the local `./modules/service_principal` module to provision a Service Principal with the Graph API permissions required for ZeroTrustAssessment to evaluate your tenant's security posture. ZTA requires read-only access to policies, roles, devices, security configurations, and audit logs.

> **Note:** Ensure you define a unique business name for this Service Principal to prevent naming collisions within a shared workshop environment.

Add the following module configuration to your `main.tf`:

```hcl
#########################################################################
# Stage 11: ZeroTrustAssessment Service Principal for Security Assessment
#########################################################################

module "MicrosoftZTA_ServicePrincipal" {
  source            = "./modules/service_principal"
  business_name     = "${var.deployment_unique_name}-ZeroTrustAssessment"
  graph_permissions = [
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "cac88765-0581-4025-9725-5ebc13f729ee",
    "7a6ee1e7-141e-4cec-ae74-d9db155731ff",
    "dc377aa6-52d8-4e23-b271-2a7ae04cedf3",
    "2f51be20-0bb4-4fed-bf7b-db946066c75e",
    "58ca0d9a-1575-47e1-a3cb-007ef2e4583b",
    "06a5fe6d-c49d-46a7-b082-56b1b14103c7",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "ae73097b-cb2a-4447-b064-5d80f6093921",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e",
    "dc5007c0-2d7d-4c42-879c-2dab87571379",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "37730810-e9ba-4e46-b07e-8ca78d182097",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "4cdc2547-9148-4295-8d11-be0db1391d6b",
    "01e37dc9-c035-40bd-b438-b2879c4870a6",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "38d9df27-64da-44fd-b7c5-a6fbac20248f"
  ]
}
```

Run `terraform plan` to preview the changes:

```bash
terraform plan
```

Run `terraform apply` to provision the Service Principal:

```bash
terraform apply
```

---

### Manual Testing with ZeroTrustAssessment

#### Generate Credentials and Grant Consent
After Terraform successfully provisions the Service Principal, complete the following manual steps in the Azure Portal:

1. **Generate a Client Secret** for authentication.
2. **Grant Admin Consent** for the configured API permissions (requires Tenant Administrator privileges).

#### Run the Assessment
1. Install the ZeroTrustAssessment PowerShell module on your workstation:
   ```powershell
   Install-Module ZeroTrustAssessment -Force
   ```

2. Connect to your tenant using the Service Principal credentials:
   ```powershell
   $ClientSecretCredential = [pscredential]::new("YOUR_CLIENT_ID_HERE",(ConvertTo-SecureString "YOUR_SECRET_HERE" -AsPlainText -Force))
   Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId "YOUR_TENANT_ID_HERE"
   ```

3. Run the Zero Trust assessment against your tenant:
   ```powershell
   Invoke-ZtAssessment
   ```

4. Review the generated reports, such as the HTML report which provides an executive summary.

5. Examine the findings and prioritize security improvements based on the assessment results.


---

## Stage Completion Checklist

- [ ] I have read and comprehended this stage.
- [ ] I have added the ZeroTrustAssessment Service Principal module to `main.tf`.
- [ ] I have successfully run `terraform plan` without errors.
- [ ] I have successfully run `terraform apply` and provisioned the Service Principal.
- [ ] I have verified the App Registration and Enterprise Application exist in Entra ID.
- [ ] I have verified all 20 API permissions are granted with admin consent.
- [ ] I have generated and securely stored the client secret.
- [ ] I have installed the ZeroTrustAssessment PowerShell module on my workstation.
- [ ] I have successfully connected to Microsoft Graph using the Service Principal.
- [ ] I have successfully run a Zero Trust assessment and generated reports.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or do you have a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code/issues).

---

**Navigation:** [← Previous: Stage 10: EntraExporter](../stage-10/entra-exporter.md) | [Next → Stage 12: Diff](../stage-12/diff.md)
