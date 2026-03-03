# Entra as Code Workshop

Manage your Entra ID tenant using Infrastructure as Code. This workshop supports both Workforce and Customer (External ID) instances.

## Interactive Workshop Mode (via GitHub Template)

This workshop features **interactive progress tracking via GitHub Issues**. Each stage of the workshop automatically generates a dedicated issue containing:
- Detailed documentation and instructions
- Checkboxes to track your progress
- Labels for easy filtering and organization

## Important Risks and Warnings

**Stage 7** applies changes at the tenant level, which will affect all users in your Entra ID tenant. Please exercise caution. We highly recommend running this step in a development tenant or skipping it entirely if you are using a production environment.

**Stage 8** utilizes Microsoft Graph beta endpoints. If you encounter any issues, please submit a ticket.

### Getting Started with Interactive Mode

1. [![](https://img.shields.io/badge/COPY%20Workshop-%E2%86%92-1f883d?style=for-the-badge&logo=github&labelColor=197935)](https://github.com/new?template_owner=mjendza&template_name=workshop-entra-as-code-interactive&owner=%40me&name=workshop-entra-as-code&description=Workshop:+Entra+ID+as+Code&visibility=public)

2. **Create your repository from the template.** Once created, a GitHub Actions pipeline will automatically generate the workshop issues for you.
   - Navigate to the **Issues** tab in your new repository.

3. **Track Your Progress:**
   - Each stage is represented by a dedicated issue.
   - Mark the checkboxes as you complete the corresponding tasks.
   - Close the issue once all tasks in the stage are finished.

4. **Recommended Workflow:**
   | Step | Action |
   |------|--------|
   | 1 | Open the stage issue |
   | 2 | Read the documentation |
   | 3 | Complete all tasks |
   | 4 | Check all checkboxes |
   | 5 | Close the issue |
   | 6 | Move to the next stage |

> **Tip:** Use the issue comments to jot down any problems encountered or lessons learned during each stage!

## Changelog 
| Version | Date       | Description                                        |
|---------|------------|----------------------------------------------------|
| v0.8    | 2025.04.28 | Alpha release                                      |
| v0.9    | 2025.05.07 | Beta - dryrun                                      |
| v0.9.1  | 2025.05.16 | Enhanced for self-paced workshops: added more images and detailed descriptions |
| v0.10   | 2026.01.03 | Corrected typos, improved documentation, and updated provider versions |
| v1.0    | 2026.01.05 | 🎆 Initial public release                          |
| v1.1    | 2026.02.19 | Added Stage 7 (Tenant configuration and security changes) using the microsoft/msgraph provider |
| v1.2    | 2026.02.24 | Added Stage 8 (Entra ID Agent) using the microsoft/msgraph provider |

## Frequently Asked Questions (FAQ)

| Question                                           | Answer                                                                       |
|----------------------------------------------------|------------------------------------------------------------------------------|
| Do I need an Entra ID Tenant?                      | Yes, if you are running the workshop on your own. No, if you are participating in a guided online or onsite session (one will be provided). |
| Do I need an Azure Subscription?                   | No, this workshop focuses exclusively on Entra ID.                            |
| Do I need to have a Workforce or an External ID tenant? | The entire workshop is designed for a Workforce tenant. Stages 1-4 are also compatible with an External ID tenant. |
| Do I need the Global Admin role?                   | Yes, Global Administrator privileges are required.                           |
| Is the workshop designed to teach me Terraform?    | No, the primary focus is learning how to manage Entra ID using Infrastructure as Code (Terraform), rather than teaching Terraform from scratch. |

## Prerequisites

### Technical Requirements
- ✅ An [Entra ID Tenant](https://www.microsoft.com/en-gb/security/business/identity-access/microsoft-entra-id).
- ✅ **Global Administrator** or **Authentication Policy Administrator** role.
- ✅ An **Entra ID P1 or P2 license** (required for Stages 4-6: Conditional Access, Access Packages, and PIM).
- ✅ **Security Defaults MUST be disabled** in your tenant (required for Conditional Access in Stage 4).

- ✅ [Visual Studio Code](https://code.visualstudio.com/) (VS Code).
- ✅ Terraform v1.0 or newer.
- ✅ Git (for cloning the repository).
- ✅ A workstation (All flows were tested on Windows, but macOS or Linux should also work).

### Recommended Basic Skills
- ✅ Familiarity with scripting and command-line interfaces.
- ✅ An understanding of Service Principal authentication concepts.
- ✅ General experience navigating the Azure Portal or Entra Admin Center.

## Workshop Objectives
- Authenticate programmatically using a Service Principal.
- Provision and configure core Entra ID resources using Terraform.
- Understand the current limitations of Managing Entra ID via IaC.

**Estimated Duration:** 90–120 minutes.

## Workshop Outline
1. Set up the workstation environment
2. Create a Service Principal
3. Prepare the Terraform file structure
4. First Terraform resource and module 
5. Execute Terraform Init, Plan, and Apply
6. Provision multiple Entra ID resources
7. Integrate with Spacelift.io for CI/CD

## Environment Setup Guide

### Installing Prerequisites

#### Visual Studio Code
```shell
winget install Microsoft.VisualStudioCode
```

#### Terraform
```shell
winget install HashiCorp.Terraform
```

### Recommended VS Code Extensions
- [Terraform](https://marketplace.visualstudio.com/items/?itemName=HashiCorp.terraform)
- [REST Client](https://marketplace.visualstudio.com/items/?itemName=humao.rest-client)
 
### Basic Terraform Commands Reference

**Initialize a working directory:**
```shell
terraform init
```

**Generate and show an execution plan:**
```shell
terraform plan
```

**Build or change infrastructure:**
```shell
terraform apply
```

**Destroy previously-created infrastructure:**
```shell
terraform destroy
```

## Out of Scope
- Licensing costs associated with Terraform configurations (if applicable).
- Remote State Management for Terraform.
- Advanced secret management practices for Entra ID tenant and Azure subscription credentials (e.g., securely storing `client_id` and `client_secret`).

## Troubleshooting

| Issue                                | Solution                                                                    |
|--------------------------------------|-----------------------------------------------------------------------------|
| No changes in the Terraform plan.    | Ensure that you have saved your changes in the `main.tf` file before running the plan. |
| Can't remove(destroy) the resources. | Check your Access Package assignments. You must remove all active assignments to your package before it can be destroyed. |
| `Error: Module not installed`        | Run `terraform init` to download and install all modules required by your configuration. |

## Feedback and Support
Did you find a bug, have a question, or want to suggest an improvement? Please open an issue in the interactive workshop repository:

**[https://github.com/mjendza/workshop-entra-as-code-interactive/issues](https://github.com/mjendza/workshop-entra-as-code-interactive/issues)**
