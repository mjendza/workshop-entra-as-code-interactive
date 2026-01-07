# Entra as a Code Workshop
Manage your Tenant with Infrastructure as Code: it works for Workforce and Customer instances

## Interactive Workshop Mode (via GitHub Temaplate)

This workshop supports **interactive tracking via GitHub Issues**! Each stage creates a dedicated issue with:
- Full documentation and instructions
- Progress checkboxes to track your completion
- Labels for easy filtering

### How to Start Interactive Mode

1. ![Static Badge](https://img.shields.io/badge/COPY?style=flat)

2. **Copy the workshop to your account - the pipeline will create GitHub Issues:**
   - Go to **Issues** tab

3. **Track Your Progress:**
   - Each stage has its own GitHub Issue with checkboxes
   - Check the boxes as you complete each step
   - Close the issue when you finish the stage

4. **Recommended Workflow:**
   | Step | Action |
   |------|--------|
   | 1 | Open the stage issue |
   | 2 | Read the documentation |
   | 3 | Complete all tasks |
   | 4 | Check all checkboxes |
   | 5 | Close the issue |
   | 6 | Move to next stage |

> **Tip:** Use the issue comments to note any problems or learnings during each stage!

## Changelog 
| Version | Date       | Description                                        |
|---------|------------|----------------------------------------------------|
| v0.8    | 2025.04.28 | Alpha                                              |
| v0.9    | 2025.05.07 | Beta - dryrun                                      |
| v0.9.1  | 2025.05.16 | For Self-Workshop: more pictures and description   |
| v0.10  | 2026.01.03 | Typos and doc improvment & update provider version |
| v1.0  | 2026.01.05 | 🎆 Public repository version |

## Q&A
| Question                                           | Answer                                                                       |
|----------------------------------------------------|------------------------------------------------------------------------------|
| Do I need an Entra ID Tenant?                      | Yes, when you run a workshop on your own; no, during an online or onsite workshop. |
| Do I need an Azure Subscription?                   | No, we will use Entra ID only.                                               |
| Do I need to have a Workforce or an External ID tenant? | All steps are for Workforce, 1-4 will work with the External ID tenant.          |
| Do I need the Global Admin role?                       | Yes.                                                                         |
| Is the workshop to learn Terraform?                | No, the workshop is to manage Entra ID as code with Terraform.               |

## Prerequisites
### Technical
- ✅ [Entra ID Tenant](https://www.microsoft.com/en-gb/security/business/identity-access/microsoft-entra-id)
- ✅ A global administrator or the authentication policy administrator permission is required.
- ✅ **Entra ID P1 or P2 license** (required for Stages 4-6: Conditional Access, Access Packages, PIM)
- ✅ **Security Defaults disabled** in tenant (required for Stage 4: Conditional Access)

- ✅ VSCode
- ✅ Terraform (v1.0+)
- ✅ Git (to clone the repository)
- ✅ Windows Workstation (all flows I tested on Windows - but you can use any OS)
  
### Entra ID Permissions (cumulative per stage)
| Stage | Required Graph API Permissions |
|-------|-------------------------------|
| 0-3 | `Application.ReadWrite.All` |
| 4   | + `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` |
| 5   | + `EntitlementManagement.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All` |
| 6   | + `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup` |

### Skills (Basic)
- ✅ Basic knowledge of scripting and the command line
- ✅ Basic understanding of Service Principal Authentication
- ✅ Familiarity with Azure Portal navigation


## Achievements
- Authenticate with service access (Service Principal)
- Set up basic Entra ID elements with Terraform.
- Understand limitations.

## Total Workshop Duration: ~90-120 minutes

## Workshop key points
1. Set up the workstation environment
2. Create a Service Principal
3. Prepare the Terraform file structure
4. First Terraform resource and module 
5. Init&Plan&Apply
6. Create a couple of Entra ID resources
7. Spacelift.io for integration

## Workshop
### Prerequisites installation
VS Code
```
winget install Microsoft.VisualStudioCode
```
Terraform
```
winget install HashiCorp.Terraform
```

#### VS Code extensions
- [Terraform](https://marketplace.visualstudio.com/items/?itemName=HashiCorp.terraform)
- [REST Client](https://marketplace.visualstudio.com/items/?itemName=humao.rest-client)

 
### Terraform basic command
init
```
terraform init
```
plan
```
terraform plan
```
apply
``` 
terraform apply
```
destroy
``` 
terraform destroy
```


## Excluded and not covered in this workshop
- Cost of the Terraform license (if any).
- Manage the Terraform state file.
- Secret management (client_id and client_secret) access to Entra ID tenant and Azure subscription (not covered at all).

## Troubleshooting
| Issue                                | Solution                                                                    |
|--------------------------------------|-----------------------------------------------------------------------------|
| No changes in the Terraform plan.    | Always be sure to save the changes in the `main.tf`.                        |
| Can't remove(destroy) the resources. | Check Access Package assignments. Remove all assignments to your package.   |
| `Error: Module not installed`        | Run "terraform init" to install all modules required by this configuration. |

## Report Issues
Found a bug, have a question, or want to suggest an improvement? Please report any issues with the workshop at:

**[https://github.com/mjendza/workshop-entra-as-code-interactive/issues](https://github.com/mjendza/workshop-entra-as-code-interactive/issues)**
