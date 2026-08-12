// Archival Function App Module
// This module creates a Function App for the Archival Function

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

// Archival Function App
resource archivalFunction 'Microsoft.Web/sites@2022-09-01' = {
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
          value: toLower('archival-${environmentName}')
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: !empty(appInsightsInstrumentationKey) ? appInsightsInstrumentationKey : ''
        }
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: !empty(keyVaultUri) ? '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/CosmosConnectionString)' : ''
        }
        {
          name: 'COSMOS_DATABASE_NAME'
          value: 'veritasvault'
        }
        {
          name: 'COSMOS_CONTAINER_NAME'
          value: 'blockchain-events'
        }
        {
          name: 'ARCHIVAL_ENVIRONMENT'
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
  name: '${baseName}-pe-vv-${projectName}-archival'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'archival-function-connection'
        properties: {
          privateLinkServiceId: archivalFunction.id
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
output functionAppId string = archivalFunction.id
output functionAppName string = archivalFunction.name
output functionAppPrincipalId string = archivalFunction.identity.principalId
output functionAppHostName string = archivalFunction.properties.defaultHostName