# Developer Guide

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.0)
- [TFLint](https://github.com/terraform-linters/tflint#installation)

## Running the Linter

### 1. Initialize Terraform providers

```bash
terraform init -backend=false
```

### 2. Format Terraform files

Recursively format all `.tf` files in the repository:

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

Install the TFLint plugin defined in `.tflint.hcl`, then run the linter:

```bash
tflint --init
tflint --recursive
```
