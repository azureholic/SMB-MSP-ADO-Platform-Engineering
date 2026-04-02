# New customer onboarding

Use this checklist when creating a new customer repository from the template.

## Repository setup

1. Run `repo-management/New-CustomerRepo.ps1` to scaffold the new customer repository.
2. The script copies `customer-template`, replaces placeholders, pushes to Azure DevOps, and creates the pipeline.
3. Verify the repository name matches the customer naming standard.

## Azure DevOps setup

1. Create or confirm the Azure service connection.
2. Grant the pipeline permission to use the service connection.
3. Verify the pipeline was created by the script from `azure-pipelines.yml`.
4. Verify the repository reference to `shared-templates`.

## Infrastructure configuration

1. Update `infra/demo.parameters.json`.
2. Review address spaces and naming against platform standards.
4. Keep secrets out of parameter files.

## Validation

1. Run a deployment to the demo environment.
2. Confirm the expected resource group and virtual network are created.
3. Review the deployment output and Azure activity log.