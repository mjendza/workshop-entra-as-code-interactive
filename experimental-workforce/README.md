# Experimental: Workforce Intune Baseline as Code

> ⚠️ **Experimental.** This path is independent of the Workforce (Stages 0-19), External ID and
> Verified ID paths. It has its own Terraform root (this folder), its own Service Principal and its
> own stage numbering. It is not part of the generated workshop issues yet.

Manage Microsoft Intune device and app protection policies in a **Workforce** tenant as code, using
the community **OpenIntuneBaseline (OIB)** as the reference implementation.

## Reference implementation and license

| | |
|---|---|
| Repository | [SkipToTheEndpoint/OpenIntuneBaseline](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline) |
| Author | James ([SkipToTheEndpoint](https://skiptotheendpoint.co.uk)), Microsoft MVP in Intune and Windows |
| Documentation | [docs.openintunebaseline.com](https://docs.openintunebaseline.com) |
| License | **GPL-3.0** |

OpenIntuneBaseline is licensed under **GPL-3.0**, so it can be used as the reference for this
workshop. This workshop repository is MIT-licensed, so the OIB policy JSON files are **not copied
(vendored) into this repo**. Terraform downloads them at plan time from a **pinned release tag**
(`byod-v2.0`, `windows-v4.0`, `win365-v1.0`) using the `hashicorp/http` data source. If you fork this
path and decide to commit the OIB JSON (or modified versions of it), those files stay under GPL-3.0
and you must keep the license and copyright notices.

The OIB itself says: *"No liability is assumed for the usage or application of the settings within
this project in production tenants."* Use a **development tenant**.

## Stages

| Step | Title | OIB folder / release | Description |
|---|---|---|---|
| [experimental-workforce-01](doc/experimental-workforce-01/README.md) | BYOD - App Protection | [`BYOD`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/BYOD) · `byod-v2.0` (stable) | Prerequisites (Service Principal + Intune permissions), then Android and iOS "BYOD L2+" app protection policies, *Managed apps* assignment filters for unmanaged devices, and Conditional Access requiring an app protection policy. |
| [experimental-workforce-02](doc/experimental-workforce-02/README.md) | WINDOWS - Entra joined Windows 11 | [`WINDOWS`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS) · `windows-v4.0` (stable) | A representative subset of the Windows OIB as code: compliance policies, Windows Update for Business rings and selected Settings Catalog profiles, driven from `PolicyManifest.json`. |
| [experimental-workforce-03](doc/experimental-workforce-03/README.md) | WINDOWS365 - Cloud PC add-on | [`WINDOWS365`](https://github.com/SkipToTheEndpoint/OpenIntuneBaseline/tree/main/WINDOWS365) · `win365-v1.0` (unstable) | The Windows 365 additions on top of stage 02: connectivity and resource redirection Settings Catalog profiles and the Cloud PC compliance policy, plus the exclusions from the Windows baseline. |

## Folder layout

```
experimental-workforce/
├── README.md                       # this file
├── provider.tf                     # azuread + msgraph + http
├── variables.tf
├── terraform.tfvars
├── experimental-workforce-01.tf    # BYOD        (starts empty - fill it in stage 01)
├── experimental-workforce-02.tf    # WINDOWS     (starts empty - fill it in stage 02)
├── experimental-workforce-03.tf    # WINDOWS365  (starts empty - fill it in stage 03)
├── tests/plan.tftest.hcl           # offline plan, mocked azuread/msgraph/http
└── doc/
    ├── experimental-workforce-01/README.md
    ├── experimental-workforce-02/README.md
    ├── experimental-workforce-03/README.md
    └── result/                     # final solution of all three stages
        ├── experimental-workforce-0{1,2,3}.tf
        └── tests/final.tftest.hcl  # assertions for the final solution
```

## Dev container

[`.devcontainer/experimental-workforce/`](../.devcontainer/experimental-workforce) is a dev container
just for this path: Ubuntu 24.04 with Terraform 1.13.4 and TFLint 0.59.1 (the same versions as
`scripts/ci/install-tools.sh`) plus the HashiCorp Terraform and REST Client VS Code extensions. Every
tool is installed in the Dockerfile, without devcontainer features, so a plain `docker build` gives
you the same toolbox.

- **VS Code:** *Dev Containers: Reopen in Container* → **Experimental Workforce (Intune)**.
- **Codespaces:** *New with options* → dev container configuration **Experimental Workforce (Intune)**.

## Offline tests (no tenant needed)

`scripts/ci/validate.sh experimental-workforce` runs `init → fmt -check → validate → test → tflint`
on a temporary copy of the repo. Every provider is mocked, and so is the OIB JSON download, so you need
no credentials and no network apart from the provider download. Without `NO_FINAL`, the script first
copies `doc/result/*.tf` and `doc/result/tests/*.tftest.hcl` over the starter files.

This path is **opt-in**. It is not part of the default solution list and not in the
`terraform-ci.yml` matrix.

```bash
# inside the dev container
NO_FINAL=1 bash scripts/ci/validate.sh experimental-workforce   # starter files as-is
bash scripts/ci/validate.sh experimental-workforce              # final solution
```

```powershell
# Windows, via WSL (from the repo root)
wsl -e bash scripts/ci/install-tools.sh                     # once: terraform + tflint into ~/.local/bin
wsl -e bash scripts/ci/validate.sh experimental-workforce

# or the dev container image, via Docker in WSL
wsl -e bash -lc 'docker build -t ew-devcontainer .devcontainer/experimental-workforce &&
  docker run --rm -v "$PWD":/workspaces/ws -w /workspaces/ws ew-devcontainer bash -c \
  "git config --global --add safe.directory /workspaces/ws && bash scripts/ci/validate.sh experimental-workforce"'
```

## Requirements (whole path)

- A Workforce tenant with an **active Intune license**. Microsoft Graph Intune APIs fail without it.
- **Entra ID P1** for Conditional Access (stage 01) and for the Windows/Windows 365 scenarios.
- Stage 02: Windows 11 Enterprise test devices that are **Autopilot-enrolled and Microsoft Entra
  joined** (the Windows OIB is **not** designed for hybrid-joined devices).
- Stage 03: a **Windows 365 Enterprise** license and a provisioning policy.
- Terraform ≥ 1.6, plus the tooling from [Stage 0](../doc/stage-00/README.md).
- No Azure subscription is needed.
