// Alert Function App Module
// This module creates a Function App for the Alert Function

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

@description('App Service Plan ID')
param appServicePlanId string

@description('Storage Account Name')
param storageAccountName string

@description('Storage Account Key')
@secure()
param storageAccountKey string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string = ''

@description('Key Vault URI')
param keyVaultUri string = ''

@description('Networking configuration')
param networkingConfig object = {
  privateEndpoints: {
    enabled: false
  }
  subnetId: ''
}

// Resource naming convention
var baseName = '${environmentName}-${locationCode}'

// Alert Function App
resource alertFunction 'Microsoft.Web/sites@2022-09-01' = {
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
    virtualNetworkSubnetId: !empty(networkingConfig.subnetId) ? networkingConfig.subnetId : null
    siteConfig: {
      linuxFxVersion: 'Node|18'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccountKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('alerts-${environmentName}')
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: !empty(appInsightsInstrumentationKey) ? appInsightsInstrumentationKey : ''
        }
        {
          name: 'TEAMS_WEBHOOK_URL'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/TeamsWebhookUrl)' : ''
        }
        {
          name: 'EMAIL_CONNECTION_STRING'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/EmailConnectionString)' : ''
        }
        {
          name: 'SMS_CONNECTION_STRING'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/SmsConnectionString)' : ''
        }
        {
          name: 'ALERT_ENVIRONMENT'
          value: environmentName
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }
}

// Private Endpoint (if enabled)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = if (networkingConfig.privateEndpoints.enabled && !empty(networkingConfig.subnetId)) {
  name: '${baseName}-pe-vv-${projectName}-alerts'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'alerts-function-connection'
        properties: {
          privateLinkServiceId: alertFunction.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: networkingConfig.subnetId
    }
  }
}

// Outputs
output functionAppId string = alertFunction.id
output functionAppName string = alertFunction.name
output functionAppPrincipalId string = alertFunction.identity.principalId
output functionAppHostName string = alertFunction.properties.defaultHostName