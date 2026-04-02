<#
.SYNOPSIS
    End-to-end onboarding of a new customer: Azure environment + repo + pipeline.

.DESCRIPTION
    1. Logs in to Azure (interactive – you pick tenant & subscription)
    2. Creates rg-devops-identity and a User-Assigned Managed Identity
    3. Assigns Owner on the subscription
    4. Creates an Azure DevOps repo
    5. Creates a WIF service connection (no secrets)
    6. Retrieves issuer & subject from the service connection
    7. Creates a federated credential on the Managed Identity
    8. Scaffolds the customer repo from the template
    9. Pushes to Azure DevOps and creates the pipeline

.EXAMPLE
    .\New-Customer.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ── Collect inputs ──────────────────────────────────────────────────────────
$CustomerName = Read-Host 'Customer name (lowercase, no spaces – e.g. contoso)'
if ([string]::IsNullOrWhiteSpace($CustomerName)) {
    Write-Error 'Customer name is required.'
    return
}

$Location = Read-Host 'Azure location (e.g. westeurope)'
if ([string]::IsNullOrWhiteSpace($Location)) {
    Write-Error 'Azure location is required.'
    return
}

$TenantId = Read-Host 'Azure Tenant ID'
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    Write-Error 'Tenant ID is required.'
    return
}

# ── Azure DevOps settings (from devops.config.json) ────────────────────────
$configPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'devops.config.json'
if (-not (Test-Path $configPath)) {
    Write-Error "Config file not found: $configPath"
    return
}
$config  = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$OrgUrl  = $config.orgUrl
$Project = $config.projectName
$RepoName = "customer-$CustomerName"

# ── Azure resource names ───────────────────────────────────────────────────
$ResourceGroupName     = 'rg-devops-identity'
$IdentityName          = "id-devops-$CustomerName"
$ServiceConnectionName = "sc-connection-$CustomerName"

# ═══════════════════════════════════════════════════════════════════════════
#  PHASE 1 – Azure login
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`nLogging in to Azure (Tenant: $TenantId) ..." -ForegroundColor Cyan
az login --tenant $TenantId

$SubscriptionId   = az account show --query "id"   -o tsv
$SubscriptionName = az account show --query "name"  -o tsv

Write-Host "Using subscription: $SubscriptionName ($SubscriptionId)" -ForegroundColor Green
Write-Host "Tenant:             $TenantId" -ForegroundColor Green

# ── Ensure az devops extension is installed ─────────────────────────────────
$devopsExt = az extension list --query "[?name=='azure-devops']" -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($devopsExt)) {
    Write-Host 'Installing azure-devops extension ...' -ForegroundColor Yellow
    az extension add --name azure-devops
}

# ═══════════════════════════════════════════════════════════════════════════
#  PHASE 2 – Azure resources (RG, Managed Identity, RBAC)
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`nEnsuring resource group '$ResourceGroupName' exists ..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location -o none
Write-Host "  Resource group ready." -ForegroundColor Green

Write-Host "Creating managed identity '$IdentityName' ..." -ForegroundColor Cyan
$identity = az identity create `
    --name $IdentityName `
    --resource-group $ResourceGroupName `
    --location $Location `
    -o json | ConvertFrom-Json

$IdentityClientId    = $identity.clientId
$IdentityPrincipalId = $identity.principalId

Write-Host "  Managed identity created." -ForegroundColor Green
Write-Host "    Client ID:    $IdentityClientId"
Write-Host "    Principal ID: $IdentityPrincipalId"

Write-Host "Assigning Owner role on subscription ..." -ForegroundColor Cyan
az role assignment create `
    --assignee-object-id $IdentityPrincipalId `
    --assignee-principal-type ServicePrincipal `
    --role Owner `
    --scope "/subscriptions/$SubscriptionId" `
    -o none
Write-Host "  Owner role assigned." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
#  PHASE 3 – Azure DevOps (repo, service connection, federation)
# ═══════════════════════════════════════════════════════════════════════════

# ── Create ADO repo ────────────────────────────────────────────────────────
Write-Host "`nEnsuring Azure DevOps repo '$RepoName' exists ..." -ForegroundColor Cyan
$existingRepo = az repos show --repository $RepoName --org $OrgUrl --project $Project -o json 2>$null | ConvertFrom-Json
if (-not $existingRepo) {
    Write-Host "  Creating repo '$RepoName' ..." -ForegroundColor Yellow
    az repos create --name $RepoName --org $OrgUrl --project $Project -o none
}
else {
    Write-Host "  Repo '$RepoName' already exists." -ForegroundColor Green
}

# ── Create WIF service connection ──────────────────────────────────────────
Write-Host "Creating service connection '$ServiceConnectionName' ..." -ForegroundColor Cyan

$ProjectId = az devops project show --project $Project --org $OrgUrl --query 'id' -o tsv
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Error "Could not resolve project ID for '$Project'."
    return
}

$serviceEndpointBody = @{
    name = $ServiceConnectionName
    type = 'AzureRM'
    url  = 'https://management.azure.com/'
    authorization = @{
        scheme     = 'WorkloadIdentityFederation'
        parameters = @{
            tenantid           = $TenantId
            serviceprincipalid = $IdentityClientId
        }
    }
    data = @{
        subscriptionId   = $SubscriptionId
        subscriptionName = $SubscriptionName
        environment      = 'AzureCloud'
        scopeLevel       = 'Subscription'
        creationMode     = 'Manual'
    }
    isShared = $false
    isReady  = $true
    serviceEndpointProjectReferences = @(
        @{
            projectReference = @{
                id   = $ProjectId
                name = $Project
            }
            name = $ServiceConnectionName
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $serviceEndpointBody -NoNewline

$scResponse = az devops service-endpoint create `
    --service-endpoint-configuration $tempFile `
    --organization $OrgUrl `
    --project $Project `
    -o json | ConvertFrom-Json

Remove-Item $tempFile -Force

Write-Host "  Service connection created." -ForegroundColor Green

# ── Retrieve issuer & subject, create federation ───────────────────────────
$Issuer  = $scResponse.authorization.parameters.workloadIdentityFederationIssuer
$Subject = $scResponse.authorization.parameters.workloadIdentityFederationSubject

if ([string]::IsNullOrWhiteSpace($Issuer) -or [string]::IsNullOrWhiteSpace($Subject)) {
    Write-Error "Could not retrieve federation issuer/subject from the service connection response."
    return
}

Write-Host "  Issuer:  $Issuer" -ForegroundColor DarkGray
Write-Host "  Subject: $Subject" -ForegroundColor DarkGray

Write-Host "Creating federated credential on managed identity ..." -ForegroundColor Cyan

$federationName = "federation-ado-$CustomerName"

az identity federated-credential create `
    --name $federationName `
    --identity-name $IdentityName `
    --resource-group $ResourceGroupName `
    --issuer $Issuer `
    --subject $Subject `
    --audiences "api://AzureADTokenExchange" `
    -o none

Write-Host "  Federated credential '$federationName' created." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
#  PHASE 4 – Scaffold customer repo from template
# ═══════════════════════════════════════════════════════════════════════════
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot    = Resolve-Path (Join-Path $ScriptDir '..')
$TemplateDir = Join-Path $RepoRoot 'customer-template'
$TargetDir   = Join-Path $RepoRoot "customer-$CustomerName"

if (-not (Test-Path $TemplateDir)) {
    Write-Error "Template directory not found: $TemplateDir"
    return
}

if (Test-Path $TargetDir) {
    Write-Host "`nTarget directory already exists: $TargetDir" -ForegroundColor Yellow
    Write-Host 'Skipping copy and placeholder replacement.' -ForegroundColor Yellow
    Push-Location $TargetDir
    try {
        Write-Host "`nGit status:" -ForegroundColor Cyan
        git status
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "`nCopying template to $TargetDir ..." -ForegroundColor Cyan
    Copy-Item -Path $TemplateDir -Destination $TargetDir -Recurse

    # ── Replace placeholders ────────────────────────────────────────────────
    $replacements = @{
        '__CUSTOMER_NAME__'      = $CustomerName
        '__LOCATION__'           = $Location
        '__SERVICE_CONNECTION__'  = $ServiceConnectionName
    }

    $files = Get-ChildItem -Path $TargetDir -Recurse -File

    foreach ($file in $files) {
        $content = Get-Content -Path $file.FullName -Raw

        $changed = $false
        foreach ($placeholder in $replacements.Keys) {
            if ($content.Contains($placeholder)) {
                $content = $content.Replace($placeholder, $replacements[$placeholder])
                $changed = $true
            }
        }

        if ($changed) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "  Replaced placeholders in $($file.FullName)" -ForegroundColor Green
        }
    }

    # ── Initialise git repo ─────────────────────────────────────────────────
    Write-Host 'Initialising git repository ...' -ForegroundColor Cyan
    Push-Location $TargetDir
    try {
        git init
        git add -A
        git commit -m "Initial scaffold for customer '$CustomerName'"
    }
    finally {
        Pop-Location
    }

    Write-Host "Customer repo ready at: $TargetDir" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════
#  PHASE 5 – Push to Azure DevOps and create pipeline
# ═══════════════════════════════════════════════════════════════════════════
Write-Host "`nPushing to Azure DevOps ..." -ForegroundColor Cyan
$RemoteUrl = "$OrgUrl/$Project/_git/$RepoName"
Push-Location $TargetDir
try {
    $status = git status --porcelain
    if ($status) {
        Write-Host '  Working tree is dirty – committing changes ...' -ForegroundColor Yellow
        git add -A
        git commit -m "Update customer '$CustomerName' repo"
    }
    $currentRemote = git remote get-url origin 2>$null
    if (-not $currentRemote) {
        git remote add origin $RemoteUrl
    }
    elseif ($currentRemote -ne $RemoteUrl) {
        Write-Host "  Updating origin to $RemoteUrl" -ForegroundColor Yellow
        git remote set-url origin $RemoteUrl
    }
    git push -u origin main
}
finally {
    Pop-Location
}
Write-Host "Pushed to $RemoteUrl" -ForegroundColor Green

Write-Host 'Creating Azure DevOps pipeline ...' -ForegroundColor Cyan
az pipelines create `
    --name $RepoName `
    --repository $RepoName `
    --repository-type tfsgit `
    --branch main `
    --yml-path azure-pipelines.yml `
    --organization $OrgUrl `
    --project $Project `
    --skip-first-run
Write-Host "Pipeline '$RepoName' created." -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════════════════
#  DONE
# ═══════════════════════════════════════════════════════════════════════════
Write-Host ''
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '  Customer onboarded successfully!' -ForegroundColor Green
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host "  Customer:            $CustomerName"
Write-Host "  Subscription:        $SubscriptionName ($SubscriptionId)"
Write-Host "  Resource Group:      $ResourceGroupName"
Write-Host "  Managed Identity:    $IdentityName (Owner)"
Write-Host "  Federation:          $federationName"
Write-Host "  Service Connection:  $ServiceConnectionName"
Write-Host "  Repo:                $RemoteUrl"
Write-Host "  Pipeline:            $RepoName"
Write-Host ''
