// Function Apps Module
// This module creates all the function apps needed for the event grid architecture

@description('Environment name (dev, test, prod)')
param environmentName string

@description('Location code for resource naming')
param locationCode string

@description('Project name for resource naming')
param projectName string

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('App Service Plan ID')
param appServicePlanId string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string

@description('Key Vault URI')
param keyVaultUri string

@description('Feature flags to control which function apps are deployed')
param featureFlags object = {
  deployRiskBot: true
  deployMetricsBot: false
  deployAlertFunction: false
  deployArchivalFunction: false
}

@description('Function app configuration')
param functionAppConfig object = {
  runtimeVersion: 'Node|18'
  functionsVersion: '~4'
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Risk Bot Function App
resource riskBotFunction 'Microsoft.Web/sites@2022-09-01' = if (featureFlags.deployRiskBot) {
  name: '${baseName}-func-vv-${projectName}-riskbot'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: functionAppConfig.runtimeVersion
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionAppConfig.functionsVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'REDIS_CONNECTION_STRING'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/RedisConnectionString)' : ''
        }
      ]
    }
  }
}

// Metrics Bot Function App
resource metricsBotFunction 'Microsoft.Web/sites@2022-09-01' = if (featureFlags.deployMetricsBot) {
  name: '${baseName}-func-vv-${projectName}-metricsbot'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: functionAppConfig.runtimeVersion
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionAppConfig.functionsVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'PROMETHEUS_PUSHGATEWAY_URL'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/PrometheusPushgatewayUrl)' : ''
        }
      ]
    }
  }
}

// Alert Function App
resource alertFunction 'Microsoft.Web/sites@2022-09-01' = if (featureFlags.deployAlertFunction) {
  name: '${baseName}-func-vv-${projectName}-alerts'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: functionAppConfig.runtimeVersion
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionAppConfig.functionsVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'TEAMS_WEBHOOK_URL'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/TeamsWebhookUrl)' : ''
        }
      ]
    }
  }
}

// Archival Function App
resource archivalFunction 'Microsoft.Web/sites@2022-09-01' = if (featureFlags.deployArchivalFunction) {
  name: '${baseName}-func-vv-${projectName}-archival'
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: functionAppConfig.runtimeVersion
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionAppConfig.functionsVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/CosmosConnectionString)' : ''
        }
      ]
    }
  }
}

// Outputs
output functionAppIds object = {
  riskBot: featureFlags.deployRiskBot ? {
    id: riskBotFunction.id
    name: riskBotFunction.name
    principalId: riskBotFunction.identity.principalId
  } : {}
  metricsBot: featureFlags.deployMetricsBot ? {
    id: metricsBotFunction.id
    name: metricsBotFunction.name
    principalId: metricsBotFunction.identity.principalId
  } : {}
  alert: featureFlags.deployAlertFunction ? {
    id: alertFunction.id
    name: alertFunction.name
    principalId: alertFunction.identity.principalId
  } : {}
  archival: featureFlags.deployArchivalFunction ? {
    id: archivalFunction.id
    name: archivalFunction.name
    principalId: archivalFunction.identity.principalId
  } : {}
}
