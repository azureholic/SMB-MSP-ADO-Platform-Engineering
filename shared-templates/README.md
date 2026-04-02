# Shared templates

This repository contains the shared Azure DevOps pipeline template and the shared Bicep template used by customer repositories.

## Contents

- `azure-pipelines.yml`: reusable Azure DevOps pipeline template
- `infra/main.bicep`: shared Azure resource deployment template

## Usage

Customer repositories should:

1. Reference this repository as a template repository in Azure DevOps.
2. Extend `azure-pipelines.yml` from this repository.
3. Provide their own JSON parameter file from their own repository.

Example:

```yaml
resources:
	repositories:
	- repository: templates
		type: git
		name: platform-engineering/shared-templates

extends:
	template: azure-pipelines.yml@templates
	parameters:
		serviceConnection: sc-connection-customer
		resourceGroupName: rg-customerA-demo
		location: uksouth
		parameterFile: infra/demo.parameters.json
```

Pin consumers to a tag or release branch so shared changes are adopted deliberately.