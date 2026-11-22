# Developer Guide

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.0)
- [TFLint](https://github.com/terraform-linters/tflint#installation)

## Running the Linter

Each Terraform root is linted separately: `workforce/` (Path 1), `external_tenant/` (Path 2) and `verified_id/` (Path 3). Run the steps below inside the root you changed (e.g. `cd workforce`), or run everything at once like CI does:

```bash
wsl -e bash scripts/ci/validate.sh                 # all roots
wsl -e bash scripts/ci/validate.sh workforce       # one root
```

### 1. Initialize Terraform providers

```bash
terraform init -backend=false
```

### 2. Format Terraform files

Recursively format all `.tf` files in the current Terraform root:

```bash
terraform fmt -recursive
```

### 3. Check formatting

Verify that all files are properly formatted (useful in CI):

```bash
terraform fmt -check -recursive
```

### 4. Validate configuration

```bash
terraform validate
```

### 5. Run TFLint

Install the TFLint plugin defined in the repo-root `.tflint.hcl`, then lint the Terraform root:

```bash
tflint --init
cd workforce && tflint --recursive
```

## Terraform state

Removing, re-creating and importing items in the state: [terraform.md](terraform.md).
