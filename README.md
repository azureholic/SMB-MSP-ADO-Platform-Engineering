# Platform Engineering — Azure DevOps

This repository contains the source for a platform engineering setup in Azure DevOps.

> [!CAUTION]
> In Azure DevOps, each top-level folder lives as a **separate repository** within the same project.

| Azure DevOps repo      | Folder in this repo      | Purpose                                                                 |
|-------------------------|--------------------------|-------------------------------------------------------------------------|
| `shared-templates`      | `shared-templates/`      | Reusable Azure DevOps pipeline template and shared Bicep modules        |
| `customer-template`     | `customer-template/`     | Bootstrap template used to scaffold new customer repositories           |
| `repo-management`       | `repo-management/`       | PowerShell scripts and configuration for onboarding new customers       |

## How it works

1. **`repo-management`** contains `New-Customer.ps1`, which automates end-to-end customer onboarding: Azure resource provisioning (resource group, managed identity, role assignment), Azure DevOps repo and pipeline creation, and workload identity federation — all without secrets.
2. **`customer-template`** is the blueprint that `New-Customer.ps1` copies when scaffolding a new customer repo. It includes a thin pipeline entrypoint, a demo parameter file, and an onboarding checklist.
3. **`shared-templates`** holds the reusable pipeline definition and shared Bicep infrastructure. Customer repos extend the pipeline template via an Azure DevOps `resources.repositories` reference and supply their own parameter files.

## Repo structure

```
project (Azure DevOps)
├── shared-templates        # Reusable pipeline + Bicep modules
│   ├── azure-pipelines.yml
│   └── infra/
├── customer-template       # Scaffold for new customer repos
│   ├── azure-pipelines.yml
│   ├── docs/
│   └── infra/
└── repo-management         # Onboarding automation
    ├── New-Customer.ps1
    └── devops.config.json
```

## Getting started

1. Update `repo-management/devops.config.json` with your Azure DevOps organization URL and project name.
2. Run `repo-management/New-Customer.ps1` to onboard a new customer — it will prompt for customer name, Azure location, and tenant ID.
3. The script creates the Azure resources, scaffolds a customer repo from the template, and wires up the pipeline with a workload identity federation service connection.

See each folder's README for more details.
