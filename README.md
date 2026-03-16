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

   | Step | Action                 |
   |------|------------------------|
   | 1    | Open the stage issue   |
   | 2    | Read the documentation |
   | 3    | Complete all tasks     |
   | 4    | Check all checkboxes   |
   | 5    | Close the issue        |
   | 6    | Move to the next stage |

> **Tip:** Use the issue comments to jot down any problems encountered or lessons learned during each stage!

## Steps

| Step    | Title                                | Description                                                                                                                                                                                                                                                                        |
|---------|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0       | Prerequisites                        | Create a Service Principal and client secret in the Azure Portal to be used in subsequent stages. Start with minimal permissions and retrieve your corresponding Entra ID administrative credentials.                                                                              |
| 1       | SSO Application                      | Automate the deployment of an App Registration configured for Single Sign-On with the OIDC Debugger using Terraform. Manually generate a client secret for the application. You will then observe and test authentication flows.                                                   |
| 2       | Service Principal                    | Automate the provisioning of a backend Service Principal using Terraform in Entra ID. This stage explores the manual component of application secret generation.                                                                                                                   |
| 3       | Workload Federation                  | Provision a Service Principal in Entra ID using Terraform with Workload Identity Federation actively enabled. This demonstrates authentication without requiring explicit secret generation or management. Utilize the token issuer configuration for cross-system token exchange. |
| 4       | Conditional Access                   | Automate the assignment of a Conditional Access policy specifically bound to the OidcDebugger SSO application. This will enforce rigid network segmentation. It also formally scopes authorization using a predefined geographic country configuration block.                      |
| 5       | Access Package                       | Provision an Entra ID Access Package structured to formalize onboarding mechanics routing into a centralized group. This facilitates the automated binding for self-service validated users.                                                                                       |
| 6       | Privileged Identity Management (PIM) | Utilize Privileged Identity Management to actively enforce Eligible Assignments rather than static access. Authorized users will physically elevate themselves directly into a higher-privileged tier.                                                                             |
| 7       | Tenant Security Hardening            | Restrict guest invitations and block standard users from creating app registrations and security groups. These restrictive tenant-wide resources will be applied using the microsoft/msgraph provider.                                                                             |
| 8       | Entra Agent Identity (Preview)       | Create an Agent Identity Blueprint via Terraform and provision an Agent Identity Blueprint Principal. Deploy an Agent Identity and optionally an Agent User using Microsoft Graph beta endpoints.                                                                                  |
| 9       | Maester                              | Automate the provisioning of a Service Principal with the required Maester permissions using Terraform. Run automated Maester tests to validate your tenant configuration against baseline security policies.                                                                      |
| 10      | EntraExporter                        | Establish a baseline snapshot of your current Entra ID configuration by provisioning a Service Principal using Terraform. Export your tenant's configuration to JSON files to understand its current state.                                                                        |
| 11      | Zero Trust Assessment                | Automate the provisioning of a Service Principal with the required ZeroTrustAssessment permissions using Terraform. Review the assessment results to proactively understand your tenant's security posture and identify areas for improvement.                                     |
| 12      | Diff                                 | Combine Maester and EntraExporter to implement a diff-based workflow for configuration change detection. This will allow you to compare Entra ID configurations using diff analysis to detect changes between Terraform runs.                                                      |
| 13      | Lokka                                | Automate the provisioning of a Service Principal with Lokka MCP permissions using Terraform in Entra ID. Prepare configurations for GitHub Copilot VS Code and NanoBot. This allows you to explore Entra ID configurations using natural language.                                 |
| Cleanup | Architecture Disassembly             | Execute a broad programmatic tracking destruction mapping using Terraform destroy. Formally complete the deployment workshop and zero the environment successfully. This safely removes all provisioned resources.                                                                 |

## Changelog 
| Version | Date       | Description                                                                                    |
|---------|------------|------------------------------------------------------------------------------------------------|
| v0.8    | 2025.04.28 | Alpha release                                                                                  |
| v0.9    | 2025.05.07 | Beta - dryrun                                                                                  |
| v0.9.1  | 2025.05.16 | Enhanced for self-paced workshops: added more images and detailed descriptions                 |
| v0.10   | 2026.01.03 | Corrected typos, improved documentation, and updated provider versions                         |
| v1.0    | 2026.01.05 | 🎆 Initial public release                                                                      |
| v1.1    | 2026.02.19 | Added Stage 7 (Tenant configuration and security changes) using the microsoft/msgraph provider |
| v1.2    | 2026.02.24 | Added Stage 8 (Entra ID Agent) using the microsoft/msgraph provider                            |
| v1.3    | 2026.03.02 | Added Stage 9 (Maester)                                                                        |
| v1.4    | 2026.03.03 | Added Stage 10 (EntraExporter)                                                                 |
| v1.5    | 2026.03.04 | Added Stage 11 (Zero Trust Assessment)                                                         |
| v1.6    | 2026.03.11 | Added Stage 12 DIFF via Maester (Maester + EntraExporter)                                      |
| v1.6    | 2026.03.12 | Added Stage 13 (Lokka MCP)                                                                     |
| v1.6.1  | 2026.03.13 | Updated Stage 13 Lokka MCP configurations for GitHub Copilot VS Code and NanoBot integrations  |



## Frequently Asked Questions (FAQ)

| Question                                                | Answer                                                                                                                                                                                                                                                                                  |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Do I need an Entra ID Tenant?                           | Yes, if you are running the workshop on your own. No, if you are participating in a guided online or onsite session (one will be provided).                                                                                                                                             |
| Do I need an Azure Subscription?                        | No, this workshop focuses exclusively on Entra ID.                                                                                                                                                                                                                                      |
| Do I need to have a Workforce or an External ID tenant? | The entire workshop is designed for a Workforce tenant. Stages 1-4 are also compatible with an External ID tenant.                                                                                                                                                                      |
| Do I need the Global Admin role?                        | Yes, Global Administrator privileges are required.                                                                                                                                                                                                                                      |
| Is the workshop designed to teach me Terraform?         | No, the primary focus is learning how to manage Entra ID using Infrastructure as Code (Terraform), rather than teaching Terraform from scratch.                                                                                                                                         |
| Do I need to use terraform to complete all stages?      | No, while Terraform is the primary tool used in the workshop, some stages may involve using other tools or scripts (e.g., PowerShell for generating secrets). However, the majority of the workshop is designed around Terraform. Maester, ZTA, Lokka can be managed without Terraform. |


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

**Estimated Duration:** 180–240 minutes.

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

| Issue                                | Solution                                                                                                                  |
|--------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| No changes in the Terraform plan.    | Ensure that you have saved your changes in the `main.tf` file before running the plan.                                    |
| Can't remove(destroy) the resources. | Check your Access Package assignments. You must remove all active assignments to your package before it can be destroyed. |
| `Error: Module not installed`        | Run `terraform init` to download and install all modules required by your configuration.                                  |

## Feedback and Support
Did you find a bug, have a question, or want to suggest an improvement? Please open an issue in the interactive workshop repository:

**[https://github.com/mjendza/workshop-entra-as-code-interactive/issues](https://github.com/mjendza/workshop-entra-as-code-interactive/issues)**
