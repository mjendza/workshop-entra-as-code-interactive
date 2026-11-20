# Experimental-Workforce-01: BYOD - App Protection (OpenIntuneBaseline BYOD)

> ⚠️ **Experimental path.** Independent from Stages 0-19. Uses its own Terraform root:
> [`experimental-workforce/`](../../).

Personal (BYOD) iOS and Android phones are not enrolled in Intune, so you cannot push device
configuration to them. Instead you protect the **corporate data inside the apps** (Outlook, Teams,
OneDrive, Edge, …) with **Intune App Protection Policies** (APP / MAM), and use **Conditional Access**
to make sure only protected apps can reach Microsoft 365.

This stage implements the **BYOD** module of the OpenIntuneBaseline as code.

## Reference implementation

| | |
|---|---|
| Source | [OpenIntuneBaseline/BYOD](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/BYOD) |
| Release | [`byod-v2.0`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/releases/tag/byod-v2.0) (stable) |
| Docs | [docs.openintunebaseline.com/platforms/byod](https://docs.openintunebaseline.com/platforms/byod/) |
| License | **GPL-3.0** |

The repository [SkipToTheEndpoint/OpenIntuneBaseline](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline)
is licensed under **GPL-3.0**, so it can be used as the reference for this workshop. The policy JSON is
downloaded at plan time from the pinned tag and is **not copied into this (MIT) repository** - see the
[path README](../../README.md#reference-implementation-and-license).

## Goals

- Create a dedicated Service Principal with the Intune Graph permissions this path needs.
- Deploy the two OIB **BYOD L2+** app protection policies (Android + iOS/iPadOS) from the OIB JSON.
- Create *Managed apps* **assignment filters** so the policies only apply to **unmanaged** devices.
- Assign the policies to a pilot group with the filter.
- Create the Conditional Access policies OIB lists as prerequisites: **require app protection policy**
  on iOS/Android and **block legacy authentication**.

## ⏱️ Estimated Time: 45-60 minutes

---

## 1. Prerequisites

### Tenant

- [ ] A Workforce **development** tenant with an active **Intune** license (Microsoft Graph Intune
      APIs require it) and **Entra ID P1** (Conditional Access).
- [ ] **Security defaults disabled** (needed for Conditional Access, same as [Stage 4](../../../doc/stage-04/README.md)).
- [ ] A test user with an iOS or Android phone that is **not** enrolled in Intune.
- [ ] At least one **break-glass** account to exclude from Conditional Access.

### Service Principal

The Stage 0 Service Principal only has `Application.ReadWrite.All`. Create a separate one for this
path (same steps as [Stage 0](../../../doc/stage-00/README.md)):

1. App registrations → **New registration** → name `Workshop-Terraform-SP-Intune` → single tenant.
2. Certificates & secrets → new client secret (90 days) → copy the value.
3. API permissions → Microsoft Graph → **Application** permissions → add the list below →
   **Grant admin consent**.

| Stage | Permission | Type | Used for |
|---|---|---|---|
| 01, 02, 03 | `Group.ReadWrite.All` | Application | Pilot / assignment groups |
| 01 | `DeviceManagementApps.ReadWrite.All` | Application | `deviceAppManagement/iosManagedAppProtections`, `androidManagedAppProtections` and their `assign` action |
| 01, 02, 03 | `DeviceManagementConfiguration.ReadWrite.All` | Application | `deviceManagement/assignmentFilters`, `configurationPolicies` (Settings Catalog), `deviceCompliancePolicies`, `deviceConfigurations` (WUfB rings) |
| 01 | `Policy.Read.All` | Application | Reading existing policies before Conditional Access updates |
| 01 | `Policy.ReadWrite.ConditionalAccess` | Application | Conditional Access policies |
| 01 | `Application.Read.All` | Application | Resolving service principals referenced by Conditional Access |
| 03 | `CloudPC.ReadWrite.All` | Application | (Optional) Windows 365 provisioning policy |

4. Fill both provider blocks in [`experimental-workforce/provider.tf`](../../provider.tf) and set
   `deployment_unique_name` (and `ca_break_glass_object_ids`) in
   [`experimental-workforce/terraform.tfvars`](../../terraform.tfvars).

```powershell
cd experimental-workforce
terraform init
```

---

## 2. What the OIB BYOD baseline contains

| Policy | Platform | Graph collection (beta) |
|---|---|---|
| `Android - OIB - App Protection - U - BYOD L2+ - v2.0` | Android | `deviceAppManagement/androidManagedAppProtections` |
| `iOS - OIB - App Protection - U - BYOD L2+ - v2.0` | iOS/iPadOS | `deviceAppManagement/iosManagedAppProtections` |

"**L2+**" = Microsoft's [Data protection framework](https://learn.microsoft.com/en-us/intune/app-management/protection/data-protection-framework)
**Level 2 - Enterprise enhanced data protection**, with a few settings raised to Level 3. The key
decisions (from [`BYOD/CHANGELOG.md`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/blob/main/BYOD/CHANGELOG.md)):

| Area | OIB choice | vs. Level 2 |
|---|---|---|
| Targeted apps | **All Microsoft Apps** (`appGroupType = allMicrosoftApps`), all app types | Broader than "Core Microsoft Apps", no list to maintain |
| Send org data | Policy managed apps (iOS: *with Open-In/Share filtering*) | Level 2 |
| Save copies | Block, except OneDrive for Business, SharePoint, Photo Library | Level 2 |
| Receive data | All apps | Level 2 - this greys out *Open data into Org documents* |
| Printing | **Block** | Raised to Level 3 |
| App PIN | 6 digits, **simple PIN blocked**, biometrics allowed (Android: Class 3 required) | Raised to Level 3 |
| Offline grace | Block after 7 days, wipe after 30 days | Level 2 |
| Jailbroken / rooted | **Wipe data** | Raised to Level 3 |
| Samsung Knox attestation | Block access (Android) | - |
| Min OS / patch version | **Not configured** - changes monthly; OIB recommends [IntuneComplianceMaintainer](https://github.com/SkipToTheEndpoint/IntuneComplianceMaintainer) | Level 2 asks for it |
| Mobile Threat Defense | Not configured (needs an MTD connector) | Level 3 |

> **Source of truth:** OIB states that `SETTINGSOUTPUT.md` misses some settings (Photo Library in the
> save/open lists, Android device conditions such as Play Integrity, device lock and Samsung Knox).
> Always read the JSON in `BYOD/IntuneManagement/AppProtection`, which is exactly what this stage
> deploys.

---

## 3. From an OIB export to a Graph request body

The OIB JSON files are **IntuneManagement exports**, not POST bodies. They contain read-only and
navigation data that Graph rejects on create:

- `@odata.context`, `@odata.id`, `@odata.editLink`, and every `<property>@odata.type` /
  `@odata.navigationLink` / `@odata.associationLink` annotation (only the top-level `@odata.type` is kept);
- `id`, `version`, `createdDateTime`, `lastModifiedDateTime`, `isAssigned`, `deployedAppCount`;
- `apps` and `assignments` (relationships - managed by separate actions);
- action markers such as `#microsoft.graph.assign`.

Because `appGroupType = allMicrosoftApps`, Intune fills the targeted app list itself, so you don't
need to POST `apps` (`targetApps` action) at all.

A small `locals` block downloads the file from the pinned tag and strips these keys:

```hcl
locals {
  oib_byod_base = "${var.oib_repository_raw_base}/${var.oib_byod_tag}/BYOD/IntuneManagement/AppProtection"

  oib_byod_files = {
    android = "Android - OIB - App Protection - U - BYOD L2+ - v2.0.json"
    ios     = "iOS - OIB - App Protection - U - BYOD L2+ - v2.0.json"
  }

  oib_readonly_keys = [
    "id", "version", "createdDateTime", "lastModifiedDateTime", "isAssigned",
    "deployedAppCount", "apps", "assignments",
  ]
}

data "http" "oib_byod" {
  for_each = local.oib_byod_files
  url      = "${local.oib_byod_base}/${replace(replace(each.value, " ", "%20"), "+", "%2B")}"   # names contain spaces and "+"
}

locals {
  oib_byod_body = {
    for k, v in data.http.oib_byod : k => {
      for key, value in jsondecode(v.response_body) : key => value
      if (!contains(local.oib_readonly_keys, key)
      && !startswith(key, "#")
      && (key == "@odata.type" || !strcontains(key, "@odata.")))
    }
  }
}
```


---

## 4. Workshop steps

Add each block below to [`experimental-workforce/experimental-workforce-01.tf`](../../experimental-workforce-01.tf).

### 4.1 Pilot group

```hcl
resource "azuread_group" "byod_pilot" {
  display_name     = "TF.Workshop.${var.deployment_unique_name}-BYOD.Pilot"
  security_enabled = true
}
```

Add your test user to this group (portal, or `azuread_group_member`).

### 4.2 Assignment filters (Managed apps, unmanaged devices)

OIB rule: `(app.deviceManagementType -eq "Unmanaged")`. Without the filter, the policies also hit
**enrolled** devices, which is not what you want for BYOD.

```hcl
locals {
  byod_filter_platforms = {
    android = "androidMobileApplicationManagement"
    ios     = "iOSMobileApplicationManagement"
  }
}

resource "msgraph_resource" "byod_filter" {
  for_each    = local.byod_filter_platforms
  api_version = "beta"
  url         = "deviceManagement/assignmentFilters"
  body = {
    displayName                    = "TF.Workshop.${var.deployment_unique_name}-BYOD.${each.key}.Unmanaged"
    description                    = "OIB BYOD prerequisite - unmanaged (not enrolled) devices only"
    platform                       = each.value
    assignmentFilterManagementType = "apps"
    rule                           = "(app.deviceManagementType -eq \"Unmanaged\")"
  }
}
```

### 4.3 App protection policies from the OIB JSON

```hcl
locals {
  byod_app_protection_collection = {
    android = "deviceAppManagement/androidManagedAppProtections"
    ios     = "deviceAppManagement/iosManagedAppProtections"
  }
}

resource "msgraph_resource" "byod_app_protection" {
  for_each    = local.byod_app_protection_collection
  api_version = "beta"
  url         = each.value
  body = merge(local.oib_byod_body[each.key], {
    # Keep the OIB name so OIB Deployer / TenuVault can still recognise the policy; add a
    # description that records where it came from.
    description = "Deployed by Terraform from OpenIntuneBaseline ${var.oib_byod_tag} (GPL-3.0)"
  })
}
```

### 4.4 Assign with the filter

App protection assignments are written through the `assign` **action**, not as a property:

```hcl
resource "msgraph_resource_action" "byod_assign" {
  for_each     = msgraph_resource.byod_app_protection
  api_version  = "beta"
  resource_url = "${local.byod_app_protection_collection[each.key]}/${each.value.id}"
  action       = "assign"
  method       = "POST"
  body = {
    assignments = [{
      target = {
        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
        groupId                                    = azuread_group.byod_pilot.object_id
        deviceAndAppManagementAssignmentFilterId   = msgraph_resource.byod_filter[each.key].id
        deviceAndAppManagementAssignmentFilterType = "include"
      }
    }]
  }
}
```

### 4.5 Conditional Access (OIB prerequisites)

Start both in **report-only** (`var.byod_require_app_protection`), check the sign-in logs, then switch
to `enabled`.

```hcl
resource "azuread_conditional_access_policy" "byod_require_app_protection" {
  display_name = "TF.Workshop.${var.deployment_unique_name}-BYOD.RequireAppProtection"
  state        = var.byod_require_app_protection

  conditions {
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]

    users {
      included_groups = [azuread_group.byod_pilot.object_id]
      excluded_users  = var.ca_break_glass_object_ids
    }

    applications {
      included_applications = ["Office365"]
    }

    platforms {
      included_platforms = ["android", "iOS"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["compliantApplication"]   # "Require app protection policy"
  }
}

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "TF.Workshop.${var.deployment_unique_name}-BlockLegacyAuth"
  state        = var.byod_require_app_protection

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    users {
      included_groups = [azuread_group.byod_pilot.object_id]
      excluded_users  = var.ca_break_glass_object_ids
    }

    applications {
      included_applications = ["All"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
```

> `compliantApplication` is the Graph name of **Require app protection policy**
> (`approvedApplication` is *Require approved client app*). Use it only for iOS/Android here; Edge on
> Windows MAM is a separate scenario.

### 4.6 Apply

```powershell
terraform plan
terraform apply
```

---

## 5. Verification

- [ ] Intune admin center → **Apps → App protection policies** shows both `… - OIB - App Protection - U - BYOD L2+ - v2.0` policies.
- [ ] Each policy is assigned to `TF.Workshop.<name>-BYOD.Pilot` with the matching **Unmanaged** filter set to *Include*.
- [ ] Settings in the portal match the OIB JSON (spot check: printing **Blocked**, PIN length **6**, jailbroken → **Wipe data**).
- [ ] On the unenrolled test phone, sign in to **Outlook** → the app asks for an App PIN; copy/paste from Outlook into a personal app is blocked.
- [ ] Entra **Sign-in logs** → Conditional Access tab shows `RequireAppProtection` in report-only (`Report-only: Failure` is expected before the app is protected).
- [ ] (Optional) Use [IntuneComplianceMaintainer](https://github.com/SkipToTheEndpoint/IntuneComplianceMaintainer) to add the Min OS version conditional launch that OIB leaves out.

## Known limitations (experimental)

- Graph **beta** endpoints; property names can change.
- `msgraph_resource` compares the body you send with what Graph returns. Intune adds defaults on create,
  so expect some plan noise; add `ignore_changes`/`response_export_values` tuning where needed.
- Updating the OIB tag (e.g. a future `byod-v2.1`) changes the policy *name* - the name contains the
  version - which results in an in-place update of the same object, not a new policy. Decide if that's
  what you want, or key the resource on the version.

## References

- OIB BYOD README and change log: <https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/BYOD>
- [Data protection framework using app protection policies](https://learn.microsoft.com/en-us/intune/app-management/protection/data-protection-framework)
- [Create iosManagedAppProtection (Graph beta)](https://learn.microsoft.com/graph/api/intune-shared-iosmanagedappprotection-create?view=graph-rest-beta)
- [Create deviceAndAppManagementAssignmentFilter (Graph beta)](https://learn.microsoft.com/graph/api/intune-policyset-deviceandappmanagementassignmentfilter-create?view=graph-rest-beta)
- [Require approved client apps or app protection policy](https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-approved-app-or-app-protection)
- [Block legacy authentication](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-block-legacy-authentication)

---
**Navigation:** [← Experimental Workforce path](../../README.md) | [Experimental-Workforce-02: WINDOWS →](../experimental-workforce-02/README.md)
