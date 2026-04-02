# Customer repository template

This repository is a bootstrap template for onboarding a new customer repository.

It does not contain shared deployment logic. Shared pipeline behavior and shared Bicep templates stay in the `shared-templates` repository.

## Included files

- `azure-pipelines.yml`: thin Azure DevOps pipeline entrypoint
- `infra/demo.parameters.json`: demo environment parameters
- `docs/onboarding.md`: onboarding checklist for a new customer

## How to use

1. Run `repo-management/New-CustomerRepo.ps1` to scaffold a new customer repo.
2. The script prompts for customer name and location, then replaces all placeholders:
   - `__CUSTOMER_NAME__`
   - `__LOCATION__`
3. The script pushes to Azure DevOps and creates the pipeline.
4. Grant the pipeline permission to use the service connection.
5. Confirm the shared template tag to consume from `shared-templates`.

## Design rule

Do not copy the shared Bicep file or reusable pipeline logic into customer repositories. Customer repositories should only carry customer-specific configuration and documentation.