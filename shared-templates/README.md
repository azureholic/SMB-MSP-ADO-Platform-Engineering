# Shared templates

This repository contains the shared Azure DevOps pipeline template and shared Bicep modules used by all customer repositories.

## Contents

| File                      | Description                                                        |
|---------------------------|--------------------------------------------------------------------|
| `azure-pipelines.yml`     | Reusable pipeline template — creates the resource group and runs a Bicep deployment |
| `infra/main.bicep`        | Main Bicep template — deploys a virtual network via the `vnet` module |
| `infra/modules/vnet.bicep`| VNet module — creates a virtual network with configurable subnets  |

## Pipeline parameters

The pipeline template accepts the following parameters from the consuming customer repo:

| Parameter            | Type   | Description                                       |
|----------------------|--------|---------------------------------------------------|
| `serviceConnection`  | string | Azure DevOps service connection name              |
| `resourceGroupName`  | string | Target resource group (created if it doesn't exist) |
| `location`           | string | Azure region                                      |
| `parameterFile`      | string | Path to the customer's Bicep parameter file       |

## Usage

Customer repositories extend this pipeline and provide their own parameter file:

```yaml
resources:
  repositories:
  - repository: templates
    type: git
    name: platform-engineering/shared-templates
    # ref: refs/tags/v1.0.0

extends:
  template: azure-pipelines.yml@templates
  parameters:
    serviceConnection: sc-connection-contoso
    resourceGroupName: rg-contoso-demo
    location: uksouth
    parameterFile: infra/demo.parameters.json
```

> [!TIP]
> Pin consumers to a tag or branch ref so shared changes are adopted deliberately.