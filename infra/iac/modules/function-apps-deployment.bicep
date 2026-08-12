// Function Apps Deployment Module
// This module orchestrates the deployment of all function apps for the VeritasVault platform

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

@description('Key Vault URI')
param keyVaultUri string = ''

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

@description('Feature flags to control which function apps are deployed')
param featureFlags object = {
  deployRiskBot: true
  deployMetricsBot: true
  deployAlertFunction: true
  deployArchivalFunction: true
}

@description('Storage account configuration')
param storageConfig object = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
}

@description('App Service Plan ID')
param appServicePlanId string = ''

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string = ''

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Create App Service Plan if not provided
module appServicePlan 'function-apps/app-service-plan.bicep' = if (empty(appServicePlanId)) {
  name: 'appServicePlanDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    sku: environmentName == 'prod' ? 'EP1' : 'Y1'
    tier: environmentName == 'prod' ? 'ElasticPremium' : 'Dynamic'
  }
}

// Deploy shared storage account for function apps
module sharedStorage 'function-apps/storage-account.bicep' = {
  name: 'sharedStorageDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: '${projectName}func'
    location: location
    tags: tags
    storageConfig: storageConfig
  }
}

// Deploy Risk Bot Function App
module riskBotFunction 'function-apps/risk-bot.bicep' = if (featureFlags.deployRiskBot) {
  name: 'riskBotFunctionDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanId: empty(appServicePlanId) ? appServicePlan.outputs.appServicePlanId : appServicePlanId
    storageAccountName: sharedStorage.outputs.storageAccountName
    storageAccountKey: sharedStorage.outputs.storageAccountKey
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    keyVaultUri: keyVaultUri
    networkingConfig: networkingConfig
  }
}

// Deploy Metrics Bot Function App
module metricsBotFunction 'function-apps/metrics-bot.bicep' = if (featureFlags.deployMetricsBot) {
  name: 'metricsBotFunctionDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanId: empty(appServicePlanId) ? appServicePlan.outputs.appServicePlanId : appServicePlanId
    storageAccountName: sharedStorage.outputs.storageAccountName
    storageAccountKey: sharedStorage.outputs.storageAccountKey
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    keyVaultUri: keyVaultUri
    networkingConfig: networkingConfig
  }
}

// Deploy Alert Function App
module alertFunction 'function-apps/alert-function.bicep' = if (featureFlags.deployAlertFunction) {
  name: 'alertFunctionDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanId: empty(appServicePlanId) ? appServicePlan.outputs.appServicePlanId : appServicePlanId
    storageAccountName: sharedStorage.outputs.storageAccountName
    storageAccountKey: sharedStorage.outputs.storageAccountKey
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    keyVaultUri: keyVaultUri
    networkingConfig: networkingConfig
  }
}

// Deploy Archival Function App
module archivalFunction 'function-apps/archival-function.bicep' = if (featureFlags.deployArchivalFunction) {
  name: 'archivalFunctionDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanId: empty(appServicePlanId) ? appServicePlan.outputs.appServicePlanId : appServicePlanId
    storageAccountName: sharedStorage.outputs.storageAccountName
    storageAccountKey: sharedStorage.outputs.storageAccountKey
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    keyVaultUri: keyVaultUri
    networkingConfig: networkingConfig
  }
}

// Outputs
output functionAppIds object = {
  riskBot: featureFlags.deployRiskBot ? {
    id: riskBotFunction.outputs.functionAppId
    name: riskBotFunction.outputs.functionAppName
    principalId: riskBotFunction.outputs.functionAppPrincipalId
  } : {}
  metricsBot: featureFlags.deployMetricsBot ? {
    id: metricsBotFunction.outputs.functionAppId
    name: metricsBotFunction.outputs.functionAppName
    principalId: metricsBotFunction.outputs.functionAppPrincipalId
  } : {}
  alert: featureFlags.deployAlertFunction ? {
    id: alertFunction.outputs.functionAppId
    name: alertFunction.outputs.functionAppName
    principalId: alertFunction.outputs.functionAppPrincipalId
  } : {}
  archival: featureFlags.deployArchivalFunction ? {
    id: archivalFunction.outputs.functionAppId
    name: archivalFunction.outputs.functionAppName
    principalId: archivalFunction.outputs.functionAppPrincipalId
  } : {}
}