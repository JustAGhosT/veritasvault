// App Service Plan Module
// This module creates an App Service Plan for Function Apps

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

@description('App Service Plan configuration')
param appServicePlanConfig object = {
  skuName: 'Y1'
  tier: 'Dynamic'
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// App Service Plan for Functions
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${baseName}-plan-vv-${projectName}'
  location: location
  tags: tags
  sku: {
    name: appServicePlanConfig.skuName
    tier: appServicePlanConfig.tier
  }
  properties: {
    reserved: true // Linux
  }
}

// Outputs
output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name