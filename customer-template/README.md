# Customer repository template

This repository is a bootstrap template for onboarding a new customer repository.

It does not contain shared deployment logic. Shared pipeline behavior and shared Bicep templates stay in the `shared-templates` repository.

## Included files

- `azure-pipelines.yml` — thin pipeline entrypoint that extends the shared template from `shared-templates`
- `infra/demo.parameters.json` — demo environment Bicep parameters (VNet name, address space, subnets)
- `docs/onboarding.md` — onboarding checklist for a new customer

## Placeholders

The template files contain the following placeholders, which are replaced automatically by `New-Customer.ps1`:

| Placeholder              | Replaced with                              |
|--------------------------|--------------------------------------------|
| `__CUSTOMER_NAME__`      | Lowercase customer name (e.g. `contoso`)   |
| `__LOCATION__`           | Azure region (e.g. `uksouth`)              |
| `__SERVICE_CONNECTION__` | Service connection name (`sc-connection-<customer>`) |

## How to use

1. Run `repo-management/New-Customer.ps1` — it handles everything end-to-end:
   - Creates Azure resources (resource group, managed identity, role assignment)
   - Creates the Azure DevOps repo and WIF service connection (no secrets)
   - Scaffolds this template, replaces all placeholders, pushes, and creates the pipeline
2. Grant the pipeline permission to use the service connection.
3. Optionally pin a `ref` in `azure-pipelines.yml` to consume a specific version of `shared-templates`.

## Design rule

Do not copy the shared Bicep file or reusable pipeline logic into customer repositories. Customer repositories should only carry customer-specific configuration and documentation.