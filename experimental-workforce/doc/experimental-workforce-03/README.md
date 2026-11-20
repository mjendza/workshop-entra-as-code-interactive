# Experimental-Workforce-03: WINDOWS365 - Cloud PC add-on (OpenIntuneBaseline WINDOWS365)

> ⚠️ **Experimental path.** Independent from Stages 0-19. Uses the
> [`experimental-workforce/`](../../) Terraform root and builds directly on
> [Experimental-Workforce-02](../experimental-workforce-02/README.md).

Windows 365 Cloud PCs are Windows 11 devices too, so they get the Windows baseline from stage 02. On
top of that they need a few **Cloud PC-specific** settings: how the RDP connection behaves and which
local resources (drives, clipboard, USB, printers) may be redirected into the session. This stage
deploys the **WINDOWS365** module of the OpenIntuneBaseline and adjusts the stage 02 assignments for
Cloud PCs.

## Reference implementation

| | |
|---|---|
| Source | [OpenIntuneBaseline/WINDOWS365](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS365) |
| Release | [`win365-v1.0`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/releases/tag/win365-v1.0) (**unstable** channel) |
| Docs | [docs.openintunebaseline.com/platforms/windows365](https://docs.openintunebaseline.com/platforms/windows365/) |
| License | **GPL-3.0** |

The repository [SkipToTheEndpoint/OpenIntuneBaseline](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline)
is licensed under **GPL-3.0**, so it can be used as the reference for this workshop. The policy JSON is
downloaded at plan time from the pinned tag and is **not copied into this (MIT) repository**.

> The W365 baseline is on the **unstable** channel (v1.0, 2024, tested on the Windows 11 Enterprise
> 23H2 gallery image). Treat it as a starting point and re-check settings against current Windows 365
> guidance.

## Intended use-case (from OIB)

| | |
|---|---|
| Image | Windows 11 Enterprise gallery image |
| Provisioning policy | License type **Enterprise**, join type **Microsoft Entra joined**, **Microsoft Hosted Network**, **Use Microsoft Entra single sign-on = Yes** |
| User | Cloud-only or hybrid identity with Entra ID as IdP, MFA via Conditional Access, **not** a local admin |
| Licensing | M365 E3/E5 (+ MDE) or Business Premium, **plus a Windows 365 Enterprise SKU** |
| Client | Tested with the **Windows App** on a device also running the Windows OIB |

> [!NOTE]
> The W365 OIB is an **addition** to the Windows OIB. Assign Cloud PCs **all** Windows OIB policies
> **except**:
> - **BitLocker** (`Win - OIB - ES - Encryption - D - BitLocker (OS Disk)`, and the BitLocker compliance check)
> - **Device Health compliance** - replaced by the W365 compliance policy below
>
> Use group assignments or Intune **assignment filters** to achieve this.

> [!WARNING]
> The W365 OIB is **not** designed to protect corporate data when the Cloud PC is accessed from a
> **non-corporate** device. For BYOD access, combine it with stage 01 style controls (e.g. Windows App
> + app protection / Conditional Access).

## Goals

- Deploy the three W365 OIB policies from the pinned tag.
- Create a *Managed devices* **assignment filter** for Cloud PCs and **exclude** them from the
  BitLocker / Device Health policies deployed in stage 02.
- (Optional) Create a Windows 365 **provisioning policy** that matches the OIB use-case.

## ⏱️ Estimated Time: 45-60 minutes (+ Cloud PC provisioning time)

---

## 1. What the W365 OIB contains

| Policy | Type | Graph collection (beta) | Assign to |
|---|---|---|---|
| `Win365 - OIB - Device Security - D - Connectivity Settings - v1.0` | Settings Catalog | `deviceManagement/configurationPolicies` | Cloud PC devices |
| `Win365 - OIB - Device Security - D - Resource Redirection - v1.0` | Settings Catalog | `deviceManagement/configurationPolicies` | Cloud PC devices |
| `Win365 - OIB - Compliance - U - Device Health - v1.0` | Compliance | `deviceManagement/deviceCompliancePolicies` | Cloud PC users |

Key settings (from `WINDOWS365/SETTINGSOUTPUT.md`):

| Area | Setting | OIB value |
|---|---|---|
| Connectivity | RDP transport | **UDP and TCP** (RDP Shortpath) |
| Connectivity | Always prompt for password upon connection | Enabled |
| Connectivity | Disconnect remote session on lock (Microsoft identity platform auth) | Enabled |
| Connectivity | Require secure RPC / client encryption level | Enabled / **High** |
| Redirection | Audio/video playback, audio recording, time zone | **Allowed** |
| Redirection | Drives, COM, LPT, Plug and Play devices | **Blocked** |
| Redirection | Clipboard **server → client** | **Disabled** (data can go in, not out) |
| Compliance | Secure Boot, Code Integrity | Required |
| Compliance | BitLocker | **Not required** (not applicable to Cloud PCs) |
| Compliance | Non-compliance action | Mark non-compliant after **6 hours** |

`WINDOWS365/NativeImport/` holds the two Settings Catalog policies in the format of the Intune portal's
**Import policy** button - handy for a manual comparison with what Terraform created.

---

## 2. Workshop steps

Add the blocks to [`experimental-workforce/experimental-workforce-03.tf`](../../experimental-workforce-03.tf).
The download/strip logic is the same as stage 02 - reuse `local.oib_windows_readonly_keys`.

### 2.1 Groups and the Cloud PC filter

```hcl
resource "azuread_group" "w365_users" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-W365.Users"
  security_enabled = true
}

resource "msgraph_resource" "w365_filter" {
  api_version = "beta"
  url         = "deviceManagement/assignmentFilters"
  body = {
    displayName                    = "TF.Workshop.${var.deployment_unique_name}-W365.CloudPCs"
    description                    = "Windows 365 Cloud PCs (OIB W365 exclusions)"
    platform                       = "windows10AndLater"
    assignmentFilterManagementType = "devices"
    rule                           = "(device.model -startsWith \"Cloud PC\")"
  }
}
```

> Cloud PCs report a model of `Cloud PC <SKU>` (e.g. `Cloud PC Enterprise 2vCPU/8GB/128GB`). Verify the
> value on your first Cloud PC (Intune → Devices → *your Cloud PC* → Hardware) before relying on it.

### 2.2 W365 policies

```hcl
locals {
  oib_w365_base = "${var.oib_repository_raw_base}/${var.oib_windows365_tag}/WINDOWS365/IntuneManagement"

  oib_w365_selected = {
    "Win365 - OIB - Device Security - D - Connectivity Settings - v1.0" = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies" }
    "Win365 - OIB - Device Security - D - Resource Redirection - v1.0"  = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies" }
    "Win365 - OIB - Compliance - U - Device Health - v1.0"              = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies" }
  }
}

data "http" "oib_w365" {
  for_each = local.oib_w365_selected
  url      = "${local.oib_w365_base}/${each.value.folder}/${replace(each.key, " ", "%20")}.json"
}
```

Build `local.oib_w365_body` exactly like `local.oib_windows_body` in stage 02 (strip read-only keys,
rebuild `scheduledActionsForRule` for the compliance policy), then:

```hcl
resource "msgraph_resource" "oib_w365" {
  for_each    = local.oib_w365_selected
  api_version = "beta"
  url         = each.value.collection
  body        = local.oib_w365_body[each.key]
}
```

### 2.3 Assign to Cloud PCs only

The `D` policies go to **all devices** with the Cloud PC filter set to **include**; the `U` compliance
policy goes to the W365 users with the same filter:

```hcl
locals {
  # Looked up by key, so the two target shapes don't need a common type
  # (a ?: between two different object shapes is a Terraform type error)
  w365_assignment_targets = {
    devices = {
      "@odata.type"                              = "#microsoft.graph.allDevicesAssignmentTarget"
      deviceAndAppManagementAssignmentFilterId   = msgraph_resource.w365_filter.id
      deviceAndAppManagementAssignmentFilterType = "include"
    }
    users = {
      "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
      groupId                                    = azuread_group.w365_users.object_id
      deviceAndAppManagementAssignmentFilterId   = msgraph_resource.w365_filter.id
      deviceAndAppManagementAssignmentFilterType = "include"
    }
  }
}

resource "msgraph_resource_action" "oib_w365_assign" {
  for_each     = msgraph_resource.oib_w365
  api_version  = "beta"
  resource_url = "${local.oib_w365_selected[each.key].collection}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    assignments = [{
      target = local.w365_assignment_targets[strcontains(each.key, " - D - ") ? "devices" : "users"]
    }]
  }
}
```

### 2.4 Exclude Cloud PCs from the stage 02 BitLocker / Device Health policies

Go back to `msgraph_resource_action.oib_windows_assign` in
[`experimental-workforce-02.tf`](../../experimental-workforce-02.tf) and add the Cloud PC filter in
**exclude** mode for the BitLocker compliance policy (and for the BitLocker / Device Health policies if
you added them to `oib_windows_selected`):

```hcl
locals {
  w365_excluded_windows_policies = [
    "Win - OIB - CP - Device Health - U - BitLocker - v4.0",
    "Win - OIB - ES - Encryption - D - BitLocker (OS Disk) - v3.7",
  ]
}

# inside target = { ... } of oib_windows_assign:
#   deviceAndAppManagementAssignmentFilterId   = contains(local.w365_excluded_windows_policies, each.key) ? msgraph_resource.w365_filter.id : null
#   deviceAndAppManagementAssignmentFilterType = contains(local.w365_excluded_windows_policies, each.key) ? "exclude" : "none"
```

> An Intune assignment can have only **one** filter. If you later need another filter on the same
> assignment, combine the rules into one filter instead.

Add the W365 users (and their Cloud PCs, if you use device groups) to the stage 02 pilot groups so the
rest of the Windows OIB reaches them.

### 2.5 (Optional) Provisioning policy

Matching the OIB use-case. Requires `CloudPC.ReadWrite.All` and a Windows 365 Enterprise license.
Off by default - set `w365_create_provisioning_policy = true` and `w365_gallery_image_id` (a
Windows 11 Enterprise id from `GET deviceManagement/virtualEndpoint/galleryImages`) in `terraform.tfvars`:

```hcl
resource "msgraph_resource" "w365_provisioning" {
  count       = var.w365_create_provisioning_policy ? 1 : 0
  api_version = "beta"
  url         = "deviceManagement/virtualEndpoint/provisioningPolicies"
  body = {
    displayName        = "TF.Workshop.${var.deployment_unique_name}-W365.OIB"
    description        = "Entra joined, Microsoft hosted network, SSO - OIB W365 use-case"
    provisioningType   = "dedicated"
    imageType          = "gallery"
    imageId            = var.w365_gallery_image_id
    enableSingleSignOn = true
    domainJoinConfigurations = [{
      domainJoinType = "azureADJoin"
      regionGroup    = "europeUnion"
      regionName     = "automatic"
    }]
    windowsSetting = { locale = "en-US" }
  }

  lifecycle {
    precondition {
      condition     = var.w365_gallery_image_id != ""
      error_message = "Set w365_gallery_image_id when w365_create_provisioning_policy = true."
    }
  }
}
```

Assign it to `azuread_group.w365_users` (`assign` action on the provisioning policy) and assign a
Windows 365 license to the user to start provisioning. Check the property names against
[cloudPcProvisioningPolicy](https://learn.microsoft.com/graph/api/resources/cloudpcprovisioningpolicy?view=graph-rest-beta)
before applying - this API changes often.

### 2.6 Apply

```powershell
terraform plan
terraform apply
```

---

## 3. Verification

- [ ] Intune → **Devices → Configuration** shows both `Win365 - OIB - Device Security` policies, assigned to *All devices* with the `W365.CloudPCs` filter (*Include*).
- [ ] Intune → **Devices → Compliance** shows `Win365 - OIB - Compliance - U - Device Health - v1.0`; the Cloud PC is *Compliant*.
- [ ] The stage 02 BitLocker compliance policy shows the Cloud PC as **Not applicable** (filtered out), not *Not compliant*.
- [ ] Connect with the **Windows App**: copy text **into** the Cloud PC works, copy **out of** it doesn't; local drives are not visible in *This PC*.
- [ ] Locking the Cloud PC session disconnects it.

## Known limitations (experimental)

- W365 OIB is on the **unstable** channel and dates from 2024.
- Graph **beta** for everything in this stage; the provisioning policy API is the least stable.
- The Cloud PC filter rule depends on the reported device model - verify it in your tenant.

## References

- OIB Windows 365: <https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS365>
- [Configure single sign-on for Windows 365](https://learn.microsoft.com/en-us/windows-365/enterprise/configure-single-sign-on)
- [Windows 365 security guidelines](https://learn.microsoft.com/en-us/windows-365/enterprise/security-guidelines)
- [Manage RDP device redirections](https://learn.microsoft.com/en-us/windows-365/enterprise/manage-rdp-device-redirections)
- [RDP Shortpath for public networks](https://learn.microsoft.com/en-us/windows-365/enterprise/rdp-shortpath-public-networks)
- [Assignment filters](https://learn.microsoft.com/intune/fundamentals/filters/overview)

---
**Navigation:** [← Experimental-Workforce-02: WINDOWS](../experimental-workforce-02/README.md) | [Experimental Workforce path](../../README.md)
