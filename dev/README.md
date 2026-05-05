# Developer Guide

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.0)
- [TFLint](https://github.com/terraform-linters/tflint#installation)

## Running the Linter

### 1. Initialize Terraform providers

```bash
terraform init -backend=false
```

### 2. Check formatting

```bash
terraform fmt -check -recursive
```

To auto-fix formatting issues:

```bash
terraform fmt -recursive
```

### 3. Validate configuration

```bash
terraform validate
```

### 4. Run TFLint

Install the TFLint plugin defined in `.tflint.hcl`, then run the linter:

```bash
tflint --init
tflint --recursive
```
