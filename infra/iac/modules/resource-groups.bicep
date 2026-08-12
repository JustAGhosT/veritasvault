// Resource Groups Module
// This module creates all the resource groups needed for the VeritasVault platform

targetScope = 'subscription'

@description('Environment name (dev, test, prod)')
param environmentName string

@description('Location code for resource naming')
param locationCode string

@description('Project name for resource naming')
param projectName string

@description('Location for resources')
param location string

@description('Tags for all resources')
param tags object

@description('Whether to deploy multi-region resources')
param multiRegion bool = false

@description('Secondary location for geo-redundant resources')
param secondaryLocation string = 'northeurope'

@description('Secondary location code')
param secondaryLocationCode string = 'neu'

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'
var secondaryBaseName = '${environmentName}-${secondaryLocationCode}'

// Core resource group for main infrastructure
resource coreResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${baseName}-rg-vv-${projectName}'
  location: location
  tags: tags
}

// Data resource group for storage resources
resource dataResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${baseName}-rg-vv-data'
  location: location
  tags: tags
}

// Services resource group for application services
resource servicesResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${baseName}-rg-vv-services'
  location: location
  tags: tags
}

// Monitoring resource group for monitoring resources
resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${baseName}-rg-vv-monitoring'
  location: location
  tags: tags
}

// Security resource group for security resources
resource securityResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${baseName}-rg-vv-security'
  location: location
  tags: tags
}

// Secondary region resource groups (conditional)
resource secondaryCoreResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (multiRegion) {
  name: '${secondaryBaseName}-rg-vv-${projectName}'
  location: secondaryLocation
  tags: union(tags, {
    'region': 'secondary'
  })
}

resource secondaryDataResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (multiRegion) {
  name: '${secondaryBaseName}-rg-vv-data'
  location: secondaryLocation
  tags: union(tags, {
    'region': 'secondary'
  })
}

resource secondaryServicesResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (multiRegion) {
  name: '${secondaryBaseName}-rg-vv-services'
  location: secondaryLocation
  tags: union(tags, {
    'region': 'secondary'
  })
}

// Outputs
output coreResourceGroupName string = coreResourceGroup.name
output dataResourceGroupName string = dataResourceGroup.name
output servicesResourceGroupName string = servicesResourceGroup.name
output monitoringResourceGroupName string = monitoringResourceGroup.name
output securityResourceGroupName string = securityResourceGroup.name

output secondaryCoreResourceGroupName string = multiRegion ? secondaryCoreResourceGroup.name : ''
output secondaryDataResourceGroupName string = multiRegion ? secondaryDataResourceGroup.name : ''
output secondaryServicesResourceGroupName string = multiRegion ? secondaryServicesResourceGroup.name : ''