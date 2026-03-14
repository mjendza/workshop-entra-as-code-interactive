# Stage 10: EntraExporter - Configuration State Export

## Rationale

To detect configuration drift and understand what has changed in your Entra ID tenant, you must first establish a baseline—a snapshot of your current configuration. **EntraExporter** is a PowerShell module that exports your complete Entra ID tenant configuration to JSON files, enabling you to:

- Create auditable snapshots of your identity infrastructure.
- Compare configurations between runs to identify changes.
- Archive configuration history for compliance and troubleshooting.
- Integrate with version control systems for configuration governance.


---

## ⏱️ Estimated Time: 10 minutes

---

## Goals

- Automate the provisioning of a Service Principal with the required EntraExporter permissions using Terraform.
- Understand how EntraExporter integrates into configuration governance and drift detection workflows.
- Export your tenant's configuration and review the output to understand its current state (e.g., examining policies like the `authorizationPolicy`).

---

## Documentation & References

- [EntraExporter - Official GitHub Repository](https://github.com/merill/EntraExporter)
- [EntraExporter PowerShell Module - PowerShell Gallery](https://www.powershellgallery.com/packages/EntraExporter)
- [Microsoft Graph Permissions Reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

---

## Implementation & Code

We will utilize the local `./modules/service_principal` module to provision a Service Principal. This identity will be granted the Microsoft Graph API permissions required by EntraExporter to export your tenant configuration. 

You can review the required permissions in the [EntraExporter documentation](https://github.com/microsoft/EntraExporter?tab=readme-ov-file#using-the-module).

Add the following module configuration to your `main.tf`:

```hcl
#########################################################################
# Stage 10: EntraExporter Service Principal for Configuration Export
#########################################################################

module "MicrosoftEntraExporter_ServicePrincipal" {
  source            = "./modules/service_principal"
  business_name     = "${var.deployment_unique_name}-EntraExporter"
  graph_permissions = [
    "d07a8cc0-3d51-4b77-b3b0-32704d1f69fa",
    "2f3e6f8c-093b-4c57-a58b-ba5ce494a169",
    "b86848a7-d5b1-41eb-a9b4-54a4e6306e97",
    "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30",
    "b0afded3-3588-46d8-8b3d-9842eff778da",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "c74fd47d-ed3c-45c3-9a9e-b8676de685d2",
    "e321f0bb-e7f7-481e-bb28-e3b0b32d4bd0",
    "1b0c317f-dd31-4305-9932-259a8b6e8099",
    "bb70e231-92dc-4729-aff5-697b3f04be95",
    "498476ce-e0fe-48b0-b801-37ba7e2685c6",
    "246dd0d5-5bd0-4def-940b-0421030a5b68",
    "9e640839-a198-48fb-8b9a-013fd6f6cbcd",
    "edb419d6-7edc-42a3-9345-509bfdf5d87c",
    "230c1aed-a721-4c5d-9cb4-a90514e508ef",
    "ff278e11-4a33-4d0c-83d2-d01dc58929a5",
    "c7fbd983-d9aa-4fa7-84b8-17382c103bc4",
    "83d4163d-a2d8-4d3b-9695-4ae3ca98f888",
    "75bcfbce-a647-4fba-ad51-b63d73b210f4",
    "ab5b445e-8f10-45f4-9c79-dd3f8062cc4e",
    "df021288-bdef-4463-88db-98f22de89214",
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

### Export Entra ID Configuration to JSON

#### Generate Credentials and Grant Consent

After Terraform successfully provisions the Service Principal, complete the following manual steps in the Azure Portal:

1. **Generate a Client Secret** for authentication.
2. **Grant Admin Consent** for the configured API permissions (requires Tenant Administrator privileges).

#### Run EntraExporter

An example walkthrough script is also available in `scripts\entra-exporter\workshop-entra-exporter.md`.

1. Install the EntraExporter PowerShell module on your workstation:
   ```powershell
   Install-Module EntraExporter -Force
   ```

2. Connect to your tenant using the Service Principal credentials:
   ```powershell
   $ClientSecretCredential = [pscredential]::new("YOUR_CLIENT_ID_HERE",(ConvertTo-SecureString "YOUR_SECRET_HERE" -AsPlainText -Force))
   Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId "YOUR_TENANT_ID_HERE"
   ```

3. Export your tenant configuration. 
   
   *Recommendation:* Change to the `scripts\entra-exporter` directory and output to the relative path `"exported\"`. This ensures the exported files are correctly placed for use in subsequent workshop stages.
   ```powershell
   Export-Entra -Path "exported\" -Type "Config"
   ```

4. Verify that the export completed successfully by reviewing the generated JSON files. They should contain comprehensive configuration data for your Entra ID resources.

---

## Stage Completion Checklist

- [ ] I have read and comprehended this stage.
- [ ] I have added the EntraExporter Service Principal module to `main.tf`.
- [ ] I have successfully run `terraform plan` without errors.
- [ ] I have successfully run `terraform apply` and provisioned the Service Principal.
- [ ] I have verified the App Registration and Enterprise Application exist in Entra ID.
- [ ] I have verified all API permissions are granted with admin consent.
- [ ] I have generated and securely stored the client secret.
- [ ] I have installed the EntraExporter PowerShell module on my workstation.
- [ ] I have successfully connected to Microsoft Graph using the Service Principal.
- [ ] I have successfully exported my tenant configuration to JSON files.
- [ ] I am ready to proceed to the next stage.

> **Tip:** Please mark all boxes above prior to closing out the issue!

> **Report Issues:** Did you encounter a bug or do you have a question? [Report your issue here](https://github.com/mjendza/workshop-entra-as-code/issues).

---

**Navigation:** [← Previous: Stage 9: Maester](../stage-9/maester.md) | [Next → Stage 11: Zero Trust Assessment](../stage-11/zta.md)
