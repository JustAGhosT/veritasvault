# Deployment script for VeritasVault Infrastructure as Code
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "vv-$Environment-rg",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Check for Azure CLI
$azCliVersion = az --version 2>$null
if (-not $?) {
    Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
$account = az account show 2>$null | ConvertFrom-Json
if (-not $?) {
    Write-Host "Not logged in to Azure. Initiating login..."
    az login
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $?) {
        Write-Error "Failed to log in to Azure."
        exit 1
    }
}

Write-Host "Logged in as: $($account.user.name)"
Write-Host "Subscription: $($account.name) ($($account.id))"
Write-Host "Deploying to environment: $Environment"

# Create resource group if it doesn't exist
$resourceGroup = az group show --name $ResourceGroupName 2>$null | ConvertFrom-Json
if (-not $?) {
    Write-Host "Creating resource group '$ResourceGroupName' in location '$Location'..."
    if (-not $WhatIf) {
        az group create --name $ResourceGroupName --location $Location
    } else {
        Write-Host "[WhatIf] Would create resource group '$ResourceGroupName' in location '$Location'"
    }
}

# Deploy the main Bicep template
$deploymentName = "vv-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$templateFile = "$PSScriptRoot/../environments/$Environment/main.bicep"

Write-Host "Deploying template '$templateFile' to resource group '$ResourceGroupName'..."

if (-not $WhatIf) {
    az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters environmentName=$Environment location=$Location
} else {
    Write-Host "[WhatIf] Would deploy template '$templateFile' to resource group '$ResourceGroupName'"
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file $templateFile `
        --parameters environmentName=$Environment location=$Location
}

if ($?) {
    Write-Host "Deployment completed successfully!"
} else {
    Write-Error "Deployment failed."
    exit 1
}