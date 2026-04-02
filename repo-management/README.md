# Repo Management

Scripts for onboarding new customers to the platform. Handles Azure resource provisioning, Azure DevOps repo/pipeline creation, and workload identity federation — all in a single command.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with the `azure-devops` extension
- Git
- The identity you use for `az login` **must** have:
  - **Azure subscription**: permissions to create resource groups, managed identities, and role assignments (e.g. Owner or User Access Administrator + Contributor)
  - **Azure DevOps**: permissions to create repositories, pipelines, and service connections in the target project (e.g. Project Administrator)

## Configuration

### `devops.config.json`

Central configuration file for Azure DevOps settings. All scripts read from this file instead of hardcoding values.

| Property      | Description                                      | Example                                |
|---------------|--------------------------------------------------|----------------------------------------|
| `orgUrl`      | Full URL of the Azure DevOps organization        | `https://dev.azure.com/azureholic`     |
| `projectName` | Name of the Azure DevOps project                 | `platform-engineering`                 |

Update this file if the organization or project changes.

## Scripts

### `New-Customer.ps1`

End-to-end customer onboarding script. Prompts for customer name, Azure location, and tenant ID, then:

1. Logs in to Azure (`az login --tenant`) — you pick the subscription interactively
2. Creates `rg-devops-identity` resource group
3. Creates a User-Assigned Managed Identity (`id-devops-<customer>`)
4. Assigns **Owner** role on the subscription
5. Creates an Azure DevOps repo (`customer-<customer>`)
6. Creates a WIF service connection (`sc-connection-<customer>`) — no secrets
7. Retrieves the issuer & subject from the service connection response
8. Creates a federated credential on the Managed Identity
9. Scaffolds the customer repo from `customer-template` (replaces placeholders)
10. Pushes to Azure DevOps and creates the pipeline

```powershell
.\New-Customer.ps1
```

### `New-CustomerRepo.ps1` / `Prep-CustomerEnvironment.ps1`

Legacy scripts (predecessor to `New-Customer.ps1`). Kept for reference — use `New-Customer.ps1` instead.