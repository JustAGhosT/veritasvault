// VeritasVault Event Grid Architecture (Goldsky Integration)
// Main orchestration module for Event Grid infrastructure

@description('Environment name (dev, test, prod)')
param environmentName string = 'dev'

@description('Location for all resources')
param location string = 'westeurope'

@description('Location code for resource naming')
param locationCode string = 'weu'

@description('Project name for resource naming')
param projectName string = 'chain'

@description('Tags for all resources')
param tags object = {
  environment: environmentName
  project: 'VeritasVault'
  owner: 'Phoenix VC'
}

@description('Feature flags to control which resources are deployed')
param featureFlags object = {
  deployEventGrid: true
  deployDeadLetterStorage: true
  deployCosmosDB: false
  deployRedisCache: false
  deployAppServicePlan: false
  deployMonitoring: false
  deployKeyVault: false
  deployFunctionApps: false
}

@description('Cosmos DB configuration')
param cosmosDbConfig object = {
  serverless: true
  containers: [
    {
      name: 'blockchain-events'
      partitionKeyPath: '/eventType'
      ttlInSeconds: 2592000 // 30 days
    }
  ]
}

@description('Redis Cache configuration')
param redisCacheConfig object = {
  skuName: 'Basic'
  capacity: 1
}

@description('App Service Plan configuration')
param appServicePlanConfig object = {
  skuName: 'Y1'
  tier: 'Dynamic'
}

@description('Monitoring configuration')
param monitoringConfig object = {
  logRetentionDays: 30
  enableDiagnostics: true
}

// Deploy Event Grid Topic
module eventGridTopicModule 'eventgrid/topic.bicep' = if (featureFlags.deployEventGrid) {
  name: 'eventGridTopicDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
  }
}

// Deploy Dead Letter Storage
module deadLetterStorageModule 'eventgrid/deadletter-storage.bicep' = if (featureFlags.deployDeadLetterStorage) {
  name: 'deadLetterStorageDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
  }
}

// Deploy Cosmos DB
module cosmosDbModule 'eventgrid/cosmos-db.bicep' = if (featureFlags.deployCosmosDB) {
  name: 'cosmosDbDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    cosmosDbConfig: cosmosDbConfig
  }
}

// Deploy Redis Cache
module redisCacheModule 'eventgrid/redis-cache.bicep' = if (featureFlags.deployRedisCache) {
  name: 'redisCacheDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    redisCacheConfig: redisCacheConfig
  }
}

// Deploy App Service Plan
module appServicePlanModule 'eventgrid/app-service-plan.bicep' = if (featureFlags.deployAppServicePlan) {
  name: 'appServicePlanDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanConfig: appServicePlanConfig
  }
}

// Deploy Monitoring Resources
module monitoringModule 'eventgrid/monitoring.bicep' = if (featureFlags.deployMonitoring) {
  name: 'monitoringDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    monitoringConfig: monitoringConfig
  }
}

// Deploy Key Vault
module keyVaultModule 'eventgrid/key-vault.bicep' = if (featureFlags.deployKeyVault) {
  name: 'keyVaultDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
  }
}

// Function App module - conditional deployment
module functionApps 'function-apps.bicep' = if (featureFlags.deployFunctionApps) {
  name: 'functionAppsDeployment'
  params: {
    environmentName: environmentName
    locationCode: locationCode
    projectName: projectName
    location: location
    tags: tags
    appServicePlanId: featureFlags.deployAppServicePlan ? appServicePlanModule.outputs.appServicePlanId : ''
    appInsightsInstrumentationKey: featureFlags.deployMonitoring ? monitoringModule.outputs.appInsightsInstrumentationKey : ''
    keyVaultUri: featureFlags.deployKeyVault ? keyVaultModule.outputs.keyVaultUri : ''
  }
}

// Event Grid Subscriptions module - conditional deployment
module eventGridSubscriptions 'event-grid-subscriptions.bicep' = if (featureFlags.deployEventGrid && featureFlags.deployFunctionApps) {
  name: 'eventGridSubscriptionsDeployment'
  params: {
    eventGridTopicName: eventGridTopicModule.outputs.topicName
    deadLetterStorageId: featureFlags.deployDeadLetterStorage ? deadLetterStorageModule.outputs.storageId : ''
    deadLetterContainerName: featureFlags.deployDeadLetterStorage ? deadLetterStorageModule.outputs.containerName : ''
    functionAppIds: functionApps.outputs.functionAppIds
  }
}

// Diagnostic Settings for Event Grid Topic - conditional deployment
module eventGridDiagnostics 'eventgrid/diagnostics.bicep' = if (featureFlags.deployEventGrid && featureFlags.deployMonitoring && monitoringConfig.enableDiagnostics) {
  name: 'eventGridDiagnosticsDeployment'
  params: {
    eventGridTopicName: eventGridTopicModule.outputs.topicName
    workspaceId: monitoringModule.outputs.logAnalyticsWorkspaceId
  }
}

// Outputs - conditionally return values based on what was deployed
output eventGridTopicEndpoint string = featureFlags.deployEventGrid ? eventGridTopicModule.outputs.topicEndpoint : ''
output eventGridTopicId string = featureFlags.deployEventGrid ? eventGridTopicModule.outputs.topicId : ''
output deadLetterStorageId string = featureFlags.deployDeadLetterStorage ? deadLetterStorageModule.outputs.storageId : ''
output cosmosDbEndpoint string = featureFlags.deployCosmosDB ? cosmosDbModule.outputs.cosmosDbEndpoint : ''
output cosmosDbId string = featureFlags.deployCosmosDB ? cosmosDbModule.outputs.cosmosDbId : ''
output redisHostName string = featureFlags.deployRedisCache ? redisCacheModule.outputs.redisHostName : ''
output redisId string = featureFlags.deployRedisCache ? redisCacheModule.outputs.redisId : ''
output appServicePlanId string = featureFlags.deployAppServicePlan ? appServicePlanModule.outputs.appServicePlanId : ''
output logAnalyticsWorkspaceId string = featureFlags.deployMonitoring ? monitoringModule.outputs.logAnalyticsWorkspaceId : ''
output appInsightsInstrumentationKey string = featureFlags.deployMonitoring ? monitoringModule.outputs.appInsightsInstrumentationKey : ''
output keyVaultUri string = featureFlags.deployKeyVault ? keyVaultModule.outputs.keyVaultUri : ''
output keyVaultId string = featureFlags.deployKeyVault ? keyVaultModule.outputs.keyVaultId : ''