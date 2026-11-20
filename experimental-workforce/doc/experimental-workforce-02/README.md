# Experimental-Workforce-02: WINDOWS - Entra joined Windows 11 (OpenIntuneBaseline WINDOWS)

> ⚠️ **Experimental path.** Independent from Stages 0-19. Uses the
> [`experimental-workforce/`](../../) Terraform root and the Service Principal from
> [Experimental-Workforce-01](../experimental-workforce-01/README.md#1-prerequisites).

Stage 01 protected data inside apps on devices you don't manage. This stage manages the **device
itself**: corporate Windows 11 laptops, enrolled through Autopilot and **Microsoft Entra joined**. You
deploy a representative part of the **Windows** module of the OpenIntuneBaseline as code - compliance,
update rings and Settings Catalog hardening - and learn the pattern for deploying the rest.

## Reference implementation

| | |
|---|---|
| Source | [OpenIntuneBaseline/WINDOWS](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS) |
| Release | [`windows-v4.0`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/releases/tag/windows-v4.0) "26H2 Edition" (stable) |
| Docs | [docs.openintunebaseline.com/platforms/windows](https://docs.openintunebaseline.com/platforms/windows/) |
| License | **GPL-3.0** |

The repository [SkipToTheEndpoint/OpenIntuneBaseline](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline)
is licensed under **GPL-3.0**, so it can be used as the reference for this workshop. The policy JSON is
downloaded at plan time from the pinned tag and is **not copied into this (MIT) repository**.

## Intended use-case (from OIB)

The Windows OIB is designed for and tested on **Windows 11 Enterprise**, **Autopilot-enrolled**,
**Microsoft Entra joined**, **single-user** devices with a **standard user** account.

> [!IMPORTANT]
> The Windows OIB is **not** designed for **hybrid-joined** devices and will likely not work as
> expected on them. Use cloud-only Entra joined test VMs/laptops.

Licensing: Intune P1 + Entra ID P1 + Defender for Endpoint (or M365 E3 + MDE / M365 E5 / Business
Premium). Some policies (e.g. Personal Data Encryption, Cloud Kerberos Trust) have extra requirements -
see [Settings guidance](https://docs.openintunebaseline.com/platforms/windows/settings-guidance/) and
[Known issues](https://docs.openintunebaseline.com/platforms/windows/known-issues/).

## Goals

- Understand the shape of the Windows OIB (`PolicyManifest.json`, policy types, naming convention).
- Deploy a **curated subset** of the baseline with a single `for_each`, driven by the manifest.
- Assign the policies to a **pilot device group** first (OIB ships three update rings: Pilot, UAT, Production).
- Know which tools to use for the **full** baseline (OIB Deployer, TenuVault, IntuneManagement).

## ⏱️ Estimated Time: 60-90 minutes

---

## 1. What the Windows OIB contains

`WINDOWS/PolicyManifest.json` lists every policy with a stable `oibId`, `policyType` and `status`
(`active` / `deprecated`). At `windows-v4.0`:

| `policyType` in manifest | Folder in `WINDOWS/IntuneManagement/` | Graph collection (beta) | Count (active + deprecated) |
|---|---|---|---|
| `SettingsCatalog` | `SettingsCatalog` | `deviceManagement/configurationPolicies` | 48 |
| `EndpointSecurity` | `SettingsCatalog` (file names contain `- ES -`) | `deviceManagement/configurationPolicies` | 15 |
| `CompliancePolicies` | `CompliancePolicies` | `deviceManagement/deviceCompliancePolicies` | 13 (9 active, `CP` granular v4.0) |
| `UpdatePolicies` | `UpdatePolicies` | `deviceManagement/deviceConfigurations` (`windowsUpdateForBusinessConfiguration`) | 3 rings |
| `DriverUpdateProfiles` | `DriverUpdateProfiles` | `deviceManagement/windowsDriverUpdateProfiles` | 3 rings |
| `DeviceConfiguration` | `DeviceConfiguration` | `deviceManagement/deviceConfigurations` | 1 (Endpoint Analytics) |

Plus two optional platform scripts in `WINDOWS/Scripts` (`Enable-AutoTimezone`,
`Trigger-PostOOBEUpdates`) and a CIS deviation file `OIB4.0-CIS5.0.0-DeviationRationale.csv`.

**Naming convention** (OIB): `Win - OIB - <Category> - <Area> - <D|U> - <Name> - v<version>`

- `SC` = Settings Catalog, `ES` = Endpoint Security, `CP` = Compliance Policy, `TP` = Template
- `D` = assign to **devices**, `U` = assign to **users**

The `D`/`U` letter matters: it tells you which group to assign the policy to.

> **Why a subset?** ~90 policies are too many to review in a workshop, and every one of them changes
> device behaviour. You will deploy a selection that covers all three API shapes (compliance, update
> ring, Settings Catalog); adding the rest is just extending a list.

---

## 2. Selected policies

| Policy | Type | Why it's in the workshop |
|---|---|---|
| `Win - OIB - CP - Device Health - U - BitLocker - v4.0` | Compliance | Device must be encrypted to be compliant |
| `Win - OIB - CP - Device Health - U - SecureBoot - v4.0` | Compliance | Secure Boot attestation |
| `Win - OIB - CP - Device Security - U - Firewall - v4.0` | Compliance | Firewall must be on |
| `Win - OIB - WUfB - Ring 1 - Pilot - v3.0` | Update ring | First of the three OIB rings |
| `Win - OIB - ES - Windows LAPS - D - LAPS Configuration - v4.0` | Endpoint Security | Rotating local admin password (Entra backup) |
| `Win - OIB - ES - Windows Firewall - D - Firewall Configuration - v3.1` | Endpoint Security | Pairs with the firewall compliance check |
| `Win - OIB - ES - Attack Surface Reduction - D - ASR Rules (Audit Mode) - v3.1` | Endpoint Security | Audit only - safe to apply in a lab |
| `Win - OIB - SC - Microsoft Edge - D - Security - v4.0` | Settings Catalog | Typical browser hardening |

Compliance only becomes *meaningful* once Conditional Access requires a compliant device
(`compliantDevice`) - that is the Windows counterpart of the `compliantApplication` grant from stage 01.
It is left as an optional exercise at the end.

---

## 3. From an OIB export to a Graph request body

Same idea as [stage 01](../experimental-workforce-01/README.md#3-from-an-oib-export-to-a-graph-request-body):
drop read-only properties, annotations and relationships before POSTing. Two Windows specifics:

- **Settings Catalog / Endpoint Security** exports carry `settingCount`, `creationSource`,
  `priorityMetaData` and many `#microsoft.graph.*` action markers. The `settings` array is posted as-is.
- **Compliance policies must be created with `scheduledActionsForRule`** (the *Actions for
  noncompliance*). The export contains it, but with `id`s and `@odata` links, so it is rebuilt from the
  export values.

```hcl
locals {
  oib_windows_base = "${var.oib_repository_raw_base}/${var.oib_windows_tag}/WINDOWS/IntuneManagement"

  # name => { folder, collection } - extend this map to deploy more of the baseline
  oib_windows_selected = {
    "Win - OIB - CP - Device Health - U - BitLocker - v4.0"                          = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - CP - Device Health - U - SecureBoot - v4.0"                         = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - CP - Device Security - U - Firewall - v4.0"                         = { folder = "CompliancePolicies", collection = "deviceManagement/deviceCompliancePolicies", assign_to = "users" }
    "Win - OIB - WUfB - Ring 1 - Pilot - v3.0"                                       = { folder = "UpdatePolicies", collection = "deviceManagement/deviceConfigurations", assign_to = "devices" }
    "Win - OIB - ES - Windows LAPS - D - LAPS Configuration - v4.0"                  = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - ES - Windows Firewall - D - Firewall Configuration - v3.1"          = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - ES - Attack Surface Reduction - D - ASR Rules (Audit Mode) - v3.1"  = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
    "Win - OIB - SC - Microsoft Edge - D - Security - v4.0"                          = { folder = "SettingsCatalog", collection = "deviceManagement/configurationPolicies", assign_to = "devices" }
  }

  oib_windows_readonly_keys = [
    "id", "version", "createdDateTime", "lastModifiedDateTime", "assignments", "settingCount",
    "creationSource", "priorityMetaData", "supportsScopeTags", "isAssigned",
  ]
}

data "http" "oib_windows" {
  for_each = local.oib_windows_selected
  url      = "${local.oib_windows_base}/${each.value.folder}/${replace(replace(each.key, " ", "%20"), "+", "%2B")}.json"
}

locals {
  oib_windows_raw = { for k, v in data.http.oib_windows : k => jsondecode(v.response_body) }

  oib_windows_body = {
    for k, raw in local.oib_windows_raw : k => merge(
      {
        for key, value in raw : key => value
        if (!contains(local.oib_windows_readonly_keys, key)
        && key != "scheduledActionsForRule"
        && !startswith(key, "#")
        && (key == "@odata.type" || !strcontains(key, "@odata.")))
      },
      # Compliance only: rebuild "Actions for noncompliance" without ids/links.
      # A for expression (not ?:) so "with" and "without" need no common type.
      {
        for _ in(can(raw.scheduledActionsForRule) ? ["x"] : []) : "scheduledActionsForRule" => [{
          ruleName = "PasswordRequired"
          scheduledActionConfigurations = [
            # IntuneManagement exports a single object here (not an array) - try() covers both
            for a in try(raw.scheduledActionsForRule[0], raw.scheduledActionsForRule).scheduledActionConfigurations : {
              actionType                = a.actionType
              gracePeriodHours          = a.gracePeriodHours
              notificationTemplateId    = a.notificationTemplateId
              notificationMessageCCList = a.notificationMessageCCList
            }
          ]
        }]
      }
    )
  }
}
```

> `ruleName = "PasswordRequired"` is the value Graph's own compliance examples use; the export has
> `null`. If Graph rejects it in your tenant, try leaving `ruleName` out.

---

## 4. Workshop steps

Add the blocks to [`experimental-workforce/experimental-workforce-02.tf`](../../experimental-workforce-02.tf).

### 4.1 Pilot groups

OIB policies are scoped `D` (device) or `U` (user), so create one group of each:

```hcl
resource "azuread_group" "windows_pilot_devices" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-Windows.Pilot.Devices"
  security_enabled = true
}

resource "azuread_group" "windows_pilot_users" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-Windows.Pilot.Users"
  security_enabled = true
}
```

Add your Entra joined test device to the device group and its user to the user group. (Optionally use
a dynamic device group on `device.devicePhysicalIds -any _ -contains "[ZTDId]"` for Autopilot devices.)

### 4.2 Policies

```hcl
resource "msgraph_resource" "oib_windows" {
  for_each    = local.oib_windows_selected
  api_version = "beta"
  url         = each.value.collection
  body        = local.oib_windows_body[each.key]
}
```

### 4.3 Assignments

All three collections support the `assign` action. Settings Catalog / Endpoint Security, compliance
and device configurations use the same `assignments[].target` shape as stage 01:

```hcl
resource "msgraph_resource_action" "oib_windows_assign" {
  for_each     = msgraph_resource.oib_windows
  api_version  = "beta"
  resource_url = "${local.oib_windows_selected[each.key].collection}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    # deviceCompliancePolicies/assign expects "assignments"; so do configurationPolicies and deviceConfigurations
    assignments = [{
      target = {
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId = (local.oib_windows_selected[each.key].assign_to == "devices"
          ? azuread_group.windows_pilot_devices.object_id
        : azuread_group.windows_pilot_users.object_id)
      }
    }]
  }
}
```

### 4.4 Apply

```powershell
terraform plan    # 8 policies + 8 assign actions + 2 groups
terraform apply
```

On the test device: **Settings → Accounts → Access work or school → Info → Sync**, or wait for the
next check-in.

---

## 5. Verification

- [ ] Intune → **Devices → Configuration** lists the Settings Catalog / Endpoint Security policies with their OIB names.
- [ ] Intune → **Devices → Compliance** lists the three `CP` policies; the device shows *Compliant* (or *Not compliant* with a clear reason, e.g. BitLocker not yet enabled).
- [ ] Intune → **Devices → Windows updates → Update rings** shows `Ring 1 - Pilot`.
- [ ] Per-policy **Device status** reports *Succeeded* for the test device, no *Conflict*.
- [ ] Entra → Devices → your device → **Local administrator password recovery** shows a LAPS password.
- [ ] Event Viewer → *Microsoft-Windows-Windows Defender/Operational* shows ASR **audit** events (ID 1122) - nothing is blocked.

## Deploying the full baseline

For everything outside the subset, use the tools OIB documents in
[Importing the baseline](https://docs.openintunebaseline.com/getting-started/importing/):

| Tool | When |
|---|---|
| [OIB Deployer](https://deploy.openintunebaseline.com/) | Granular, platform-specific deployment; shows missing or updated policies |
| [TenuVault](https://docs.tenuvault.com/baselines/quick-start/) | Deploy, compare and validate OIB policies |
| [IntuneManagement](https://github.com/Micke-K/IntuneManagement) | The tool OIB exports are made with |
| Terraform (this stage) | Add names from `PolicyManifest.json` (`status = "active"`) to `oib_windows_selected` |

Read the [CIS deviation rationale](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/blob/main/WINDOWS/OIB4.0-CIS5.0.0-DeviationRationale.csv)
before adding policies such as `Disable NTLM`, `Administrator Protection` or `In-Box App Removal`.

## Optional exercise: require a compliant device

Create an `azuread_conditional_access_policy` for `windows` with
`built_in_controls = ["compliantDevice"]`, scoped to `windows_pilot_users`, in report-only. This is what
makes the compliance policies above actually gate access.

## Known limitations (experimental)

- Graph **beta**; Settings Catalog `settings` payloads are large, so `terraform plan` diffs are noisy.
- Changing the tag to a new OIB release can rename policies and change `settingDefinitionId`s; review the
  [Windows change log](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/blob/main/WINDOWS/CHANGELOG.md) first.
- Driver update profiles and platform scripts are not covered here.

## References

- OIB Windows: <https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS>
- [Settings Catalog - configurationPolicies (Graph beta)](https://learn.microsoft.com/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationpolicy?view=graph-rest-beta)
- [windows10CompliancePolicy (Graph beta)](https://learn.microsoft.com/graph/api/resources/intune-deviceconfig-windows10compliancepolicy?view=graph-rest-beta)
- [windowsUpdateForBusinessConfiguration (Graph beta)](https://learn.microsoft.com/graph/api/resources/intune-deviceconfig-windowsupdateforbusinessconfiguration?view=graph-rest-beta)

---
**Navigation:** [← Experimental-Workforce-01: BYOD](../experimental-workforce-01/README.md) | [Experimental-Workforce-03: WINDOWS365 →](../experimental-workforce-03/README.md)
